import 'package:flutter/material.dart';
import '../data/repositories/saboy_repository.dart';

class SaboyOrderSummary {
  final String id;
  final int? dailyNumber;
  final double grandTotal;
  final DateTime? openedAt;
  final int status; // 0=open, 1=closed
  final int? waiterId;
  final String? waiterName;
  final int itemCount;

  SaboyOrderSummary({
    required this.id,
    this.dailyNumber,
    required this.grandTotal,
    this.openedAt,
    required this.status,
    this.waiterId,
    this.waiterName,
    required this.itemCount,
  });
}

class SaboyProvider extends ChangeNotifier {
  final SaboyRepository _repo;

  SaboyProvider({SaboyRepository? repository})
    : _repo = repository ?? SaboyRepository();

  List<SaboyOrderSummary> _openOrders = [];
  List<SaboyOrderSummary> _closedOrders = [];
  bool _isLoading = false;

  List<SaboyOrderSummary> get openOrders => _openOrders;
  List<SaboyOrderSummary> get closedOrders => _closedOrders;
  bool get isLoading => _isLoading;

  Future<void> loadOrders() async {
    _isLoading = true;
    notifyListeners();

    try {
      final rows = await _repo.getTodayOrders();

      final open = <SaboyOrderSummary>[];
      final closed = <SaboyOrderSummary>[];

      for (final row in rows) {
        final s = SaboyOrderSummary(
          id: row['id'] as String,
          dailyNumber: row['daily_number'] as int?,
          grandTotal: (row['grand_total'] as num?)?.toDouble() ?? 0.0,
          openedAt: row['opened_at'] != null
              ? DateTime.tryParse(row['opened_at'] as String)
              : null,
          status: (row['status'] as int?) ?? 1,
          waiterId: row['waiter_id'] as int?,
          waiterName: row['waiter_name'] as String?,
          itemCount: (row['item_count'] as num?)?.toInt() ?? 0,
        );
        if (s.status == 0) {
          open.add(s);
        } else {
          closed.add(s);
        }
      }

      _openOrders = open;
      _closedOrders = closed;
    } catch (e) {
      debugPrint('SaboyProvider.loadOrders error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}
