import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/report_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/printing_service.dart';
import '../../../providers/printer_provider.dart';
import 'package:intl/intl.dart';
import '../widgets/filter_bar.dart';

class WaitersReportScreen extends StatefulWidget {
  const WaitersReportScreen({super.key});

  @override
  State<WaitersReportScreen> createState() => _WaitersReportScreenState();
}

class _WaitersReportScreenState extends State<WaitersReportScreen> {
  static const _avatarColors = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFF0984E3),
    Color(0xFFE17055),
    Color(0xFFFDAB3D),
    Color(0xFFD63031),
    Color(0xFF74B9FF),
    Color(0xFF55EFC4),
    Color(0xFFA29BFE),
    Color(0xFFFF7675),
  ];

  final TextEditingController _percentCtrl = TextEditingController();
  double _customPercent = 0;

  @override
  void dispose() {
    _percentCtrl.dispose();
    super.dispose();
  }

  double _calcCommission(Map<String, dynamic> w) {
    final type = (w['waiter_type'] as num?)?.toInt() ?? 0;
    final value = (w['waiter_value'] as num?)?.toDouble() ?? 0;
    final sales = (w['total_sales'] as num?)?.toDouble() ?? 0;
    final orders = (w['order_count'] as num?)?.toInt() ?? 0;
    final isKassa = (w['name'] as String?) == 'Kassa';
    if (isKassa) return 0;
    return type == 1 ? sales * (value / 100) : orders * value;
  }

  double _calcCustom(Map<String, dynamic> w) {
    if (_customPercent <= 0) return 0;
    final sales = (w['total_sales'] as num?)?.toDouble() ?? 0;
    return sales * (_customPercent / 100);
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final printerProvider = context.watch<PrinterProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Xodimlar Hisoboti',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () =>
                  _print(context, reportProvider, printerProvider),
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Chek chiqarish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0984E3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const ReportFilterBar(),

          // ── Foiz kiritish paneli ─────────────────────────────────────────
          _PercentInputBar(
            controller: _percentCtrl,
            percent: _customPercent,
            onChanged: (v) => setState(() => _customPercent = v),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: reportProvider.getWaiterStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6C5CE7)));
                }

                final stats = snapshot.data ?? [];
                if (stats.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 56,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.2)),
                        const SizedBox(height: 12),
                        Text('Ma\'lumot topilmadi',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                              fontSize: 15,
                            )),
                      ],
                    ),
                  );
                }

                double totalSales = 0;
                double totalCommission = 0;
                double totalCustom = 0;
                int totalOrders = 0;
                for (final w in stats) {
                  totalSales +=
                      (w['total_sales'] as num?)?.toDouble() ?? 0;
                  totalCommission += _calcCommission(w);
                  totalCustom += _calcCustom(w);
                  totalOrders +=
                      (w['order_count'] as num?)?.toInt() ?? 0;
                }
                final maxSales = stats.fold(
                    0.0,
                    (m, w) =>
                        ((w['total_sales'] as num?)?.toDouble() ?? 0) > m
                            ? (w['total_sales'] as num).toDouble()
                            : m);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryHeader(
                        totalSales: totalSales,
                        totalCommission: totalCommission,
                        totalOrders: totalOrders,
                        waiterCount: stats.length,
                        isDark: isDark,
                        customPercent: _customPercent,
                        totalCustom: totalCustom,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.people_rounded,
                              size: 18, color: Color(0xFF6C5CE7)),
                          const SizedBox(width: 8),
                          Text(
                            'Xodimlar kesimida',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C5CE7)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${stats.length} kishi',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6C5CE7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: _customPercent > 0 ? 1.45 : 1.7,
                        ),
                        itemCount: stats.length,
                        itemBuilder: (context, index) {
                          final w = stats[index];
                          final color = _avatarColors[
                              index % _avatarColors.length];
                          final commission = _calcCommission(w);
                          final customAmt = _calcCustom(w);
                          final sales =
                              (w['total_sales'] as num?)?.toDouble() ?? 0;
                          final frac =
                              maxSales > 0 ? sales / maxSales : 0.0;
                          return _WaiterCard(
                            waiter: w,
                            color: color,
                            commission: commission,
                            frac: frac,
                            rank: index + 1,
                            isDark: isDark,
                            customPercent: _customPercent,
                            customAmount: customAmt,
                          );
                        },
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

  Future<void> _print(BuildContext context, ReportProvider reportProvider,
      PrinterProvider printerProvider) async {
    try {
      final stats = await reportProvider.getWaiterStats();
      final filter = reportProvider.filter;
      final dateRange =
          '${DateFormat('dd.MM.yyyy').format(filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(filter.endDate)}';
      final success = await PrintingService.printWaitersReport(
        settings: printerProvider.settings,
        waiters: stats,
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
            content: Text(e.toString()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'))
            ],
          ),
        );
      }
    }
  }
}

// ─────────────────────── Foiz kiritish paneli ────────────────────────────

class _PercentInputBar extends StatelessWidget {
  final TextEditingController controller;
  final double percent;
  final ValueChanged<double> onChanged;

