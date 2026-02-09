import 'package:intl/intl.dart';

class PriceFormatter {
  static String format(double price) {
    // Uzbek format: space as thousand separator, no decimals if not needed
    // Example: 10 000
    final format = NumberFormat("#,###", "en_US");
    return format.format(price).replaceAll(',', ' ');
  }

  static String formatWithCurrency(double price) {
    return '${format(price)} so‘m';
  }
}
