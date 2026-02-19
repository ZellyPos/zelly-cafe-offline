import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database_helper.dart';
import '../security/rsa_verifier.dart';
import '../security/device_fingerprint_service.dart';
import '../security/time_tamper_guard.dart';
import '../../models/license_model.dart';

class LicenseService with ChangeNotifier {
  static final LicenseService instance = LicenseService._internal();
  LicenseService._internal();

  static const String _licenseFileName = 'license.json';

  // Ommaviy kalit
  static const String _publicKey = '''
-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnP9yQyuAZ3E71/fuvxGz
FPBLSG80Js2pzbmOCzgH65QBIu+UwEuSfVY8nA+JUxVSP+xF3d+w4d1Ng1l/ky1E
YT8io+i80to9NGOOZtPopwORjsyrWYWTpGY5QDW3wc3MJlzecJ2gJ5vB/wGm1Ky9
KuTkYVUH1MlSRbdn3ZCduLIhfn6qjrnCIvXeEqoFArzmNgqxbKVwoibDaU0RvSv6
MTwMzhPsHjxCO5BN9LwZPau6XTTmaEMEZ/szAn3wk0Jvdia3eKLnuLrk8wAhWrNi
S8UPdfrDn8RyZT5OobqxMpusK2fzpqTCU+8TdeoypM4cSRZZvozeqb0y1Betd/tt
HwIDAQAB
-----END PUBLIC KEY-----
''';

  LicenseStatus? _currentStatus;
  LicenseStatus get currentStatus =>
      _currentStatus ??
      LicenseStatus(
        type: LicenseType.invalid,
        message: 'Litsenziya yuklanmagan',
      );

  /// Tizimni ishga tushirishda litsenziyani tekshirish
  Future<LicenseStatus> init() async {
    // 1. Vaqtni tekshirish (tamper protection)
    final timeOk = await TimeTamperGuard.checkAndPulse();
    if (!timeOk) {
      _currentStatus = LicenseStatus(
        type: LicenseType.tampered,
        message:
            'Tizim vaqti manipulyatsiyasi aniqlandi! Iltimos, vaqtni to\'g\'rilang.',
      );
      notifyListeners();
      return _currentStatus!;
    }

    // 2. Litsenziyani yuklash (AppData yoki DB)
    final licenseData = await _loadLicenseSource();
    if (licenseData == null) {
      _currentStatus = LicenseStatus(
        type: LicenseType.invalid,
        message: 'Litsenziya fayli topilmadi.',
      );
      notifyListeners();
      return _currentStatus!;
    }

    // 3. Validatsiya
    _currentStatus = await verifyLicense(licenseData);
    notifyListeners();
    return _currentStatus!;
  }

  /// Litsenziya faylini verify qilish
  Future<LicenseStatus> verifyLicense(String jsonContent) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonContent);
      final payloadMap = data['payload'];
      final signature = data['signature'];

      if (payloadMap == null || signature == null) {
        return LicenseStatus(
          type: LicenseType.invalid,
          message: 'Fayl formati noto\'g\'ri.',
        );
      }

      final payload = LicensePayload.fromMap(payloadMap);

      // A. Raqamli imzoni tekshirish
      final canonicalJson = payload.toCanonicalJson();
      print('--- DEBUG: VERIFYING LICENSE ---');
      print('CANONICAL JSON: $canonicalJson');
      print('SIGNATURE: $signature');

      final isSignatureValid = RsaVerifier.verify(
        canonicalJson,
        signature,
        _publicKey,
      );

      if (!isSignatureValid) {
        return LicenseStatus(
          type: LicenseType.invalid,
          message: 'Litsenziya imzosi noto\'g\'ri (soxtalashgan).',
        );
      }

      // B. Qurilmaga bog'liqlikni tekshirish (HWID)
      final currentDeviceId = await DeviceFingerprintService.getDeviceId();
      if (payload.deviceId != currentDeviceId) {
        return LicenseStatus(
          type: LicenseType.invalid,
          message: 'Litsenziya boshqa qurilmaga tegishli.',
        );
      }

      // C. Muddatni tekshirish
      final now = DateTime.now();
      if (now.isAfter(payload.expiry)) {
        final diff = now.difference(payload.expiry).inDays;
        if (diff <= 7) {
          return LicenseStatus(
            type: LicenseType.gracePeriod,
            message:
                'Litsenziya muddati tugadi. Imtiyozli davr: ${7 - diff} kun qoldi.',
            payload: payload,
            remainingDays: 7 - diff,
          );
        } else {
          return LicenseStatus(
            type: LicenseType.expired,
            message: 'Litsenziya muddati tugagan! Savdo bloklandi.',
            payload: payload,
          );
        }
      }

      final remaining = payload.expiry.difference(now).inDays;
      return LicenseStatus(
        type: LicenseType.active,
        message: 'Litsenziya faol.',
        payload: payload,
        remainingDays: remaining,
      );
    } catch (e) {
      return LicenseStatus(type: LicenseType.invalid, message: 'Xatolik: $e');
    }
  }

  /// Litsenziyani saqlash (Import)
  Future<bool> saveLicense(String jsonContent) async {
    final status = await verifyLicense(jsonContent);
    if (!status.isValid && status.type != LicenseType.expired) {
      return false;
    }

    // 1. AppData-ga saqlash
    final appDir = await getApplicationSupportDirectory();
    final zellyDir = Directory(p.join(appDir.path, 'Zelly'));
    if (!await zellyDir.exists()) await zellyDir.create(recursive: true);
    final file = File(p.join(zellyDir.path, _licenseFileName));
    await file.writeAsString(jsonContent);

    // 2. DB-ga saqlash (backup)
    final db = await DatabaseHelper.instance.database;
    await db.insert('settings', {
      'key': 'offline_license_data',
      'value': jsonContent,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    _currentStatus = status;
    notifyListeners();
    return true;
  }

  Future<String?> _loadLicenseSource() async {
    // 1. AppData-dan o'qish
    try {
      final appDir = await getApplicationSupportDirectory();
      final file = File(p.join(appDir.path, 'Zelly', _licenseFileName));
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}

    // 2. DB-dan o'qish (agar fayl o'chib ketsa)
    try {
      final db = await DatabaseHelper.instance.database;
      final res = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['offline_license_data'],
      );
      if (res.isNotEmpty) {
        return res.first['value'] as String;
      }
    } catch (_) {}

    return null;
  }
}
