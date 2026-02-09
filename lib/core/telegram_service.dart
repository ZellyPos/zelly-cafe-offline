import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'utils/price_formatter.dart';

class TelegramService {
  static Future<bool> sendMessage({
    required String token,
    required String chatId,
    required String text,
    String? webAppUrl,
  }) async {
    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');

      final Map<String, dynamic> body = {
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'HTML',
      };

      if (webAppUrl != null) {
        final bool isHttps = webAppUrl.startsWith('https://');
        body['reply_markup'] = jsonEncode({
          'inline_keyboard': [
            [
              {
                'text': isHttps
                    ? 'Batafsil ko\'rish (WebApp)'
                    : 'Batafsil ko\'rish (Browser)',
                if (isHttps)
                  'web_app': {'url': webAppUrl}
                else
                  'url': webAppUrl,
              },
            ],
          ],
        });
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('Telegram error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Telegram exception: $e');
      return false;
    }
  }

  static String formatReportSummary({
    required String restaurantName,
    required Map<String, dynamic> metrics,
    required List<Map<String, dynamic>> topProducts,
    required String date,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<b>📊 ZELLY POS HISOBOTI</b>');
    buffer.writeln('🏢 <b>Muanassa:</b> $restaurantName');
    buffer.writeln('📅 <b>Sana:</b> $date');
    buffer.writeln('--------------------------------');

    final count = metrics['count'] ?? 0;
    final total = (metrics['total'] as num?)?.toDouble() ?? 0.0;
    final cash = (metrics['cash_total'] as num?)?.toDouble() ?? 0.0;
    final card = (metrics['card_total'] as num?)?.toDouble() ?? 0.0;

    buffer.writeln('✅ <b>Jami cheklar:</b> $count ta');
    buffer.writeln(
      '💰 <b>Umumiy tushum:</b> ${PriceFormatter.format(total)} so\'m',
    );
    buffer.writeln('💵 <b>Naqd:</b> ${PriceFormatter.format(cash)} so\'m');
    buffer.writeln('💳 <b>Karta:</b> ${PriceFormatter.format(card)} so\'m');
    buffer.writeln('--------------------------------');

    if (topProducts.isNotEmpty) {
      buffer.writeln('🔝 <b>Top Mahsulotlar:</b>');
      for (var i = 0; i < topProducts.length; i++) {
        final p = topProducts[i];
        final revenue = (p['revenue'] as num?)?.toDouble() ?? 0.0;
        buffer.writeln(
          '${i + 1}. ${p['name']} - ${PriceFormatter.format(revenue)} so\'m',
        );
      }
    }

    return buffer.toString();
  }
}
