import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../models/analytics_models.dart';
import '../../../models/waiter.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../providers/report_provider.dart';
import 'orders_report_screen.dart';
import 'general_report_screen.dart';
import '../../mgmt/waiter_profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _periodKey = 'week';
  DateTime _start = DateTime.now().subtract(const Duration(days: 6));
  DateTime _end = DateTime.now();

  static const _periods = [
    ('today', 'Bugun'),
    ('yesterday', 'Kecha'),
    ('week', '7 kun'),
    ('thisMonth', 'Bu oy'),
    ('lastMonth', 'O\'tgan oy'),
    ('custom', 'Tanlash'),
  ];

  static const _accent = Color(0xFF6C5CE7);
  static const _green = Color(0xFF00B894);
  static const _orange = Color(0xFFE17055);
  static const _blue = Color(0xFF0984E3);

  late Future<_DashData> _dataFuture;

  @override
  void initState() {
    super.initState();
    // _dataFuture ni darhol belgilaymiz — async init ichida qaytaradi
    _dataFuture = _initAndLoad();
  }

  Future<_DashData> _initAndLoad() async {
    final rp = context.read<ReportProvider>();
    if (rp.filterInitialized) {
      // FilterBar yoki boshqa ekranda o'rnatilgan filterni ishlatamiz
      _start = rp.dateFrom;
      _end = rp.dateTo;
      _periodKey = _fromFilterChip(rp.activeChipKey);
    } else {
      await _computeDates('week');
      _periodKey = 'week';
    }
    AnalyticsService.instance.clearCache();
    return _DashData.load(_start, _end);
  }

  /// FilterBar chip kalitini DashboardScreen kalitiga o'giradi.
  String _fromFilterChip(String filterKey) {
    const map = <String, String>{
      'today':     'today',
      'yesterday': 'yesterday',
      'week':      'week',
      'month':     'thisMonth',
    };
    return map[filterKey] ?? 'custom';
  }

  /// DashboardScreen chip kalitini FilterBar chip kalitiga o'giradi.
  String? _toFilterChip(String dashKey) {
    const map = <String, String>{
      'today':     'today',
      'yesterday': 'yesterday',
      'week':      'week',
      'thisMonth': 'month',
    };
    return map[dashKey];
  }

  Future<void> _computeDates(String key) async {
    final dayStart = await SettingsRepository().getDayStartTime();
    final dayEnd = dayStart.add(const Duration(days: 1));

    switch (key) {
      case 'today':
        _start = dayStart;
        _end = dayEnd;
      case 'yesterday':
        _start = dayStart.subtract(const Duration(days: 1));
        _end = dayStart;
      case 'week':
        _start = dayStart.subtract(const Duration(days: 6));
        _end = dayEnd;
      case 'thisMonth':
        _start = DateTime(dayStart.year, dayStart.month, 1, dayStart.hour, dayStart.minute);
        _end = dayEnd;
      case 'lastMonth':
        final first = DateTime(dayStart.year, dayStart.month - 1, 1, dayStart.hour, dayStart.minute);
        final last = DateTime(dayStart.year, dayStart.month, 1, dayStart.hour, dayStart.minute);
        _start = first;
        _end = last;
      default:
        _start = dayStart.subtract(const Duration(days: 6));
        _end = dayEnd;
    }
  }

  void _loadData() {
    AnalyticsService.instance.clearCache();
    setState(() {
      _dataFuture = _DashData.load(_start, _end);
    });
  }

  void _setPeriod(String key) async {
    if (key == 'custom') {
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: _start, end: _end),
      );
      if (range == null) return;
      final dayStart = await SettingsRepository().getDayStartTime();
      final h = dayStart.hour;
      final m = dayStart.minute;

      _periodKey = 'custom';
      _start = DateTime(range.start.year, range.start.month, range.start.day, h, m);
      _end = DateTime(range.end.year, range.end.month, range.end.day, h, m).add(const Duration(days: 1));
      _loadData();
    } else {
      await _computeDates(key);
      setState(() {
        _periodKey = key;
      });
      _loadData();
    }
    // ReportProvider'ni yangilaymiz — boshqa hisobot ekranlari ham shu filterni ko'radi
    if (mounted) {
      context.read<ReportProvider>().updateFilter(
        startDate: _start,
        endDate: _end,
        chipKey: _toFilterChip(key),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(theme, isDark),
          Expanded(
            child: FutureBuilder<_DashData>(
              future: _dataFuture,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _accent),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Xatolik: ${snap.error}',
                        style: const TextStyle(color: Colors.red)),
                  );
                }
                final d = snap.data!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _KpiRow(data: d, isDark: isDark),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        'Sotuvlar trayektoriyasi',
                        subtitle:
                            '${DateFormat('dd.MM').format(_start)} — ${DateFormat('dd.MM.yyyy').format(_end)}',
                        icon: Icons.show_chart_rounded,
                        color: _accent,
                      ),
                      const SizedBox(height: 12),
                      _SalesLineChart(dailySales: d.dailySales, accentColor: _accent),
                      const SizedBox(height: 24),
                      _ThreeColRow(children: [
                        _ColSection(
                          title: 'Top mahsulotlar',
                          icon: Icons.local_fire_department_rounded,
                          color: _orange,
                          child: _TopProductsBars(
                              products: d.topProducts, accentColor: _orange),
                        ),
                        _ColSection(
                          title: 'To\'lov taqsimoti',
                          icon: Icons.pie_chart_rounded,
                          color: _accent,
                          child: _PaymentDonut(payments: d.payments, isDark: isDark),
                        ),
                        _ColSection(
                          title: 'Ofitsiantlar reytingi',
                          icon: Icons.emoji_events_rounded,
                          color: _green,
                          child: _WaiterLeaderboard(
                              waiters: d.waiters, accentColor: _green),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        'Soatlik faollik',
                        icon: Icons.access_time_rounded,
                        color: _blue,
                      ),
                      const SizedBox(height: 12),
                      _HourlyChart(hourly: d.hourly, accentColor: _blue),
                      const SizedBox(height: 24),
                      _ThreeColRow(children: [
                        _ColSection(
                          title: 'Stollar reytingi',
                          icon: Icons.table_restaurant_rounded,
                          color: _green,
                          child: _RankingList(
                            items: d.tables
                                .map((t) => (t.tableName, t.revenue, t.ordersCount))
                                .toList(),
                            color: _green,
                          ),
                        ),
                        _ColSection(
                          title: 'Zallar bo\'yicha',
                          icon: Icons.meeting_room_rounded,
                          color: _accent,
                          child: _RankingList(
                            items: d.locations
                                .map((l) => (l.locationName, l.revenue, 0))
                                .toList(),
                            color: _accent,
                            hideCount: true,
                          ),
                        ),
                        if (d.categories.isNotEmpty)
                          _ColSection(
                            title: 'Kategoriyalar',
                            icon: Icons.category_rounded,
                            color: _orange,
                            child: _CategoryBars(categories: d.categories),
                          )
                        else
                          const SizedBox(),
                      ]),
                      const SizedBox(height: 24),
                      _QuickLinks(),
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

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: _accent, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Vizual Analitika',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 13, color: _accent.withValues(alpha: 0.8)),
                      const SizedBox(width: 6),
                      Text(
                        '${DateFormat('dd.MM.yyyy').format(_start)} — ${DateFormat('dd.MM.yyyy').format(_end)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _accent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _periods.map((p) {
                  final isSelected = _periodKey == p.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: InkWell(
                        onTap: () => _setPeriod(p.$1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? _accent
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.15),
                            ),
                          ),
                          child: Text(
                            p.$2,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Data loader ────────────────────────────

class _DashData {
  final List<DailySalesStats> dailySales;
  final List<ProductPerformance> topProducts;
  final List<WaiterPerformance> waiters;
  final List<TablePerformance> tables;
  final List<LocationPerformance> locations;
  final List<PaymentTypeStats> payments;
  final List<HourlySalesStats> hourly;
  final List<CategorySalesStats> categories;

  const _DashData({
    required this.dailySales,
    required this.topProducts,
    required this.waiters,
    required this.tables,
    required this.locations,
    required this.payments,
    required this.hourly,
    required this.categories,
  });

  static Future<_DashData> load(DateTime start, DateTime end) async {
    final svc = AnalyticsService.instance;
    final results = await Future.wait([
      svc.getDailySales(start: start, end: end, useCache: false),
      svc.getTopProducts(start: start, end: end, limit: 10, useCache: false),
      svc.getWaiterPerformance(start: start, end: end, useCache: false),
      svc.getTablePerformance(start: start, end: end, limit: 10, useCache: false),
      svc.getLocationPerformance(start: start, end: end, useCache: false),
      svc.getPaymentBreakdown(start: start, end: end, useCache: false),
      svc.getHourlyBreakdown(start: start, end: end, useCache: false),
      svc.getCategoryBreakdown(start: start, end: end, useCache: false),
    ]);
    return _DashData(
      dailySales: results[0] as List<DailySalesStats>,
      topProducts: results[1] as List<ProductPerformance>,
      waiters: results[2] as List<WaiterPerformance>,
      tables: results[3] as List<TablePerformance>,
      locations: results[4] as List<LocationPerformance>,
      payments: results[5] as List<PaymentTypeStats>,
      hourly: results[6] as List<HourlySalesStats>,
      categories: results[7] as List<CategorySalesStats>,
    );
  }

  double get totalRevenue => dailySales.fold(0.0, (s, d) => s + d.total);
  int get totalOrders => dailySales.fold(0, (s, d) => s + d.ordersCount);
  double get avgCheck => totalOrders > 0 ? totalRevenue / totalOrders : 0;
  double get cashTotal => dailySales.fold(0.0, (s, d) => s + d.cash);
  double get cardTotal => dailySales.fold(0.0, (s, d) => s + d.card);
}

// ───────────────────────── Section Title ────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _SectionTitle(
    this.text, {
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 10),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ],
    );
  }
}

