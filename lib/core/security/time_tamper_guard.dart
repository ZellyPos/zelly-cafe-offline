import 'dart:ffi';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database_helper.dart';

// kernel32 uchun FFI bog'lamasi
typedef GetTickCount64Native = Uint64 Function();
typedef GetTickCount64Dart = int Function();

/// Tizim vaqtini manipulyatsiya qilishdan (rollback) himoya qilish.
class TimeTamperGuard {
  static final DatabaseHelper _db = DatabaseHelper.instance;

  static final GetTickCount64Dart _getTickCount64 = DynamicLibrary.open(
    'kernel32.dll',
  ).lookupFunction<GetTickCount64Native, GetTickCount64Dart>('GetTickCount64');

  /// Vaqtni tekshirish va logni yangilash.
  /// Agar vaqt orqaga qaytarilgan bo'lsa `false` qaytaradi.
  static Future<bool> checkAndPulse() async {
    final db = await _db.database;
    final now = DateTime.now().toUtc();

    // Tizim uptime-i (ms)
    int uptime;
    try {
      uptime = _getTickCount64();
    } catch (_) {
      uptime = 0;
    }

    final logs = await db.query('security_logs');
    final Map<String, String> data = {
      for (var row in logs) row['key'] as String: row['value'] as String,
    };

    final lastWallTimeStr = data['last_wall_time'];
    final lastUptimeStr = data['last_uptime_ms'];

    if (lastWallTimeStr != null && lastUptimeStr != null) {
      final lastWall = DateTime.parse(lastWallTimeStr);
      final lastUptime = int.parse(lastUptimeStr);

      final wallElapsed = now.difference(lastWall).inMilliseconds;
      final uptimeElapsed = uptime - lastUptime;

      // 1. Rollback tekshiruvi: real vaqt orqaga ketganmi?
      if (now.isBefore(lastWall)) {
        print('Time Tamper Detected: Wall clock rollback');
        return false;
      }

      // 2. Uptime tekshiruvi:
      if (uptime > 0 && uptime < lastUptime && wallElapsed < 3600000) {
        // Reboot bo'lishi mumkin
      } else if (uptime > 0 && uptimeElapsed < -5000) {
        print('Time Tamper Detected: Uptime inconsistency');
        return false;
      }
    }

    // Logni yangilash
    await _updateLogs(db, now, uptime);
    return true;
  }

  static Future<void> _updateLogs(Database db, DateTime now, int uptime) async {
    await db.insert('security_logs', {
      'key': 'last_wall_time',
      'value': now.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.insert('security_logs', {
      'key': 'last_uptime_ms',
      'value': uptime.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
