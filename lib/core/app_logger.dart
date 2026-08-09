import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

enum LogLevel { debug, info, warn, error }

/// Markaziy fayl logger. Barcha xatolar va muhim jarayonlar shu yerga yoziladi.
///
/// Ishlatish:
///   AppLogger.i('CartProvider', 'Buyurtma tasdiqlandi #42');
///   AppLogger.e('Checkout', 'To\'lov xatosi', error, stackTrace);
///
/// Log fayllari: {AppSupport}/logs/app_YYYY-MM-DD.log
/// Saqlash muddati: 7 kun | Fayl hajmi chegarasi: 5 MB
class AppLogger {
  AppLogger._();
  static final AppLogger _i = AppLogger._();

  static const _maxFileBytes = 5 * 1024 * 1024; // 5 MB
  static const _keepDays = 30;
  static final _timeFmt = DateFormat('yyyy-MM-dd HH:mm:ss.SSS');
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  IOSink? _sink;
  String? _openDate;
  String? _logsPath;
  bool _ready = false;

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<void> init() => _i._setup();

  static void d(String tag, String msg) =>
      _i._write(LogLevel.debug, tag, msg);

  static void i(String tag, String msg) =>
      _i._write(LogLevel.info, tag, msg);

  static void w(String tag, String msg, [Object? err]) =>
      _i._write(LogLevel.warn, tag, msg, err);

  static void e(String tag, String msg, [Object? err, StackTrace? st]) =>
      _i._write(LogLevel.error, tag, msg, err, st);

  /// Log fayllar papkasining yo'li (AboutScreen uchun)
  static String? get logsDirectory => _i._logsPath;

  /// Bugungi log faylini o'qib qaytaradi (UI da ko'rsatish uchun)
  static Future<List<String>> readTodayLines({int lastN = 200}) async {
    try {
      final file = _i._currentFile();
      if (file == null || !await file.exists()) return [];
      final lines = await file.readAsLines();
      return lines.length > lastN ? lines.sublist(lines.length - lastN) : lines;
    } catch (_) {
      return [];
    }
  }

  /// Barcha log fayllarini sanab qaytaradi (eng yangi birinchi)
  static Future<List<File>> listLogFiles() async {
    try {
      final dir = Directory(_i._logsPath ?? '');
      if (!await dir.exists()) return [];
      final files = await dir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (_) {
      return [];
    }
  }

  /// IOSink ni flushlaydi — ilova yopilishidan oldin chaqirilsin
  static Future<void> flush() async {
    try {
      await _i._sink?.flush();
    } catch (_) {}
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _setup() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      final dir = Directory('${appDir.path}/logs');
      if (!await dir.exists()) await dir.create(recursive: true);
      _logsPath = dir.path;

      await _cleanOldLogs(dir);
      await _openSink(dir);
      _ready = true;
      i('AppLogger', 'Logger ishga tushdi — ${dir.path}');
    } catch (err) {
      debugPrint('[AppLogger] init xatosi: $err');
    }
  }

  Future<void> _openSink(Directory dir) async {
    final today = _dateFmt.format(DateTime.now());
    _openDate = today;
    final file = await _resolveFile(dir, today);
    _sink = file.openWrite(mode: FileMode.append);
  }

  /// Segmentatsiya: fayl 5MB dan oshsa yangi segment ochiladi
  Future<File> _resolveFile(Directory dir, String date) async {
    for (var seg = 0; ; seg++) {
      final name = seg == 0 ? 'app_$date.log' : 'app_${date}_$seg.log';
      final f = File('${dir.path}/$name');
      if (!await f.exists()) return f;
      if ((await f.length()) < _maxFileBytes) return f;
    }
  }

  File? _currentFile() {
    if (_logsPath == null || _openDate == null) return null;
    return File('$_logsPath/app_$_openDate.log');
  }

  Future<void> _cleanOldLogs(Directory dir) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: _keepDays));
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.log')) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) await entity.delete();
        }
      }
    } catch (_) {}
  }

  void _write(
    LogLevel level,
    String tag,
    String msg, [
    Object? err,
    StackTrace? st,
  ]) {
    final now = DateTime.now();
    final today = _dateFmt.format(now);

    // Kun o'zgarsa yangi faylga o'tish
    if (_ready && today != _openDate) {
      _rotate(today);
    }

    final lvl = switch (level) {
      LogLevel.debug => 'DEBUG',
      LogLevel.info  => 'INFO ',
      LogLevel.warn  => 'WARN ',
      LogLevel.error => 'ERROR',
    };

    final sb = StringBuffer()
      ..write(_timeFmt.format(now))
      ..write(' [$lvl] ')
      ..write(tag)
      ..write(': ')
      ..write(msg);

    if (err != null) sb.write(' | $err');
    if (st != null) {
      // Faqat dastlabki 10 qator stack trace
      final lines = st.toString().split('\n').take(10).join('\n');
      sb.write('\n$lines');
    }

    final line = sb.toString();

    // Debug rejimda konsolga ham chiqaradi
    debugPrint(line);

    if (_ready && _sink != null) {
      try {
        _sink!.writeln(line);
      } catch (_) {}
    }
  }

  void _rotate(String newDate) {
    _sink?.flush().then((_) => _sink?.close()).catchError((_) {});
    _sink = null;
    _openDate = newDate;
    if (_logsPath != null) {
      final dir = Directory(_logsPath!);
      _cleanOldLogs(dir).then((_) => _resolveFile(dir, newDate)).then((f) {
        _sink = f.openWrite(mode: FileMode.append);
      }).catchError((_) {});
    }
  }
}
