import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/filter_bar.dart';

class WaitersReportScreen extends StatelessWidget {
  const WaitersReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Xodimlar Hisoboti",
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
                final stats = await reportProvider.getWaiterStats();
                final filter = reportProvider.filter;
                final dateRange =
                    "${DateFormat('dd.MM.yyyy').format(filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(filter.endDate)}";

                await PrintingService.printWaitersReport(
                  settings: printerProvider.settings,
                  waiters: stats,
                  dateRange: dateRange,
                );
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: reportProvider.getWaiterStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = snapshot.data ?? [];
                double totalSales = 0;
                for (var s in stats) {
                  totalSales += (s['total_sales'] as num).toDouble();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryCard(
                        "Jami savdo",
                        "${PriceFormatter.format(totalSales)} so'm",
                        Icons.group,
                        Colors.blue,
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        "Xodimlar kesimida",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 20,
                              mainAxisSpacing: 20,
                              childAspectRatio: 1.6,
                            ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final waiter = stats[index];
                          return _buildWaiterCard(waiter);
                        },
                      ),
                      if (stats.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(48.0),
                            child: Text(
                              "Ma'lumot topilmadi",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                    ],
                  ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWaiterCard(Map<String, dynamic> waiter) {
    final String name = waiter['name'] as String;
    final int count = (waiter['order_count'] as num).toInt();
    final String total = PriceFormatter.format(
      (waiter['total_sales'] as num).toDouble(),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFF1F5F9),
                child: Icon(Icons.person, color: Color(0xFF64748B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildStatRow("Buyurtmalar", "$count ta"),
          const SizedBox(height: 8),
          _buildStatRow(
            "Jami savdo",
            "$total so'm",
            isBold: true,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }
}