// ──────────────────── Three Column Layout ───────────────────────────

class _ThreeColRow extends StatelessWidget {
  final List<Widget> children;
  const _ThreeColRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth > 900) {
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 16),
                  child: e.value,
                ),
              );
            }).toList(),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map((w) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: w,
                ))
            .toList(),
      );
    });
  }
}

class _ColSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _ColSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title, icon: icon, color: color),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// ───────────────────────── KPI Row ──────────────────────────────────

class _KpiRow extends StatelessWidget {
  final _DashData data;
  final bool isDark;

  const _KpiRow({required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _KpiCard(
        label: 'Jami tushum',
        value: PriceFormatter.format(data.totalRevenue),
        unit: 'so\'m',
        icon: Icons.payments_rounded,
        color: const Color(0xFF6C5CE7),
        isDark: isDark,
      ),
      _KpiCard(
        label: 'Buyurtmalar',
        value: '${data.totalOrders}',
        unit: 'ta',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0984E3),
        isDark: isDark,
      ),
      _KpiCard(
        label: 'O\'rtacha chek',
        value: PriceFormatter.format(data.avgCheck),
        unit: 'so\'m',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF00B894),
        isDark: isDark,
      ),
      _KpiCard(
        label: 'Naqd pul',
        value: PriceFormatter.format(data.cashTotal),
        unit: 'so\'m',
        icon: Icons.account_balance_wallet_rounded,
        color: const Color(0xFFE17055),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth > 700) {
        return Row(
          children: cards
              .asMap()
              .entries
              .map((e) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: e.key < cards.length - 1 ? 14 : 0),
                      child: e.value,
                    ),
                  ))
              .toList(),
        );
      }
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: cards,
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.4)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Sales Line Chart ───────────────────────────

