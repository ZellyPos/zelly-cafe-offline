import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/repositories/report_repository.dart';
import 'connectivity_provider.dart';

class ReportFilter {
  DateTime startDate;
  DateTime endDate;
  int? orderType;
  int? locationId;
  int? waiterId;

  ReportFilter({
    required this.startDate,
    required this.endDate,
    this.orderType,
    this.locationId,
    this.waiterId,
  });
}

class ReportProvider extends ChangeNotifier {
  final ReportRepository _repo;

  ReportProvider({ReportRepository? repository})
    : _repo = repository ?? ReportRepository();

  final ReportFilter _filter = ReportFilter(
    startDate: DateTime.now(),
    endDate: DateTime.now(),
  );

  ReportFilter get filter => _filter;
  DateTime get dateFrom => _filter.startDate;
  DateTime get dateTo => _filter.endDate;

  bool _filterInitialized = false;
  bool get filterInitialized => _filterInitialized;

  String _activeChipKey = 'today';
  String get activeChipKey => _activeChipKey;

  final bool _isLoading = false;
  bool get isLoading => _isLoading;

  ConnectivityProvider? _connectivity;
  void setConnectivity(ConnectivityProvider c) {
    _connectivity = c;
  }

  bool get _isClient =>
      _connectivity?.mode == ConnectivityMode.client;

  String get _baseUrl => _connectivity?.clientBaseUrl ?? '';

  Map<String, String> get _baseParams => {
        'start': _filter.startDate.toIso8601String(),
        'end': _filter.endDate.toIso8601String(),
        if (_filter.orderType != null) 'order_type': '${_filter.orderType}',
        if (_filter.locationId != null) 'location_id': '${_filter.locationId}',
        if (_filter.waiterId != null) 'waiter_id': '${_filter.waiterId}',
      };

  Future<dynamic> _remoteGet(String path, [Map<String, String>? params]) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: params ?? _baseParams,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Report fetch failed: ${response.statusCode}');
  }

  Future<Map<String, dynamic>>? _dashboardStatsFuture;

  void updateFilter({
    DateTime? startDate,
    DateTime? endDate,
    int? orderType,
    int? locationId,
    int? waiterId,
    bool clearOrderType = false,
    bool clearLocation = false,
    bool clearWaiter = false,
    String? chipKey,
  }) {
    _filterInitialized = true;
    if (chipKey != null) _activeChipKey = chipKey;
    if (startDate != null) _filter.startDate = startDate;
    if (endDate != null) _filter.endDate = endDate;

    if (clearOrderType) {
      _filter.orderType = null;
    } else if (orderType != null) {
      _filter.orderType = orderType;
    }

    if (clearLocation) {
      _filter.locationId = null;
    } else if (locationId != null) {
      _filter.locationId = locationId;
    }

    if (clearWaiter) {
      _filter.waiterId = null;
    } else if (waiterId != null) {
      _filter.waiterId = waiterId;
    }

    _dashboardStatsFuture = null;
    notifyListeners();
  }

  // ── Dashboard Aggregates ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDashboardStats() {
    return _dashboardStatsFuture ??= _fetchDashboardStats();
  }

  Future<Map<String, dynamic>> _fetchDashboardStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/stats');
      return Map<String, dynamic>.from(data as Map);
    }
    return _repo.getDashboardStats(
      start: _filter.startDate,
      end: _filter.endDate,
      orderType: _filter.orderType,
      locationId: _filter.locationId,
      waiterId: _filter.waiterId,
    );
  }

  // ── Orders List ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getOrders() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/orders');
      return List<Map<String, dynamic>>.from(data as List);
    }
    return _repo.getOrders(
      start: _filter.startDate,
      end: _filter.endDate,
      orderType: _filter.orderType,
      locationId: _filter.locationId,
      waiterId: _filter.waiterId,
    );
  }

  // ── Product Stats ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getProductStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/products');
      return List<Map<String, dynamic>>.from(data as List);
    }
    return _repo.getProductStats(
      start: _filter.startDate,
      end: _filter.endDate,
      orderType: _filter.orderType,
      locationId: _filter.locationId,
      waiterId: _filter.waiterId,
    );
  }

  // ── Waiter Stats ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getWaiterStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/waiters');
      return List<Map<String, dynamic>>.from(data as List);
    }
    return _repo.getWaiterStats(
      start: _filter.startDate,
      end: _filter.endDate,
      orderType: _filter.orderType,
      locationId: _filter.locationId,
    );
  }

  // ── Location Stats ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLocationStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/locations',
          {'start': _filter.startDate.toIso8601String(), 'end': _filter.endDate.toIso8601String()});
      return List<Map<String, dynamic>>.from(data as List);
    }
    return _repo.getLocationStats(
      start: _filter.startDate,
      end: _filter.endDate,
    );
  }

  // ── Table Stats ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTableStats() async {
    if (_isClient) {
      final data = await _remoteGet('/reports/tables',
          {'start': _filter.startDate.toIso8601String(), 'end': _filter.endDate.toIso8601String()});
      return List<Map<String, dynamic>>.from(data as List);
    }
    return _repo.getTableStats(
      start: _filter.startDate,
      end: _filter.endDate,
    );
  }

  // ── Z-Report ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getZReportData() async {
    final dateLabel = _filter.startDate.toIso8601String().split('T')[0];
    final endLabel = _filter.endDate.toIso8601String().split('T')[0];
    final dateStr = dateLabel == endLabel ? dateLabel : '$dateLabel - $endLabel';

    if (_isClient) {
      final data = await _remoteGet('/reports/zreport',
          {'start': _filter.startDate.toIso8601String(), 'end': _filter.endDate.toIso8601String()});
      final m = Map<String, dynamic>.from(data as Map);
      return {
        'date': dateStr,
        'summary': m['summary'],
        'waiters': m['waiterSales'],
        'categories': m['categorySales'],
      };
    }

    final z = await _repo.getZReport(
      startDate: _filter.startDate,
      endDate: _filter.endDate,
    );
    return {
      'date': dateStr,
      'summary': z['summary'],
      'waiters': z['waiters'],
      'categories': z['categories'],
    };
  }

  // ── Order Details ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getOrderDetails(String orderId) {
    return _repo.getOrderDetails(orderId);
  }

  Future<List<Map<String, dynamic>>> getOrderItems(String orderId) {
    return _repo.getOrderItems(orderId);
  }
}
