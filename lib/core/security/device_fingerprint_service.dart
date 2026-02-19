import 'dart:convert';
import 'dart:ffi';
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Qurilmaning o'ziga xos identifikatorini (HWID) aniqlash uchun xizmat.
/// Windows MachineGuid registridan olingan qiymatga asoslanadi.
class DeviceFingerprintService {
  static const String _registryKey = r'SOFTWARE\Microsoft\Cryptography';
  static const String _registryValue = 'MachineGuid';
  static const String _salt = 'ZELLY|';

  /// Qurilmaning barmoq izini (SHA256 fingerprint) qaytaradi.
  static Future<String> getDeviceId() async {
    final guid = _getMachineGuid();
    if (guid == null) {
      throw Exception('Qurilma identifikatorini aniqlab bo\'lmadi.');
    }

    final bytes = utf8.encode(_salt + guid);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Windows registridan MachineGuid ni o'qiydi.
  static String? _getMachineGuid() {
    final phkResult = calloc<HKEY>();
    try {
      final lpSubKey = _registryKey.toNativeUtf16();

      // Registrni ochish
      final status = RegOpenKeyEx(
        HKEY_LOCAL_MACHINE,
        lpSubKey,
        0,
        REG_SAM_FLAGS.KEY_READ | REG_SAM_FLAGS.KEY_WOW64_64KEY,
        phkResult,
      );

      if (status != WIN32_ERROR.ERROR_SUCCESS) {
        return null;
      }

      final lpValueName = _registryValue.toNativeUtf16();
      final lpData = calloc<BYTE>(256);
      final lpcbData = calloc<DWORD>()..value = 256;

      try {
        // Qiymatni o'qish
        final queryStatus = RegQueryValueEx(
          phkResult.value,
          lpValueName,
          nullptr,
          nullptr,
          lpData,
          lpcbData,
        );

        if (queryStatus == WIN32_ERROR.ERROR_SUCCESS) {
          return lpData.cast<Utf16>().toDartString();
        }
      } finally {
        free(lpValueName);
        free(lpData);
        free(lpcbData);
      }
    } finally {
      RegCloseKey(phkResult.value);
      free(phkResult);
    }
    return null;
  }
}
