import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../core/services/analytics_service.dart';
import '../../../models/analytics_models.dart';
import '../../../core/utils/price_formatter.dart';
import 'package:intl/intl.dart';

/// DashboardScreen - Hisobotlarni vizual grafiklar orqali ko'rsatish oynasi
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  final DateTime _end = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Vizual Analitika (Dashboard)'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Row 1: Sales Trend (Line Chart)
            _buildChartSection(
              title: 'Sotuvlar Trayektoriyasi (Oxirgi 30 kun)',
              child: _buildSalesLineChart(),
            ),
            const SizedBox(height: 24),

            // Row 2: Top Products & Staff Performance
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildChartSection(
                          title: 'Ommabop Mahsulotlar (Top 5)',
                          child: _buildTopProductsBarChart(),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildChartSection(
                          title: 'Ofitsiantlar Samaradorligi',
                          child: _buildWaiterBarChart(),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildChartSection(
                        title: 'Ommabop Mahsulotlar (Top 5)',
                        child: _buildTopProductsBarChart(),
                      ),
                      const SizedBox(height: 24),
                      _buildChartSection(
                        title: 'Ofitsiantlar Samaradorligi',
                        child: _buildWaiterBarChart(),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection({required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          SizedBox(height: 300, child: child),
        ],
      ),
    );
  }

  Widget _buildSalesLineChart() {
    return FutureBuilder<List<DailySalesStats>>(
      future: AnalyticsService.instance.getDailySales(start: _start, end: _end),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!.reversed.toList();

        return LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: true),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: data.indexed
                    .map((e) => FlSpot(e.$1.toDouble(), e.$2.total))
                    .toList(),
                isCurved: true,
                color: Colors.blue,
                barWidth: 4,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withOpacity(0.1),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopProductsBarChart() {
    return FutureBuilder<List<ProductPerformance>>(
      future: AnalyticsService.instance.getTopProducts(
        start: _start,
        end: _end,
        limit: 5,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;

        return BarChart(
          BarChartData(
            barGroups: data.indexed
                .map(
                  (e) => BarChartGroupData(
                    x: e.$1,
                    barRods: [
                      BarChartRodData(
                        toY: e.$2.qty,
                        color: Colors.orange,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    if (val.toInt() < data.length) {
                      return Text(
                        data[val.toInt()].productName,
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }

  Widget _buildWaiterBarChart() {
    return FutureBuilder<List<WaiterPerformance>>(
      future: AnalyticsService.instance.getWaiterPerformance(
        start: _start,
        end: _end,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data!;

        return BarChart(
          BarChartData(
            barGroups: data.indexed
                .map(
                  (e) => BarChartGroupData(
                    x: e.$1,
                    barRods: [
                      BarChartRodData(
                        toY: e.$2.revenue,
                        color: Colors.purple,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) {
                    if (val.toInt() < data.length) {
                      return Text(
                        data[val.toInt()].waiterName,
                        style: const TextStyle(fontSize: 10),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }
}
