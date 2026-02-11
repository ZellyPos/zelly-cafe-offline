import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/filter_bar.dart';

class TablesReportScreen extends StatelessWidget {
  const TablesReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Stollar Hisoboti",
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
                  final stats = await reportProvider.getTableStats();
                  final filter = reportProvider.filter;
                  final dateRange =
                      "${DateFormat('dd.MM.yyyy').format(filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(filter.endDate)}";

                  final success = await PrintingService.printTablesReport(
                    settings: printerProvider.settings,
                    tables: stats,
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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: reportProvider.getTableStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = snapshot.data ?? [];

                return GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: stats.length,
                  itemBuilder: (context, index) {
                    final table = stats[index];
                    return _buildTableCard(table);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(Map<String, dynamic> table) {
    final String name = table['table_name']?.toString() ?? '';
    final String location = table['location_name']?.toString() ?? '';
    final int count = (table['order_count'] as num?)?.toInt() ?? 0;
    final String total = PriceFormatter.format(
      (table['total_revenue'] as num?)?.toDouble() ?? 0.0,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            location,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          _buildStatRow("Buyurtmalar", "$count ta"),
          const SizedBox(height: 8),
          _buildStatRow(
            "Jami tushum",
            "$total so'm",
            isBold: true,
            color: Colors.indigo,
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
