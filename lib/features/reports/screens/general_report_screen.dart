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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Umumiy Hisobot (Z-Hisobot)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
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
                        title: const Text('Chop etishda xatolik'),
                        content: SingleChildScrollView(
                          child: Text('Xatolik xabari: $e'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Z-PV'),
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
            tooltip: 'Excel',
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
            tooltip: 'PDF',
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
                      _buildSectionTitle(context, 'Moliyaviy Xulosa'),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildSummaryCard(
                            context,
                            'Jami Savdo',
                            "${PriceFormatter.format((summary['total'] as num?)?.toDouble() ?? 0)} so'm",
                            Icons.account_balance,
                            Colors.green,
                          ),
                          _buildSummaryCard(
                            context,
                            'Cheklar Soni',
                            "${summary['count'] ?? 0} ta",
                            Icons.receipt,
                            Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentBreakdown(context, summary),
                      _buildDiscountBlock(context, summary),
                      const SizedBox(height: 48),

                      MediaQuery.of(context).size.width <= 1100
                          ? Column(
                              children: [
                                _buildBreakdownList(
                                  context,
                                  'Xodimlar Savdosi',
                                  waiters,
                                  'name',
                                  'sales',
                                ),
                                const SizedBox(height: 32),
                                _buildBreakdownList(
                                  context,
                                  'Kategoriyalar',
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
                                    context,
                                    'Xodimlar Savdosi',
                                    waiters,
                                    'name',
                                    'sales',
                                  ),
                                ),
                                const SizedBox(width: 32),
                                // Category Breakdown
                                Expanded(
                                  child: _buildBreakdownList(
                                    context,
                                    'Kategoriyalar',
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

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width <= 1100 ? 240 : 300,
        maxWidth: MediaQuery.of(context).size.width <= 1100
            ? 500
            : double.infinity,
      ),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: theme.shadowColor.withValues(alpha: 0.03), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
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
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // To'lov turlari bo'yicha breakdown (6 ta tur)
  Widget _buildPaymentBreakdown(BuildContext context, Map<String, dynamic> summary) {
    final theme = Theme.of(context);

    final items = [
      ('💵 Naqd',     summary['cash_total'],     const Color(0xFF10B981)),
      ('💳 Karta',    summary['card_total'],     const Color(0xFF3B82F6)),
      ('🖥️ Terminal', summary['terminal_total'], const Color(0xFF8B5CF6)),
      ('⭐ Bonus',    summary['bonus_total'],    const Color(0xFFF59E0B)),
      ('📒 Qarz',     summary['debt_total'],     Colors.red),
      ('📲 O\'tkazma',summary['transfer_total'], const Color(0xFF06B6D4)),
    ].where((e) => ((e.$2 as num?)?.toDouble() ?? 0) > 0).toList();

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TO'LOV TURLARI",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Text(item.$1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(
                  '${PriceFormatter.format((item.$2 as num?)?.toDouble() ?? 0)} so\'m',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: item.$3,
                  ),
                ),
              ],
            ),
          )),
          const Divider(height: 20),
          Row(
            children: [
              const Text('Jami:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(
                '${PriceFormatter.format(items.fold(0.0, (s, e) => s + ((e.$2 as num?)?.toDouble() ?? 0)))} so\'m',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Chegirma bloki — faqat total_discount > 0 bo'lganda ko'rinadi
  Widget _buildDiscountBlock(BuildContext context, Map<String, dynamic> summary) {
    final totalDiscount = (summary['total_discount'] as num?)?.toDouble() ?? 0;
    if (totalDiscount <= 0) return const SizedBox.shrink();

    final orderDisc = (summary['order_discount_total'] as num?)?.toDouble() ?? 0;
    final itemDisc  = (summary['item_discount_total']  as num?)?.toDouble() ?? 0;
    final orderCount = summary['order_discount_count'] ?? 0;
    final grossSales = ((summary['total'] as num?)?.toDouble() ?? 0) + totalDiscount;
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CHEGIRMALAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          if (orderDisc > 0)
            _discRow(
              context,
              'Buyurtma chegirmalari ($orderCount ta):',
              orderDisc,
            ),
          if (itemDisc > 0)
            _discRow(context, 'Mahsulot chegirmalari:', itemDisc),
          const Divider(height: 18),
          _discRow(context, 'Jami chegirma:', totalDiscount, bold: true),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chegirmasiz savdo:',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                "${PriceFormatter.format(grossSales)} so'm",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _discRow(BuildContext context, String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                color: bold ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              )),
          Text(
            "- ${PriceFormatter.format(value)} so'm",
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBreakdownList(
    BuildContext context,
    String title,
    List items,
    String keyLabel,
    String keyValue,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, title),
        const SizedBox(height: 16),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.brightness == Brightness.light
                      ? const Color(0xFFE2E8F0)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      item[keyLabel]?.toString() ?? '',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
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
