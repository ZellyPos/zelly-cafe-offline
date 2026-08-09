import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../providers/report_provider.dart';
import '../../../core/printing_service.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../models/order.dart';

class OrderDetailsDialog extends StatefulWidget {
  final String orderId;

  const OrderDetailsDialog({super.key, required this.orderId});

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  bool _printing = false;

  Future<void> _printReceipt(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> items,
  ) async {
    setState(() => _printing = true);
    try {
      final orderItems = items
          .map((item) => OrderItem(
                orderId: widget.orderId,
                productId: (item['product_id'] as num?)?.toInt() ?? 0,
                productName: item['product_name'] ?? '',
                qty: (item['qty'] as num).toDouble(),
                price: (item['price'] as num).toDouble(),
                unit: item['unit']?.toString(),
              ))
          .toList();

      final o = Order(
        id: widget.orderId,
        total: (order['total'] as num?)?.toDouble() ?? 0.0,
        paymentType: order['payment_type'] ?? '',
        createdAt: DateTime.tryParse(order['created_at'] ?? '') ?? DateTime.now(),
        items: orderItems,
        orderType: (order['order_type'] as num?)?.toInt() ?? 0,
        tableId: (order['table_id'] as num?)?.toInt(),
        locationId: (order['location_id'] as num?)?.toInt(),
        waiterId: (order['waiter_id'] as num?)?.toInt(),
        status: 1,
        tableName: order['table_name']?.toString(),
        locationName: order['location_name']?.toString(),
        waiterName: order['waiter_name']?.toString(),
        foodTotal: (order['food_total'] as num?)?.toDouble() ?? 0.0,
        roomCharge: (order['room_charge'] as num?)?.toDouble() ??
            (order['room_total'] as num?)?.toDouble() ?? 0.0,
        serviceTotal: (order['service_total'] as num?)?.toDouble() ?? 0.0,
        grandTotal: (order['grand_total'] as num?)?.toDouble() ??
            (order['total'] as num?)?.toDouble() ?? 0.0,
        paidAmount: (order['paid_amount'] as num?)?.toDouble() ?? 0.0,
        change: (order['change_amount'] as num?)?.toDouble() ?? 0.0,
        dailyNumber: (order['daily_number'] as num?)?.toInt(),
        note: order['note']?.toString(),
      );

      final success = await PrintingService.printReceipt(order: o);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? 'Chek chiqarildi' : 'Chek chiqarishda xatolik'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Xatolik: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width <= 1100 ? 500 : 600,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 550;

            return FutureBuilder<Map<String, dynamic>?>(
              future: context.read<ReportProvider>().getOrderDetails(widget.orderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final order = snapshot.data;
                if (order == null) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: Text('Buyurtma topilmadi')),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, order),
                    const Divider(height: 32),
                    const Text(
                      'Buyurtma tarkibi:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Expanded(child: _buildItemsList(context, isCompact, order)),
                    const Divider(height: 32),
                    _buildFooter(context, order, isCompact),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> order) {
    final String id = order['id'].toString().length >= 8
        ? order['id'].toString().substring(0, 8).toUpperCase()
        : order['id'].toString().toUpperCase();
    final String? dailyNo = order['daily_number']?.toString();
    final String displayId = dailyNo != null ? '№$dailyNo (#$id)' : '#$id';
    final DateTime date = DateTime.parse(order['created_at']);
    final String type = order['order_type'] == 0 ? 'Stol' : 'Saboy';
    final String location = order['location_name'] ?? '-';
    final String table = order['table_name'] ?? '-';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Buyurtma $displayId',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('dd.MM.yyyy HH:mm').format(date)} • $location / $table',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _buildItemsList(
    BuildContext context,
    bool isCompact,
    Map<String, dynamic> order,
  ) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<ReportProvider>().getOrderItems(widget.orderId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!;
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            final double price = (item['price'] as num).toDouble();
            final int qty = (item['qty'] as num).toInt();
            final double total = price * qty;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['product_name'] ?? '',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: isCompact ? 13 : 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${PriceFormatter.format(price)} x $qty',
                          style: TextStyle(
                              fontSize: isCompact ? 11 : 12,
                              color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${PriceFormatter.format(total)} so\'m',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isCompact ? 13 : 14),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(
    BuildContext context,
    Map<String, dynamic> order,
    bool isCompact,
  ) {
    final double grandTotal = (order['grand_total'] as num?)?.toDouble() ??
        (order['total'] as num?)?.toDouble() ?? 0.0;
    final double foodTotal =
        (order['food_total'] as num?)?.toDouble() ?? 0.0;
    final double roomTotal =
        (order['room_total'] as num?)?.toDouble() ??
        (order['room_charge'] as num?)?.toDouble() ?? 0.0;
    final double serviceTotal =
        (order['service_total'] as num?)?.toDouble() ?? 0.0;
    return Column(
      children: [
        _buildSummaryRow(
          'Taomlar:',
          PriceFormatter.format(
            foodTotal > 0 ? foodTotal : grandTotal - roomTotal - serviceTotal,
          ),
        ),
        if (roomTotal > 0) ...[
          const SizedBox(height: 4),
          _buildSummaryRow('Xona/Stol:', PriceFormatter.format(roomTotal)),
        ],
        if (serviceTotal > 0) ...[
          const SizedBox(height: 4),
          _buildSummaryRow(
              'Ofitsiant xizmati:', PriceFormatter.format(serviceTotal)),
        ],
        const Divider(height: 24),
        _buildSummaryRow(
          'Jami:',
          PriceFormatter.format(grandTotal),
          isTotal: true,
        ),
        const SizedBox(height: 12),
        // To'lov turlari — order_payments dan
        FutureBuilder<List<Map<String, dynamic>>>(
          future: OrderRepository().getOrderPayments(widget.orderId),
          builder: (ctx, snap) {
            final payments = snap.data ?? [];
            if (payments.isEmpty) {
              // Eski yozuvlar uchun fallback
              final fallback = order['payment_type'] ?? 'Kassa';
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("To'lov turi:", style: TextStyle(color: Colors.grey)),
                  _paymentChip(fallback, Colors.blue),
                ],
              );
            }
            if (payments.length == 1) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("To'lov turi:", style: TextStyle(color: Colors.grey)),
                  _paymentChip(payments.first['payment_type'] as String, Colors.blue),
                ],
              );
            }
            // Split payment — bir nechta tur
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("To'lov turlari:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                ...payments.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _paymentChip(p['payment_type'] as String, Colors.blue),
                      Text(
                        PriceFormatter.format((p['amount'] as num?)?.toDouble() ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                )),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildPrintButton(context, order),
      ],
    );
  }

  Widget _paymentChip(String type, Color color) {
    const labels = {
      'cash': '💵 Naqd', 'Cash': '💵 Naqd',
      'card': '💳 Karta', 'Card': '💳 Karta',
      'terminal': '🖥️ Terminal', 'Terminal': '🖥️ Terminal',
      'bonus': '⭐ Bonus', 'Bonus': '⭐ Bonus',
      'debt': '📒 Qarz', 'Debt': '📒 Qarz',
      'transfer': '📲 O\'tkazma', 'Transfer': '📲 O\'tkazma',
    };
    final label = labels[type] ?? type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color.withValues(alpha: 0.85), fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Widget _buildPrintButton(BuildContext context, Map<String, dynamic> order) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: context.read<ReportProvider>().getOrderItems(widget.orderId),
      builder: (ctx, snap) {
        final items = snap.data ?? [];
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_printing || !snap.hasData)
                ? null
                : () => _printReceipt(order, items),
            icon: _printing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print_rounded),
            label: Text(_printing ? 'Chiqarilmoqda...' : 'Chek chiqarish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value,
      {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight:
                  isTotal ? FontWeight.bold : FontWeight.normal),
        ),
        Text(
          "$value so'm",
          style: TextStyle(
              fontSize: isTotal ? 22 : 14,
              fontWeight:
                  isTotal ? FontWeight.bold : FontWeight.w600,
              color:
                  isTotal ? Colors.blue.shade700 : Colors.black),
        ),
      ],
    );
  }
}
