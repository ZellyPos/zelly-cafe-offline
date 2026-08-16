import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_logger.dart';
import '../../data/repositories/settings_repository.dart';

/// Ilovani **kuniga bir marta** o'zi yopib qayta ochadi (§16).
///
/// Nega kerak: kassa kompyuteri haftalab o'chirilmaydi — xotira to'planadi,
/// ulanishlar (WebSocket, tunnel, printer) uzilib qoladi, kunlik hisob-kitob
/// keshlari eskiradi. Kechasi bir marta toza ishga tushish shularni tozalaydi.
///
/// Qoidalar (POS uchun xavfsizlik):
/// - Faqat **belgilangan vaqt oynasida** (default 04:00, oyna 2 soat) — kunduzi
///   hech qachon o'z-o'zidan yopilmaydi.
/// - Kuniga **bitta** marta: sana `settings` jadvaliga yoziladi, shuning uchun
///   qayta ochilgandan keyin sikl takrorlanmaydi.
/// - **Band bo'lsa kutadi**: savatda mahsulot bo'lsa yoki [busy] `true`
///   qaytarsa, restart keyingi tekshiruvga qoldiriladi (oyna tugaguncha).
/// - Ilova endigina ochilgan bo'lsa (< 10 daqiqa) tegilmaydi — qayta ishga
///   tushish siklining oldini oladi.
class DailyRestartService {
  DailyRestartService._();
  static final DailyRestartService instance = DailyRestartService._();

  /// Sozlama kalitlari (`settings` jadvali).
  static const keyEnabled = 'daily_restart_enabled';
  static const keyTime = 'daily_restart_time';
  static const keyLastDate = 'daily_restart_last_date';

  static const defaultTime = '04:00';

  /// Belgilangan vaqtdan keyin restart hali ham mumkin bo'lgan oyna.
  /// Oyna tugagach o'sha kun uchun urinish to'xtaydi (ertaga qayta ko'riladi).
  static const _window = Duration(hours: 2);

  /// Ishga tushgandan keyingi "tegmaslik" muddati — restart sikli bo'lmasin.
  static const _minUptime = Duration(minutes: 10);

  /// Tekshirish oralig'i — daqiqada bir marta yetarli va arzon.
  static const _tick = Duration(minutes: 1);

  final SettingsRepository _repo = SettingsRepository();

  Timer? _timer;
  DateTime? _startedAt;
  bool Function()? _busy;
  bool _restarting = false;

  /// Kuzatuvni boshlaydi. [busy] — `true` qaytarsa restart kechiktiriladi
  /// (masalan savatda ochiq buyurtma bor).
  void start({bool Function()? busy}) {
    if (_timer != null) return; // Ikki marta ishga tushmasin
    _busy = busy;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(_tick, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    if (_restarting) return;
    final startedAt = _startedAt;
    if (startedAt == null) return;
    if (DateTime.now().difference(startedAt) < _minUptime) return;

    try {
      final settings = await _repo.getAll();
      // Kalit yo'q bo'lsa — yoqilgan (yangi imkoniyat default holda ishlaydi).
      if (settings[keyEnabled] == 'false') return;

      final now = DateTime.now();
      final scheduled = _scheduledFor(now, settings[keyTime] ?? defaultTime);
      if (now.isBefore(scheduled)) return;
      if (now.isAfter(scheduled.add(_window))) return; // oyna o'tib ketdi

      if (settings[keyLastDate] == _dateKey(now)) return; // bugun bo'lgan

      if (_busy?.call() ?? false) {
        AppLogger.i('Restart', 'Ilova band — qayta ishga tushirish kechiktirildi');
        return;
      }

      _restarting = true;
      // Sanani OLDIN yozamiz: qayta ochilgach yana restart bo'lib ketmasin.
      await _repo.setValue(keyLastDate, _dateKey(now));
      AppLogger.i('Restart', 'Kunlik qayta ishga tushirish boshlandi');
      await restartNow();
    } catch (e, st) {
      _restarting = false;
      AppLogger.e('Restart', 'Kunlik qayta ishga tushirishda xato', e, st);
    }
  }

  /// Ilovani yopib qayta ochadi (qo'lda ham chaqirilishi mumkin).
  ///
  /// Yangi nusxa **darhol** emas, bir necha soniyadan keyin ochiladi: eski
  /// jarayon SQLite faylini va server portini bo'shatib ulgurishi kerak.
  Future<void> restartNow({Duration delay = const Duration(seconds: 5)}) async {
    final exe = Platform.resolvedExecutable;
    try {
      if (Platform.isWindows) {
        // `.bat` — Windows'da eng ishonchli yo'l: ota-jarayon o'lganda ham
        // ishlaydi. Kutish uchun `ping` (`timeout` konsolsiz rejimda xato
        // beradi). Oxirgi qator o'zini o'chiradi.
        final bat = File(p.join(Directory.systemTemp.path, 'zelly_restart.bat'));
        await bat.writeAsString(
          '@echo off\r\n'
          'ping 127.0.0.1 -n ${delay.inSeconds + 1} > nul\r\n'
          'start "" "$exe"\r\n'
          'del "%~f0"\r\n',
        );
        await Process.start(
          'cmd.exe',
          ['/c', bat.path],
          mode: ProcessStartMode.detached,
        );
      } else {
        await Process.start(
          '/bin/sh',
          ['-c', 'sleep ${delay.inSeconds}; "$exe" &'],
          mode: ProcessStartMode.detached,
        );
      }
    } catch (e, st) {
      AppLogger.e('Restart', 'Yangi nusxani ochib bo\'lmadi', e, st);
      _restarting = false;
      return; // Ochib bo'lmasa yopmaymiz ham — aks holda kassa qolib ketadi
    }

    await AppLogger.flush();
    exit(0);
  }

  /// `HH:mm` matnidan bugungi rejalashtirilgan vaqt. Noto'g'ri qiymatda
  /// [defaultTime] ishlatiladi (sozlama buzilsa ham ilova ishlayveradi).
  static DateTime _scheduledFor(DateTime now, String raw) {
    final parts = raw.split(':');
    var h = parts.length == 2 ? int.tryParse(parts[0]) ?? -1 : -1;
    var m = parts.length == 2 ? int.tryParse(parts[1]) ?? -1 : -1;
    if (h < 0 || h > 23 || m < 0 || m > 59) {
      h = 4;
      m = 0;
    }
    return DateTime(now.year, now.month, now.day, h, m);
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
