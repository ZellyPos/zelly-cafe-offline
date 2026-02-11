import 'dart:convert';
import 'package:http/http.dart' as http;
import 'ai_snapshot_builder.dart';
import 'ai_cache_repository.dart';

class AiService {
  final AiCacheRepository _cache = AiCacheRepository();

  // In a real app, this should be configurable via settings UI
  static const String _apiKey = "AIzaSyDECBQZH_aG6cTBCWfx4MMgui1Xx7b4Cfw";
  static const String _baseUrl =
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

  Future<String> analyze(
    String promptType, {
    DateTime? from,
    DateTime? to,
    Map<String, dynamic>? extra,
  }) async {
    // 1. Build Snapshot
    final snapshot = await AiSnapshotBuilder.build(from: from, to: to);
    final snapshotJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(snapshot.toJson());

    // 2. Build Prompt
    final String systemPrompt = _getSystemPrompt();
    final String userPrompt = _getUserPrompt(promptType, snapshotJson, extra);
    final String combinedPrompt = "$systemPrompt\n\n$userPrompt";

    // 3. Check Cache
    final cacheKeyFilters = {
      'type': promptType,
      'from': from?.toIso8601String(),
      'to': to?.toIso8601String(),
      ...?extra,
    };
    final cached = await _cache.get(combinedPrompt, cacheKeyFilters);
    if (cached != null) return cached;

    // 4. API Call
    if (_apiKey.isEmpty) {
      return "AI tahlili uchun API kalit sozlanmagan. Iltimos, administratorga murojaat qiling.";
    }

    try {
      final response = await _callGemini(combinedPrompt);
      if (response != null) {
        await _cache.save(combinedPrompt, cacheKeyFilters, response);
        return response;
      }
      return "AI tahlili vaqtinchalik mavjud emas.";
    } catch (e) {
      return "Xatolik yuz berdi: $e. Internet ulanishini tekshiring.";
    }
  }

  String _getSystemPrompt() {
    return '''
You are an assistant for a restaurant POS system called TEZZRO.
You must reply in Uzbek (latin) only.
Be short, clear, and practical (no fluff).
Use numbers formatted like "10 000".
Do NOT invent data. Only use the provided JSON.
If data is missing, say what is missing and give a safe assumption-free answer.
Output format:
- 3–6 bullet points
- then "Tavsiya:" section with 1–3 actionable suggestions.
''';
  }

  String _getUserPrompt(
    String type,
    String dataJson,
    Map<String, dynamic>? extra,
  ) {
    switch (type) {
      case 'general_report':
        return '''
Analyze the following restaurant sales snapshot and write a simple summary for the owner.

CONTEXT:
- Period: ${extra?['from_date'] ?? 'N/A'} to ${extra?['to_date'] ?? 'N/A'}
- Filters: ${extra?['filters'] ?? 'None'}

DATA (JSON):
$dataJson

REQUIREMENTS:
1) Summarize performance: total revenue, orders count, average check.
2) Identify top 5 products by revenue and by quantity.
3) Identify bottom 3 products (low sales).
4) Identify any anomaly.
5) Provide 1–3 concrete recommendations.
''';
      case 'menu_optimization':
        return '''
You are analyzing product performance for menu optimization.
DATA (JSON):
$dataJson

Tasks:
- Pick 5 best-selling items (qty + revenue).
- Pick 5 weakest items.
- Suggest: keep / promote / rename / bundle / temporarily hide.
- Suggest 2 bundle ideas based on top items.
''';
      case 'waiter_analysis':
        return '''
Analyze waiter performance.
DATA (JSON):
$dataJson

Tasks:
- Rank top 3 waiters by revenue and by order count.
- Identify possible issues.
- Give 1–3 management suggestions.
''';
      case 'dashboard_summary':
        return '''
Write a very short "Today summary" for the cashier/owner.
DATA (JSON):
$dataJson

Rules:
- Max 5 bullets.
- Focus on: revenue, orders, top 1 product, any warning.
- End with "Tavsiya:" and 1 suggestion.
''';
      default:
        return "Analyze this data:\n$dataJson";
    }
  }

  Future<String?> _callGemini(String prompt) async {
    final response = await http.post(
      Uri.parse("$_baseUrl?key=$_apiKey"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    }
    return null;
  }
}
