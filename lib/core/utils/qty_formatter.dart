import 'package:intl/intl.dart';

/// Ombordagi miqdorlarni o'qishga qulay ko'rinishda formatlaydi.
///
/// Xomashyo qoldig'i ko'pincha grammda yuritiladi (`125000 g`) — ajratkichsiz
/// bunday sonni o'qish qiyin. Shu sabab minglar **bo'sh joy** bilan ajratiladi
/// (`125 000`), kasr qismi esa **vergul** bilan yoziladi (`1 250,5`).
///
/// Narxlar uchun [PriceFormatter] ishlatiladi — u ham xuddi shu ajratkichga
/// tayanadi, shuning uchun ikkalasi bir xil ko'rinadi.
class QtyFormatter {
  QtyFormatter._();

  static final _integer = NumberFormat('#,##0', 'en_US');
  static final _decimal = NumberFormat('#,##0.##', 'en_US');

  /// Miqdorni matnga aylantiradi: butun bo'lsa kasrsiz, aks holda 2 xonagacha
  /// (ortiqcha nollarsiz). Manfiy qiymat ishorasi bilan qaytadi.
  static String format(double value) {
    final rounded = double.parse(value.toStringAsFixed(2));
    final raw = rounded == rounded.roundToDouble()
        ? _integer.format(rounded)
        : _decimal.format(rounded);
    // en_US: minglar `,`, kasr `.` → o'zbekcha: minglar ` `, kasr `,`.
    return raw.replaceAll(',', ' ').replaceAll('.', ',');
  }

  /// Miqdor + o'lchov birligi: `125 000 g`. Birlik bo'sh bo'lsa faqat son.
  static String withUnit(double value, String? unit) {
    final text = format(value);
    return (unit == null || unit.isEmpty) ? text : '$text $unit';
  }
}
