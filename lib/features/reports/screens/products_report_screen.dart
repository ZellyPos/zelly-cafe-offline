import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/filter_bar.dart';

class ProductsReportScreen extends StatelessWidget {
  const ProductsReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Taomlar Hisoboti",
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
                  final stats = await reportProvider.getProductStats();
                  final filter = reportProvider.filter;
                  final dateRange =
                      "${DateFormat('dd.MM.yyyy').format(filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(filter.endDate)}";

                  final success =
                      await PrintingService.printProductPerformanceReport(
                        settings: printerProvider.settings,
                        products: stats,
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
              future: reportProvider.getProductStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final stats = snapshot.data ?? [];

                double totalRevenue = 0;
                int totalQty = 0;
                for (var item in stats) {
                  totalRevenue += (item['total_revenue'] as num).toDouble();
                  totalQty += (item['total_qty'] as num).toInt();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildSummaryCard(
                            "Jami sotilgan son",
                            "$totalQty ta",
                            Icons.shopping_basket_outlined,
                            Colors.blue,
                          ),
                          const SizedBox(width: 24),
                          _buildSummaryCard(
                            "Jami summa",
                            "${PriceFormatter.format(totalRevenue)} so'm",
                            Icons.payments_outlined,
                            Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _buildTableHeader(),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: stats.length,
                              separatorBuilder: (_, __) => const Divider(
                                height: 1,
                                indent: 24,
                                endIndent: 24,
                              ),
                              itemBuilder: (context, index) {
                                final item = stats[index];
                                return _buildProductRow(item);
                              },
                            ),
                            if (stats.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(48.0),
                                child: Text(
                                  "Ma'lumot topilmadi",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                          ],
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
    return Expanded(
      child: Container(
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: const [
          Expanded(
            flex: 3,
            child: Text(
              "Taom nomi",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Kirim",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Sotildi",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "Qoldiq",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "Jami summa",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item) {
    final double soldQty = (item['total_qty'] as num).toDouble();
    final double? currentStock = (item['current_stock'] as num?)?.toDouble();
    final double kirimQty = currentStock != null
        ? (soldQty + currentStock)
        : soldQty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              currentStock != null ? "${kirimQty.toStringAsFixed(0)} ta" : "-",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              "${soldQty.toStringAsFixed(0)} ta",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              currentStock != null
                  ? "${currentStock.toStringAsFixed(0)} ta"
                  : "-",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: (currentStock ?? 0) <= 5 ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "${PriceFormatter.format((item['total_revenue'] as num).toDouble())} so'm",
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
