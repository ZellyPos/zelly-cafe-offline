import '../app_logger.dart';
import '../../data/repositories/settings_repository.dart';
import '../../repositories/inventory_repository.dart';

/// Ombor harakatlar tarixini muddati bo'yicha tozalaydi (§19).
///
/// Nega **24 oy**, 6 emas: harakatlar jurnali — buxgalteriya manbai
/// (tannarx dinamikasi, yetkazuvchi bo'yicha tahlil, sarf/isrof trendi,
/// tekshiruvda "bu xomashyo qachon kirim bo'lgan?"). Hujjatlar odatda
/// kamida bir necha yil saqlanadi, 6 oyda esa hatto o'tgan yilning shu oyi
/// bilan taqqoslash ham mumkin bo'lmay qoladi.
///
/// Hajm muammosi hozircha mavjud emas: bir qator ≈ 150 bayt, kuniga ~1000
/// harakat ≈ 50 MB/yil. SQLite indeks bilan buni sezmaydi. Shuning uchun
/// tozalash — "baza shishib ketmasin" chorasi, tezlik chorasi emas.
///
/// Qoidalar:
/// - Yozuv **faqat yoshi bo'yicha** o'chadi; xomashyo/mahsulot o'chirilgani
///   sababli hech qachon (§20).
/// - Kuniga bir marta, ilova ochilgandan biroz keyin — kassir kutib
///   qolmasin.
/// - `0` oy = "cheksiz saqlash" (hech nima o'chirilmaydi).
class HistoryRetentionService {
  HistoryRetentionService._();
  static final HistoryRetentionService instance = HistoryRetentionService._();

  /// Sozlama kalitlari (`settings` jadvali).
  static const keyMonths = 'history_retention_months';
  static const keyLastDate = 'history_purge_last_date';

  static const defaultMonths = 24;

  /// Sozlamalar ekranida taklif qilinadigan variantlar (oy). `0` — cheksiz.
  static const options = <int>[6, 12, 24, 36, 0];

  /// Ishga tushgandan keyin kutish — birinchi ekran chizilib ulgursin.
  static const _startupDelay = Duration(seconds: 30);

  final SettingsRepository _settings = SettingsRepository();
  final InventoryRepository _inventory = InventoryRepository();

  bool _scheduled = false;

  /// Kunlik tekshiruvni rejalashtiradi (ilova ochilganda bir marta).
  void scheduleOnStartup() {
    if (_scheduled) return;
    _scheduled = true;
    Future.delayed(_startupDelay, runIfDue);
  }

  /// Bugun hali tozalanmagan bo'lsa tozalaydi.
  Future<void> runIfDue({DateTime? now}) async {
    final today = _dateKey(now ?? DateTime.now());
    try {
      if (await _settings.getValue(keyLastDate) == today) return;
      await purgeNow(now: now);
      await _settings.setValue(keyLastDate, today);
    } catch (e, st) {
      // Tozalash ilovaning ishlashiga to'sqinlik qilmasligi kerak.
      AppLogger.e('Retention', 'Tarixni tozalashda xato', e, st);
    }
  }

  /// Tozalashni darhol bajaradi (sozlamalar ekranidan ham chaqirilishi
  /// mumkin). Qaytadi: o'chirilgan qatorlar soni.
  Future<int> purgeNow({DateTime? now}) async {
    final months = await retentionMonths();
    if (months <= 0) return 0;

    final removed = await _inventory.purgeHistoryOlderThan(months, now: now);
    final total = removed.ingredient + removed.product;
    if (total > 0) {
      // `DELETE` fayl hajmini kichraytirmaydi — bo'shagan joyni qaytaramiz.
      await _inventory.vacuum();
      AppLogger.i(
        'Retention',
        'Tarix tozalandi | $months oydan eski: '
            'xomashyo ${removed.ingredient}, mahsulot ${removed.product} qator',
      );
    }
    return total;
  }

  /// Saqlash muddati (oy). Sozlama yo'q yoki buzuq bo'lsa [defaultMonths].
  Future<int> retentionMonths() async {
    final raw = await _settings.getValue(keyMonths);
    final months = raw == null ? null : int.tryParse(raw);
    if (months == null || months < 0) return defaultMonths;
    return months;
  }

  Future<void> setRetentionMonths(int months) =>
      _settings.setValue(keyMonths, months.toString());

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
