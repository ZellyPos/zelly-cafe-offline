import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/filter_bar.dart';
import '../widgets/order_details_dialog.dart';

class OrdersReportScreen extends StatelessWidget {
  const OrdersReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Buyurtmalar Hisoboti",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final orders = await reportProvider.getOrders();
                  final filter = reportProvider.filter;
                  final dateRange =
                      "${DateFormat('dd.MM.yyyy').format(filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(filter.endDate)}";

                  final success = await PrintingService.printOrdersReport(
                    settings: printerProvider.settings,
                    orders: orders,
                    dateRange: dateRange,
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? 'Chek chiqarildi' : 'Xatolik yuz berdi',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Chop etishda xatolik"),
                        content: SingleChildScrollView(
                          child: Text("Xatolik xabari: $e"),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("OK"),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text("Chek chiqarish"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const ReportFilterBar(),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: reportProvider.getDashboardStats(),
              builder: (context, statsSnapshot) {
                final metrics = statsSnapshot.data?['metrics'] ?? {};
                final totalRevenue =
                    (metrics['total'] as num?)?.toDouble() ?? 0.0;
                final orderCount = (metrics['count'] as num?)?.toInt() ?? 0;
                final avgCheck =
                    (metrics['avg_check'] as num?)?.toDouble() ?? 0.0;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        children: [
                          _buildSummaryCard(
                            "Buyurtmalar",
                            "$orderCount ta",
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            "Jami savdo",
                            "${PriceFormatter.format(totalRevenue)} so'm",
                            Icons.payments,
                            Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _buildSummaryCard(
                            "O'rtacha chek",
                            "${PriceFormatter.format(avgCheck)} so'm",
                            Icons.analytics,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: reportProvider.getOrders(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final orders = snapshot.data ?? [];

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            itemCount: orders.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final order = orders[index];
                              return _buildOrderRow(context, order);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderRow(BuildContext context, Map<String, dynamic> order) {
    final String idStr = order['id']?.toString() ?? '';
    final String id = idStr.length >= 8
        ? idStr.substring(0, 8).toUpperCase()
        : idStr.toUpperCase();
    final String? dailyNumber = order['daily_number']?.toString();
    final String displayId = dailyNumber != null
        ? "№$dailyNumber (#$id)"
        : "#$id";

    final String createdAtRaw = order['created_at']?.toString() ?? '';
    final String time = createdAtRaw.length >= 16
        ? createdAtRaw.substring(11, 16)
        : '--:--';

    final String total = PriceFormatter.format(
      (order['total'] as num?)?.toDouble() ?? 0.0,
    );
    final bool isDineIn = order['order_type']?.toString() == '0';

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => OrderDetailsDialog(orderId: order['id']),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDineIn ? Colors.blue : Colors.orange).withOpacity(
                  0.1,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isDineIn ? Icons.restaurant : Icons.shopping_bag,
                color: isDineIn ? Colors.blue : Colors.orange,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$displayId • $time",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${order['waiter_name'] ?? 'Kassa'} • ${order['location_name'] ?? '-'}/${order['table_name'] ?? '-'}",
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$total so'm",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green,
                  ),
                ),
                Text(
                  order['payment_type'] ?? "Kassa",
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }
}
