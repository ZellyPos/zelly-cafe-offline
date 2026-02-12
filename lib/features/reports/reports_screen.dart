import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/report_provider.dart';
import '../../core/utils/price_formatter.dart';
import 'widgets/filter_bar.dart';
import 'screens/products_report_screen.dart';
import 'screens/orders_report_screen.dart';
import 'screens/waiters_report_screen.dart';
import 'screens/tables_report_screen.dart';
import 'screens/locations_report_screen.dart';
import 'screens/general_report_screen.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../core/app_strings.dart';
import '../../core/telegram_service.dart';
import 'package:intl/intl.dart';
import '../../widgets/ai_action_button.dart';
import '../../widgets/ai_summary_banner.dart';
import '../../providers/ai_provider.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _buildHeader(context),
          const ReportFilterBar(),
          const AiSummaryBanner(),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: reportProvider.getDashboardStats(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data ?? {};
                final metrics = data['metrics'] ?? {};
                final totalRevenue =
                    (metrics['total'] as num?)?.toDouble() ?? 0.0;
                final orderCount = (metrics['count'] as num?)?.toInt() ?? 0;

                // For other specific card metrics, we can derive them from provider if needed,
                // but for now, let's use what we have or placeholder totals.

                return GridView.builder(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width <= 1100 ? 12 : 24,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _getCrossAxisCount(context),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: _getChildAspectRatio(context),
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final items = [
                      _buildReportCard(
                        context: context,
                        title: AppStrings.ordersTitle,
                        subtitle: AppStrings.operationsSubtitle,
                        icon: Icons.receipt_long,
                        color: Colors.blue,
                        metric: "${PriceFormatter.format(totalRevenue)} so'm",
                        onTap: () =>
                            _navigateTo(context, const OrdersReportScreen()),
                      ),
                      _buildReportCard(
                        context: context,
                        title: AppStrings.productsTitle,
                        subtitle: AppStrings.topProductsSubtitle,
                        icon: Icons.restaurant_menu,
                        color: Colors.orange,
                        metric: "$orderCount taom",
                        onTap: () =>
                            _navigateTo(context, const ProductsReportScreen()),
                      ),
                      _buildReportCard(
                        context: context,
                        title: AppStrings.waitersTitle,
                        subtitle: AppStrings.staffPerformanceSubtitle,
                        icon: Icons.people_alt,
                        color: Colors.purple,
                        metric: AppStrings.commissionAndSales,
                        onTap: () =>
                            _navigateTo(context, const WaitersReportScreen()),
                      ),
                      _buildReportCard(
                        context: context,
                        title: AppStrings.tablesTitle,
                        subtitle: AppStrings.tablesRevenueSubtitle,
                        icon: Icons.table_restaurant,
                        color: Colors.indigo,
                        metric: AppStrings.activeTablesAnalysis,
                        onTap: () =>
                            _navigateTo(context, const TablesReportScreen()),
                      ),
                      _buildReportCard(
                        context: context,
                        title: AppStrings.locationsTitle,
                        subtitle: AppStrings.locationsSubtitle,
                        icon: Icons.location_on,
                        color: Colors.teal,
                        metric: AppStrings.byLocations,
                        onTap: () =>
                            _navigateTo(context, const LocationsReportScreen()),
                      ),
                      _buildReportCard(
                        context: context,
                        title: AppStrings.generalReportTitle,
                        subtitle: AppStrings.zreportSubtitle,
                        icon: Icons.analytics,
                        color: Colors.redAccent,
                        metric: AppStrings.financialSummary,
                        onTap: () =>
                            _navigateTo(context, const GeneralReportScreen()),
                      ),
                    ];
                    return items[index];
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width <= 800;
    return Container(
      padding: EdgeInsets.fromLTRB(
        isSmall ? 16 : 32,
        isSmall ? 24 : 48,
        isSmall ? 16 : 32,
        isSmall ? 12 : 24,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.reportsTitle,
                style: TextStyle(
                  fontSize: isSmall ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                AppStrings.reportsDescription,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
          Row(
            children: [
              AiActionButton(
                onAnalyze: () {
                  final reportProvider = context.read<ReportProvider>();
                  context.read<AiProvider>().getGeneralReport(
                    reportProvider.dateFrom,
                    reportProvider.dateTo,
                  );
                },
                label: AppStrings.aiAnalysis,
                dialogTitle: AppStrings.generalReportAnalysis,
              ),
              const SizedBox(width: 12),
              _buildTelegramSyncButton(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelegramSyncButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _handleTelegramSync(context),
      icon: const Icon(Icons.send_rounded, size: 20),
      label: Text(AppStrings.syncTelegram),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF229ED9), // Telegram Blue
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width <= 800 ? 12 : 24,
          vertical: MediaQuery.of(context).size.width <= 800 ? 12 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleTelegramSync(BuildContext context) async {
    final settings = context.read<AppSettingsProvider>();

    if (settings.telegramBotToken == null || settings.telegramChatId == null) {
      _showTelegramConfigDialog(context);
    } else {
      _performSync(context);
    }
  }

  void _showTelegramConfigDialog(BuildContext context) {
    final settings = context.read<AppSettingsProvider>();
    final tokenController = TextEditingController(
      text: settings.telegramBotToken,
    );
    final chatController = TextEditingController(text: settings.telegramChatId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.telegramSettingsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tokenController,
              decoration: InputDecoration(
                labelText: AppStrings.botToken,
                hintText: "12345678:ABCDE...",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chatController,
              decoration: InputDecoration(
                labelText: AppStrings.chatId,
                hintText: "-10012345678",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              await settings.setTelegramSettings(
                tokenController.text,
                chatController.text,
              );
              if (context.mounted) {
                Navigator.pop(context);
                _performSync(context);
              }
            },
            child: Text(AppStrings.saveAndSend),
          ),
        ],
      ),
    );
  }

  void _performSync(BuildContext context) async {
    final reportProvider = context.read<ReportProvider>();
    final settings = context.read<AppSettingsProvider>();
    final connectivity = context.read<ConnectivityProvider>();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(AppStrings.sendingReport)));

    try {
      final data = await reportProvider.getDashboardStats();
      final metrics = data['metrics'] ?? {};
      final topProducts = List<Map<String, dynamic>>.from(
        data['topRevenue'] ?? [],
      );

      final dateStr =
          "${DateFormat('dd.MM.yyyy').format(reportProvider.filter.startDate)} - ${DateFormat('dd.MM.yyyy').format(reportProvider.filter.endDate)}";

      final summary = TelegramService.formatReportSummary(
        restaurantName: settings.restaurantName,
        metrics: metrics,
        topProducts: topProducts,
        date: dateStr,
      );

      // Web View URL if server is running
      String? webAppUrl;
      if (connectivity.isServerRunning && connectivity.serverIp != null) {
        // We use port from connectivity provider
        webAppUrl =
            "http://${connectivity.serverIp}:${connectivity.port}/reports/view";
      }

      final success = await TelegramService.sendMessage(
        token: settings.telegramBotToken!,
        chatId: settings.telegramChatId!,
        text: summary,
        webAppUrl: webAppUrl,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? AppStrings.reportSentTelegram
                  : AppStrings.telegramError,
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Xatolik: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String metric,
    required VoidCallback onTap,
  }) {
    final isSmall = MediaQuery.of(context).size.width <= 800;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 14 : 18),
        decoration: BoxDecoration(
          color: Colors.white,
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
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isSmall ? 20 : 24),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmall ? 15 : 17,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontSize: isSmall ? 11 : 12,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              metric,
              style: TextStyle(
                fontSize: isSmall ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  int _getCrossAxisCount(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1400) return 4;
    if (width > 900) return 3;
    if (width > 600) return 2;
    return 1;
  }

  double _getChildAspectRatio(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 1200) return 1.5;
    if (width > 900) return 1.4;
    if (width > 600) return 1.6;
    return 2.5;
  }
}