  const _PercentInputBar({
    required this.controller,
    required this.percent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xFFFDAB3D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.percent_rounded, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Text(
            'Foiz hisoblash:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            height: 34,
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    RegExp(r'^\d{0,3}(\.\d{0,2})?')),
              ],
              onChanged: (v) => onChanged(double.tryParse(v) ?? 0),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: accent,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                  fontWeight: FontWeight.w400,
                ),
                suffixText: '%',
                suffixStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: accent,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                filled: true,
                fillColor: accent.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.3), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                      color: accent.withValues(alpha: 0.3), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: accent, width: 1.5),
                ),
              ),
            ),
          ),
          if (percent > 0) ...[
            const SizedBox(width: 16),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Har bir xodim savdosidan ${percent % 1 == 0 ? percent.toInt() : percent}% hisoblanadi',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () {
                controller.clear();
                onChanged(0);
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────── Summary Header ─────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final double totalSales;
  final double totalCommission;
  final int totalOrders;
  final int waiterCount;
  final bool isDark;
  final double customPercent;
  final double totalCustom;

  const _SummaryHeader({
    required this.totalSales,
    required this.totalCommission,
    required this.totalOrders,
    required this.waiterCount,
    required this.isDark,
    required this.customPercent,
    required this.totalCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF0D0D0D)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Jami savdo
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.payments_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Jami savdo',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        PriceFormatter.format(totalSales),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'so\'m',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          _MiniStat(
                              icon: Icons.receipt_long_rounded,
                              value: '$totalOrders ta',
                              label: 'buyurtma'),
                          const SizedBox(width: 20),
                          _MiniStat(
                              icon: Icons.people_rounded,
                              value: '$waiterCount',
                              label: 'xodim'),
                        ],
                      ),
                    ],
                  ),
                ),

                Container(
                  width: 1,
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.white.withValues(alpha: 0.15),
                ),

                // Komissiya
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00B894)
                                  .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                                Icons.account_balance_wallet_rounded,
                                color: Color(0xFF55EFC4),
                                size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'To\'lash kerak',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        PriceFormatter.format(totalCommission),
                        style: const TextStyle(
                          color: Color(0xFF55EFC4),
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'so\'m (komissiya)',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.info_outline_rounded,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              totalSales > 0
                                  ? '${(totalCommission / totalSales * 100).toStringAsFixed(1)}% dan'
                                  : '0%',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Foiz hisob (faqat kiritilganda ko'rinadi)
                if (customPercent > 0) ...[
                  Container(
                    width: 1,
                    height: 100,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDAB3D)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.percent_rounded,
                                  color: Color(0xFFFDAB3D), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${customPercent % 1 == 0 ? customPercent.toInt() : customPercent}% hisob',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          PriceFormatter.format(totalCustom),
                          style: const TextStyle(
                            color: Color(0xFFFDAB3D),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'so\'m (jami)',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.white54),
        const SizedBox(width: 5),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text: ' $label',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── Waiter Card ────────────────────────────────

class _WaiterCard extends StatelessWidget {
  final Map<String, dynamic> waiter;
  final Color color;
  final double commission;
  final double frac;
  final int rank;
  final bool isDark;
  final double customPercent;
  final double customAmount;

  const _WaiterCard({
    required this.waiter,
    required this.color,
    required this.commission,
    required this.frac,
    required this.rank,
    required this.isDark,
    required this.customPercent,
    required this.customAmount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = waiter['name'] as String? ?? '';
    final orderCount = (waiter['order_count'] as num?)?.toInt() ?? 0;
    final totalSales = (waiter['total_sales'] as num?)?.toDouble() ?? 0;
    final type = (waiter['waiter_type'] as num?)?.toInt() ?? 0;
    final value = (waiter['waiter_value'] as num?)?.toDouble() ?? 0;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isKassa = name == 'Kassa';
    const customColor = Color(0xFFFDAB3D);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + ism + reyting
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initials,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: color)),
                    ),
                  ),
                  if (rank <= 3)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: rank == 1
                              ? const Color(0xFFFFD700)
                              : rank == 2
                                  ? const Color(0xFFC0C0C0)
                                  : const Color(0xFFCD7F32),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: theme.colorScheme.surface, width: 1.5),
                        ),
                        child: Center(
                          child: Text('$rank',
                              style: const TextStyle(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('$orderCount buyurtma',
                        style: TextStyle(
                            fontSize: 9,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45))),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 3,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),

          const Spacer(),

          // Savdo summasi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Savdo',
                  style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.45))),
              Flexible(
                child: Text('${PriceFormatter.format(totalSales)} so\'m',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // Komissiya (mavjud tizim)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isKassa
                  ? theme.colorScheme.surfaceContainerHighest
                  : const Color(0xFF00B894).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isKassa
                    ? Colors.transparent
                    : const Color(0xFF00B894).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isKassa
                      ? 'Komissiyasiz'
                      : type == 1
                          ? '${value.toStringAsFixed(0)}%'
                          : '${PriceFormatter.format(value)}/b',
                  style: TextStyle(
                    fontSize: 8,
                    color: isKassa
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
                        : const Color(0xFF00B894),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Flexible(
                  child: Text(
                    isKassa
                        ? '—'
                        : '${PriceFormatter.format(commission)} so\'m',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isKassa
                          ? theme.colorScheme.onSurface
                              .withValues(alpha: 0.3)
                          : const Color(0xFF00B894),
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),

          // Foiz hisob satri (faqat foiz kiritilganda)
          if (customPercent > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: customColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: customColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${customPercent % 1 == 0 ? customPercent.toInt() : customPercent}%',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: customColor,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      '${PriceFormatter.format(customAmount)} so\'m',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: customColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
