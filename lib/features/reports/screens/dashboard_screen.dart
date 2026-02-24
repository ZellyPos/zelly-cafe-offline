import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/analytics_service.dart';
import '../../../models/analytics_models.dart';
import '../../../core/utils/price_formatter.dart';

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
            _buildResponsiveRow([
              _buildChartSection(
                title: 'Ommabop Mahsulotlar (Top 5)',
                child: _buildTopProductsBarChart(),
              ),
              _buildChartSection(
                title: 'Ofitsiantlar Samaradorligi',
                child: _buildWaiterBarChart(),
              ),
            ]),
            const SizedBox(height: 24),

            // Row 3: Tables & Locations
            _buildResponsiveRow([
              _buildChartSection(
                title: 'Stollar bo\'yicha tushum',
                child: _buildTableBarChart(),
              ),
              _buildChartSection(
                title: 'Zallar bo\'yicha tushum',
                child: _buildLocationBarChart(),
              ),
            ]),
            const SizedBox(height: 24),

            // Row 4: Payment Types
            _buildChartSection(
              title: 'To\'lov turlari taqsimoti',
              child: _buildPaymentPieChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children
                .map(
                  (child) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: child == children.last ? 0 : 12,
                        left: child == children.first ? 0 : 12,
                      ),
                      child: child,
                    ),
                  ),
                )
                .toList(),
          );
        } else {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: child,
                  ),
                )
                .toList(),
          );
        }
      },
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
            color: theme.shadowColor.withOpacity(0.04),
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
    final theme = Theme.of(context);
    return FutureBuilder<List<DailySalesStats>>(
      future: AnalyticsService.instance.getDailySales(start: _start, end: _end),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Xatolik: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.reversed.toList();

        if (data.isEmpty) {
          return const Center(child: Text("Sotuvlar mavjud emas"));
        }

        return LineChart(
          LineChartData(
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (val, meta) => Text(
                    PriceFormatter.format(val),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              bottomTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.blueAccent,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      '${PriceFormatter.format(spot.y)} so‘m',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
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
    final theme = Theme.of(context);
    return FutureBuilder<List<ProductPerformance>>(
      future: AnalyticsService.instance.getTopProducts(
        start: _start,
        end: _end,
        limit: 5,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Xatolik: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        if (data.isEmpty) {
          return const Center(child: Text("Ma'lumotlar mavjud emas"));
        }

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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data[val.toInt()].productName,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.orangeAccent,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${data[groupIndex].productName}\n${rod.toY.toInt()} ta\n${PriceFormatter.format(data[groupIndex].revenue)} so‘m',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }

  Widget _buildWaiterBarChart() {
    final theme = Theme.of(context);
    return FutureBuilder<List<WaiterPerformance>>(
      future: AnalyticsService.instance.getWaiterPerformance(
        start: _start,
        end: _end,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Xatolik: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        if (data.isEmpty) {
          return const Center(child: Text("Ma'lumotlar mavjud emas"));
        }

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
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          data[val.toInt()].waiterName,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (val, meta) => Text(
                    PriceFormatter.format(val),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.purpleAccent,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  return BarTooltipItem(
                    '${data[groupIndex].waiterName}\n${PriceFormatter.format(rod.toY)} so‘m',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }

  Widget _buildTableBarChart() {
    final theme = Theme.of(context);
    return FutureBuilder<List<TablePerformance>>(
      future: AnalyticsService.instance.getTablePerformance(
        start: _start,
        end: _end,
        limit: 5,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Xatolik: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text("Ma'lumotlar mavjud emas"));
        }

        return BarChart(
          BarChartData(
            barGroups: data.indexed
                .map(
                  (e) => BarChartGroupData(
                    x: e.$1,
                    barRods: [
                      BarChartRodData(
                        toY: e.$2.revenue,
                        color: Colors.teal,
                        width: 20,
                      ),
                    ],
                  ),
                )
                .toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => val.toInt() < data.length
                      ? Text(
                          data[val.toInt()].tableName,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60,
                  getTitlesWidget: (val, meta) => Text(
                    PriceFormatter.format(val),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.tealAccent.shade700,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${data[groupIndex].tableName}\n${PriceFormatter.format(rod.toY)} so‘m',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }

  Widget _buildLocationBarChart() {
    final theme = Theme.of(context);
    return FutureBuilder<List<LocationPerformance>>(
      future: AnalyticsService.instance.getLocationPerformance(
        start: _start,
        end: _end,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Xatolik: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text("Ma'lumotlar mavjud emas"));
        }

        return BarChart(
          BarChartData(
            barGroups: data.indexed
                .map(
                  (e) => BarChartGroupData(
                    x: e.$1,
                    barRods: [
                      BarChartRodData(
                        toY: e.$2.revenue,
                        color: Colors.blueGrey,
                        width: 20,
                      ),
                    ],
                  ),
                )
                .toList(),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, meta) => val.toInt() < data.length
                      ? Text(
                          data[val.toInt()].locationName,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        )
                      : const SizedBox(),
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                tooltipBgColor: Colors.blueGrey,
                getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                    BarTooltipItem(
                      '${data[groupIndex].locationName}\n${PriceFormatter.format(rod.toY)} so‘m',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        );
      },
    );
  }

  Widget _buildPaymentPieChart() {
    return FutureBuilder<List<PaymentTypeStats>>(
      future: AnalyticsService.instance.getPaymentBreakdown(
        start: _start,
        end: _end,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Xatolik: ${snapshot.error}"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(child: Text("Ma'lumotlar mavjud emas"));
        }

        final List<Color> colors = [
          Colors.blue,
          Colors.green,
          Colors.orange,
          Colors.red,
          Colors.purple,
        ];

        return PieChart(
          PieChartData(
            sections: data.indexed.map((e) {
              return PieChartSectionData(
                value: e.$2.amount,
                title: '${e.$2.type}\n${e.$2.percentage.toStringAsFixed(1)}%',
                color: colors[e.$1 % colors.length],
                radius: 100,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).toList(),
            centerSpaceRadius: 40,
            sectionsSpace: 2,
          ),
        );
      },
    );
  }
}
