import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import '../widgets/filter_bar.dart';
import '../../../core/services/export_service.dart';
import 'package:share_plus/share_plus.dart';

class GeneralReportScreen extends StatelessWidget {
  const GeneralReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          "Umumiy Hisobot (Z-Hisobot)",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final data = await reportProvider.getZReportData();
                  final success = await PrintingService.printZReport(
                    settings: printerProvider.settings,
                    data: data,
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
              label: const Text("Z-PV"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.table_view, color: Colors.green),
            tooltip: "Excel",
            onPressed: () async {
              final data = await reportProvider.getZReportData();
              final categories = data['categories'] as List? ?? [];
              final headers = ['Kategoriya', 'Miqdor', 'Tushum'];
              final rows = categories
                  .map(
                    (c) => [
                      c['category'] ?? '',
                      c['qty'] ?? 0,
                      c['total'] ?? 0,
                    ],
                  )
                  .toList();
              final path = await ExportService.instance.exportToExcel(
                fileName: 'ZReport_${DateTime.now().millisecondsSinceEpoch}',
                sheetName: 'Kategoriyalar',
                headers: headers,
                rows: rows,
              );
              if (path != null && context.mounted) {
                await Share.shareXFiles([
                  XFile(path),
                ], text: 'Z-Report (Excel)');
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            tooltip: "PDF",
            onPressed: () async {
              final data = await reportProvider.getZReportData();
              final summary = data['summary'] ?? {};
              final categories = (data['categories'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              final path = await ExportService.instance.exportSummaryToPDF(
                title: 'Z-Report',
                dateRange: data['date'] ?? '',
                summary: Map<String, dynamic>.from(summary),
                items: categories,
                itemHeaders: ['Kategoriya', 'Miqdor', 'Tushum'],
                itemKeys: ['category', 'qty', 'total'],
              );
              if (path != null && context.mounted) {
                await Share.shareXFiles([XFile(path)], text: 'Z-Report (PDF)');
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const ReportFilterBar(),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: reportProvider.getZReportData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? {};
                final summary = data['summary'] ?? {};
                final waiters = data['waiters'] as List? ?? [];
                final categories = data['categories'] as List? ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Financial Summary
                      _buildSectionTitle("Moliyaviy Xulosa"),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildSummaryCard(
                            context,
                            "Jami Savdo",
                            "${PriceFormatter.format((summary['total'] as num?)?.toDouble() ?? 0)} so'm",
                            Icons.account_balance,
                            Colors.green,
                          ),
                          _buildSummaryCard(
                            context,
                            "Cheklar Soni",
                            "${summary['count'] ?? 0} ta",
                            Icons.receipt,
                            Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildMiniCard(
                            context,
                            "Naqd: ${PriceFormatter.format((summary['cash_total'] as num?)?.toDouble() ?? 0)}",
                            Colors.orange,
                          ),
                          _buildMiniCard(
                            context,
                            "Karta: ${PriceFormatter.format((summary['card_total'] as num?)?.toDouble() ?? 0)}",
                            Colors.purple,
                          ),
                          _buildMiniCard(
                            context,
                            "Terminal: ${PriceFormatter.format((summary['terminal_total'] as num?)?.toDouble() ?? 0)}",
                            Colors.indigo,
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      MediaQuery.of(context).size.width <= 1100
                          ? Column(
                              children: [
                                _buildBreakdownList(
                                  "Xodimlar Savdosi",
                                  waiters,
                                  'name',
                                  'sales',
                                ),
                                const SizedBox(height: 32),
                                _buildBreakdownList(
                                  "Kategoriyalar",
                                  categories,
                                  'category',
                                  'total',
                                ),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Waiter Breakdown
                                Expanded(
                                  child: _buildBreakdownList(
                                    "Xodimlar Savdosi",
                                    waiters,
                                    'name',
                                    'sales',
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Category Breakdown
                                Expanded(
                                  child: _buildBreakdownList(
                                    "Kategoriyalar",
                                    categories,
                                    'category',
                                    'total',
                                  ),
                                ),
                              ],
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0F172A),
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width <= 1100 ? 240 : 300,
        maxWidth: MediaQuery.of(context).size.width <= 1100
            ? 500
            : double.infinity,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
    );
  }

  Widget _buildMiniCard(BuildContext context, String text, Color color) {
    return Container(
      width: MediaQuery.of(context).size.width <= 1100 ? 220 : 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBreakdownList(
    String title,
    List items,
    String keyLabel,
    String keyValue,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(title),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item[keyLabel]?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "${PriceFormatter.format((item[keyValue] as num?)?.toDouble() ?? 0)} so'm",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