class _SalesLineChart extends StatelessWidget {
  final List<DailySalesStats> dailySales;
  final Color accentColor;

  const _SalesLineChart({required this.dailySales, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = dailySales.reversed.toList();

    if (data.isEmpty) return const _EmptyCard(height: 220);

    return _Card(
      child: SizedBox(
        height: 220,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _calcInterval(data),
              getDrawingHorizontalLine: (val) => FlLine(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 52,
                  getTitlesWidget: (val, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _shortMoney(val),
                      style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: data.length > 10 ? (data.length / 5).ceilToDouble() : 1,
                  getTitlesWidget: (val, _) {
                    final i = val.toInt();
                    if (i < 0 || i >= data.length) return const SizedBox();
                    final parts = data[i].date.split('-');
                    final label = parts.length >= 3
                        ? '${parts[2]}.${parts[1]}'
                        : data[i].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.45))),
                    );
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: accentColor,
                tooltipRoundedRadius: 10,
                getTooltipItems: (spots) => spots
                    .map((s) => LineTooltipItem(
                          '${PriceFormatter.format(s.y)} so\'m',
                          const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ))
                    .toList(),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: data.indexed
                    .map((e) => FlSpot(e.$1.toDouble(), e.$2.total))
                    .toList(),
                isCurved: true,
                color: accentColor,
                barWidth: 3,
                dotData: FlDotData(
                  show: data.length <= 14,
                  getDotPainter: (spot, p, b, i) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: accentColor,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor.withValues(alpha: 0.2),
                      accentColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calcInterval(List<DailySalesStats> data) {
    final max = data.fold(0.0, (m, d) => d.total > m ? d.total : m);
    if (max == 0) return 1;
    final raw = max / 4;
    final magnitude = (raw / 10).floor() * 10;
    return magnitude > 0 ? magnitude.toDouble() : raw;
  }

  String _shortMoney(double val) {
    if (val >= 1000000) return '${(val / 1000000).toStringAsFixed(1)}M';
    if (val >= 1000) return '${(val / 1000).toStringAsFixed(0)}K';
    return val.toInt().toString();
  }
}

// ─────────────────────── Top Products ───────────────────────────────

class _TopProductsBars extends StatelessWidget {
  final List<ProductPerformance> products;
  final Color accentColor;

  const _TopProductsBars({required this.products, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (products.isEmpty) return const _EmptyCard();
    final maxQty = products.fold(0.0, (m, p) => p.qty > m ? p.qty : m);

    return _Card(
      child: Column(
        children: products.take(8).indexed.map((entry) {
          final i = entry.$1;
          final p = entry.$2;
          final frac = maxQty > 0 ? p.qty / maxQty : 0.0;
          final isTop3 = i < 3;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isTop3
                        ? accentColor.withValues(alpha: 0.12)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isTop3
                          ? accentColor
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              p.productName,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${p.qty.toInt()} ta',
                            style: TextStyle(
                              fontSize: 12,
                              color: accentColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 5,
                          backgroundColor: accentColor.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${PriceFormatter.format(p.revenue)} so\'m',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────── Payment Donut ──────────────────────────────

class _PaymentDonut extends StatefulWidget {
  final List<PaymentTypeStats> payments;
  final bool isDark;

  const _PaymentDonut({required this.payments, required this.isDark});

  @override
  State<_PaymentDonut> createState() => _PaymentDonutState();
}

class _PaymentDonutState extends State<_PaymentDonut> {
  int _touched = -1;

  static const _colors = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFFDAB3D),
    Color(0xFFD63031),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.payments.isEmpty) return const _EmptyCard();

    final total = widget.payments.fold(0.0, (s, p) => s + p.amount);

    return _Card(
      child: Column(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: PieChart(PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (evt, resp) {
                  setState(() {
                    _touched =
                        resp?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              sectionsSpace: 3,
              centerSpaceRadius: 44,
              sections: widget.payments.indexed.map((e) {
                final isTouched = e.$1 == _touched;
                return PieChartSectionData(
                  value: e.$2.amount,
                  color: _colors[e.$1 % _colors.length],
                  radius: isTouched ? 52 : 44,
                  title: isTouched
                      ? '${e.$2.percentage.toStringAsFixed(1)}%'
                      : '',
                  titleStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            )),
          ),
          const SizedBox(height: 16),
          ...widget.payments.indexed.map((e) {
            final pct = total > 0 ? (e.$2.amount / total * 100) : 0.0;
            final color = _colors[e.$1 % _colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.$2.type,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      Text(
                        '${PriceFormatter.format(e.$2.amount)} so\'m',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ───────────────────── Waiter Leaderboard ───────────────────────────

class _WaiterLeaderboard extends StatelessWidget {
  final List<WaiterPerformance> waiters;
  final Color accentColor;

  const _WaiterLeaderboard({required this.waiters, required this.accentColor});

  static const _podiumColors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  static const _avatarColors = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFF0984E3),
    Color(0xFFE17055),
    Color(0xFFFDAB3D),
    Color(0xFFD63031),
    Color(0xFF74B9FF),
    Color(0xFF55EFC4),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (waiters.isEmpty) return const _EmptyCard();
    final maxRev = waiters.fold(0.0, (m, w) => w.revenue > m ? w.revenue : m);

    return _Card(
      child: Column(
        children: waiters.take(8).indexed.map((entry) {
          final i = entry.$1;
          final w = entry.$2;
          final frac = maxRev > 0 ? w.revenue / maxRev : 0.0;
          final isTop3 = i < 3;
          final avatarColor = _avatarColors[i % _avatarColors.length];
          final initials = w.waiterName.isNotEmpty
              ? w.waiterName.substring(0, 1).toUpperCase()
              : '?';

          final commission = w.commission;
          final hasCommission = w.waiterValue > 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  final waiter = Waiter(
                    id: w.waiterId,
                    name: w.waiterName,
                    type: w.waiterType,
                    value: w.waiterValue,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaiterProfileScreen(waiter: waiter),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: avatarColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isTop3 ? _podiumColors[i] : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: avatarColor,
                                ),
                              ),
                            ),
                          ),
                          if (isTop3)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: _podiumColors[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    w.waiterName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      PriceFormatter.format(w.revenue),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                    if (hasCommission)
                                      Text(
                                        '+${PriceFormatter.format(commission)}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFDAB3D),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: frac,
                                minHeight: 4,
                                backgroundColor: accentColor.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '${w.ordersCount} buyurtma',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                                  ),
                                ),
                                if (hasCommission) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    w.waiterType == 1
                                        ? '${w.waiterValue.toStringAsFixed(0)}% komissiya'
                                        : '${PriceFormatter.format(w.waiterValue)} fiksed',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFFFDAB3D),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────── Hourly Chart ──────────────────────────────

class _HourlyChart extends StatelessWidget {
  final List<HourlySalesStats> hourly;
  final Color accentColor;

  const _HourlyChart({required this.hourly, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRev = hourly.fold(0.0, (m, h) => h.revenue > m ? h.revenue : m);

    return _Card(
      child: SizedBox(
        height: 180,
        child: BarChart(BarChartData(
          maxY: maxRev > 0 ? maxRev * 1.15 : 1,
          barGroups: hourly
              .map((h) => BarChartGroupData(
                    x: h.hour,
                    barRods: [
                      BarChartRodData(
                        toY: h.revenue,
                        gradient: h.ordersCount > 0
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [accentColor, accentColor.withValues(alpha: 0.6)],
                              )
                            : null,
                        color: h.ordersCount > 0
                            ? null
                            : accentColor.withValues(alpha: 0.1),
                        width: 10,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  ))
              .toList(),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 3,
                getTitlesWidget: (val, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${val.toInt()}:00',
                    style: TextStyle(
                        fontSize: 9,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: accentColor,
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, gi, rod, ri) {
                final h = hourly[group.x];
                return BarTooltipItem(
                  '${group.x}:00\n${h.ordersCount} buyurtma\n${PriceFormatter.format(rod.toY)} so\'m',
                  const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (val) => FlLine(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
        )),
      ),
    );
  }
}

// ────────────────────────── Ranking List ────────────────────────────

class _RankingList extends StatelessWidget {
  final List<(String, double, int)> items;
  final Color color;
  final bool hideCount;

  const _RankingList(
      {required this.items, required this.color, this.hideCount = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) return const _EmptyCard();
    final maxRev = items.fold(0.0, (m, t) => t.$2 > m ? t.$2 : m);

    return _Card(
      child: Column(
        children: items.take(8).indexed.map((entry) {
          final i = entry.$1;
          final item = entry.$2;
          final frac = maxRev > 0 ? item.$2 / maxRev : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < 3
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: i < 3
                          ? color
                          : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(item.$1,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis),
                          ),
                          Text(
                            '${PriceFormatter.format(item.$2)} so\'m',
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 4,
                          backgroundColor: color.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      if (!hideCount && item.$3 > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${item.$3} buyurtma',
                          style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────── Category Bars ─────────────────────────────────

class _CategoryBars extends StatelessWidget {
  final List<CategorySalesStats> categories;

  const _CategoryBars({required this.categories});

  static const _colors = [
    Color(0xFF6C5CE7),
    Color(0xFF00B894),
    Color(0xFFE17055),
    Color(0xFF0984E3),
    Color(0xFFFDAB3D),
    Color(0xFFD63031),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxRev = categories.fold(0.0, (m, c) => c.revenue > m ? c.revenue : m);
    final total = categories.fold(0.0, (s, c) => s + c.revenue);

    return _Card(
      child: Column(
        children: categories.take(6).indexed.map((entry) {
          final i = entry.$1;
          final cat = entry.$2;
          final frac = maxRev > 0 ? cat.revenue / maxRev : 0.0;
          final pct = total > 0 ? (cat.revenue / total * 100) : 0.0;
          final color = _colors[i % _colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cat.category,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${PriceFormatter.format(cat.revenue)} so\'m',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cat.qty.toInt()} ta sotilgan',
                  style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ────────────────────── Quick Links ─────────────────────────────────

class _QuickLinks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickLinkCard(
            label: 'Buyurtmalar ro\'yxati',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF0984E3),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OrdersReportScreen())),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _QuickLinkCard(
            label: 'Umumiy hisobot (Z)',
            icon: Icons.analytics_rounded,
            color: const Color(0xFFE17055),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GeneralReportScreen())),
          ),
        ),
      ],
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 13, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────── Shared Widgets ────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final double height;
  const _EmptyCard({this.height = 80});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: SizedBox(
        height: height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_rounded,
                  size: 32,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Text(
                'Ma\'lumot yo\'q',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.35),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
