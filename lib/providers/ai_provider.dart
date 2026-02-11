import 'package:flutter/material.dart';
import '../core/services/ai_service.dart';

class AiProvider extends ChangeNotifier {
  final AiService _aiService = AiService();

  bool _isLoading = false;
  String? _lastResult;
  String? _error;

  bool get isLoading => _isLoading;
  String? get lastResult => _lastResult;
  String? get error => _error;

  void clear() {
    _lastResult = null;
    _error = null;
    notifyListeners();
  }

  Future<void> getDashboardSummary() async {
    await _runAnalysis('dashboard_summary');
  }

  Future<void> getGeneralReport(
    DateTime from,
    DateTime to, {
    String? filters,
  }) async {
    await _runAnalysis(
      'general_report',
      from: from,
      to: to,
      extra: {
        'from_date': from.toIso8601String().split('T')[0],
        'to_date': to.toIso8601String().split('T')[0],
        'filters': filters ?? 'None',
      },
    );
  }

  Future<void> getMenuOptimization(DateTime from, DateTime to) async {
    await _runAnalysis('menu_optimization', from: from, to: to);
  }

  Future<void> getWaiterAnalysis(DateTime from, DateTime to) async {
    await _runAnalysis('waiter_analysis', from: from, to: to);
  }

  Future<void> _runAnalysis(
    String type, {
    DateTime? from,
    DateTime? to,
    Map<String, dynamic>? extra,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _lastResult = await _aiService.analyze(
        type,
        from: from,
        to: to,
        extra: extra,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
