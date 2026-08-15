import '../utils/qty_formatter.dart';

/// Ombordagi qoldiq yetmaganda tashlanadi.
///
/// Pishirishda (xomashyo yetmasa), buyurtmani tasdiqlashda (tayyor mahsulot
/// yetmasa) va chiqimda (qoldiq manfiyga tushib ketmasin) ishlatiladi.
/// Shu sabab servisda ham, repozitoriyda ham kerak — aylanma importdan
/// qochish uchun alohida faylda turadi.
///
/// [shortages] — har bir yetishmayotgan birlik: nom, kerak, mavjud, o'lchov.
class InsufficientStockException implements Exception {
  final List<({String name, double need, double onHand, String unit})>
  shortages;

  InsufficientStockException(this.shortages);

  /// Foydalanuvchiga ko'rsatiladigan xabar.
  String get message {
    final lines = shortages.map(
      (s) =>
          '${s.name}: kerak ${QtyFormatter.format(s.need)} ${s.unit}, '
          'mavjud ${QtyFormatter.format(s.onHand)} ${s.unit}',
    );
    return 'Ombordagi qoldiq yetarli emas:\n${lines.join('\n')}';
  }

  @override
  String toString() => message;
}
