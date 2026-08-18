import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/filter_bar.dart';

class ProductsReportScreen extends StatefulWidget {
  const ProductsReportScreen({super.key});

  @override
  State<ProductsReportScreen> createState() => _ProductsReportScreenState();
}

class _ProductsReportScreenState extends State<ProductsReportScreen> {
  final Set<String> _selectedCategories = {}; // bo'sh = barchasi

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'Taomlar Hisoboti',
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
                  final filtered = _applyCategory(stats);
                  final filter = reportProvider.filter;
                  final dateRange =
                      "${DateFormat('dd.MM.yyyy').format(filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(filter.endDate)}";
                  final success =
                      await PrintingService.printProductPerformanceReport(
                    settings: printerProvider.settings,
                    products: filtered,
                    dateRange: dateRange,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content:
                          Text(success ? 'Chek chiqarildi' : 'Xatolik yuz berdi'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ));
                  }
                } catch (e) {
                  if (context.mounted) {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Chop etishda xatolik'),
                        content: SingleChildScrollView(child: Text('$e')),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('OK'))
                        ],
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.print),
              label: const Text('Chek chiqarish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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

                final allStats = snapshot.data ?? [];
                final categories = _extractCategories(allStats);
                final stats = _applyCategory(allStats);

                double totalRevenue = 0;
                int totalQty = 0;
                for (final item in stats) {
                  totalRevenue += (item['total_revenue'] as num).toDouble();
                  totalQty += (item['total_qty'] as num).toInt();
                }

                return Column(
                  children: [
                    // ── Kategoriya filter chiqlari ─────────────────────────
                    if (categories.isNotEmpty)
                      _CategoryFilterBar(
                        categories: categories,
                        selected: _selectedCategories,
                        onToggle: (cat) => setState(() {
                          if (_selectedCategories.contains(cat)) {
                            _selectedCategories.remove(cat);
                          } else {
                            _selectedCategories.add(cat);
                          }
                        }),
                        onClearAll: () =>
                            setState(() => _selectedCategories.clear()),
                      ),

                    // ── Asosiy kontent ─────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _buildSummaryCard(
                                  'Jami sotilgan son',
                                  '$totalQty ta',
                                  Icons.shopping_basket_outlined,
                                  Colors.blue,
                                ),
                                const SizedBox(width: 24),
                                _buildSummaryCard(
                                  'Jami summa',
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
                                    color: Colors.black.withValues(alpha:0.02),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _buildTableHeader(),
                                  if (stats.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(48.0),
                                      child: Text(
                                        "Ma'lumot topilmadi",
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    )
                                  else
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: stats.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(
                                              height: 1,
                                              indent: 24,
                                              endIndent: 24),
                                      itemBuilder: (_, i) =>
                                          _buildProductRow(stats[i]),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
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

  List<String> _extractCategories(List<Map<String, dynamic>> stats) {
    final seen = <String>{};
    final cats = <String>[];
    for (final item in stats) {
      final c = item['category'] as String? ?? '';
      if (c.isNotEmpty && seen.add(c)) cats.add(c);
    }
    cats.sort();
    return cats;
  }

  List<Map<String, dynamic>> _applyCategory(
      List<Map<String, dynamic>> stats) {
    if (_selectedCategories.isEmpty) return stats;
    return stats
        .where((item) =>
            _selectedCategories.contains(item['category'] as String? ?? ''))
        .toList();
  }

  Widget _buildSummaryCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha:0.03), blurRadius: 10),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 13)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B))),
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
      child: const Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('Taom nomi',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B)))),
          Expanded(
              flex: 2,
              child: Text('Kategoriya',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Sotildi',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 1,
              child: Text('Qoldiq',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center)),
          Expanded(
              flex: 2,
              child: Text('Jami summa',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildProductRow(Map<String, dynamic> item) {
    final double soldQty = (item['total_qty'] as num).toDouble();
    final double? currentStock =
        (item['current_stock'] as num?)?.toDouble();
    final String category = item['category'] as String? ?? '—';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(item['name'],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15))),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha:0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6366F1)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Expanded(
              flex: 1,
              child: Text('${soldQty.toStringAsFixed(0)} ta',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            flex: 1,
            child: Text(
              currentStock != null
                  ? '${currentStock.toStringAsFixed(0)} ta'
                  : '—',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: currentStock != null
                    ? ((currentStock <= 5) ? Colors.red : Colors.orange)
                    : Colors.grey,
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
                  fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kategoriya filter paneli (ko'p tanlash) ───────────────────────────────

class _CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final VoidCallback onClearAll;

  const _CategoryFilterBar({
    required this.categories,
    required this.selected,
    required this.onToggle,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFF6366F1);
    final allActive = selected.isEmpty;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip(
            label: 'Barchasi',
            active: allActive,
            accent: accent,
            theme: theme,
            onTap: onClearAll,
          ),
          const SizedBox(width: 6),
          ...categories.map((cat) {
            final active = selected.contains(cat);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                label: cat,
                active: active,
                accent: accent,
                theme: theme,
                onTap: () => onToggle(cat),
                badge: active && selected.length > 1,
              ),
            );
          }),
        ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool active,
    required Color accent,
    required ThemeData theme,
    required VoidCallback onTap,
    bool badge = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? accent
                : theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (active)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.check_rounded,
                    size: 11, color: Colors.white.withValues(alpha: 0.9)),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
