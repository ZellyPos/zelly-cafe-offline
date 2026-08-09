import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import '../../providers/report_provider.dart';
import '../../core/utils/price_formatter.dart';
import 'widgets/filter_bar.dart';
import 'screens/products_report_screen.dart';
import 'screens/orders_report_screen.dart';
import 'screens/waiters_report_screen.dart';
import 'screens/tables_report_screen.dart';
import 'screens/locations_report_screen.dart';
import 'screens/general_report_screen.dart';
import 'screens/dashboard_screen.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../core/app_strings.dart';
import '../../core/telegram_service.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final GlobalKey _printKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final reportProvider = context.watch<ReportProvider>();
    final connectivity = context.read<ConnectivityProvider>();
    reportProvider.setConnectivity(connectivity);

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context),
          const ReportFilterBar(),
          Expanded(
            child: RepaintBoundary(
              key: _printKey,
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
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.9,
                  ),
                  itemCount: 7,
                  itemBuilder: (context, index) {
                    final items = [
                      _buildReportCard(
                        context: context,
                        title: "Vizual Analitika",
                        subtitle: "Grafiklar va trendlar",
                        icon: Icons.dashboard_customize,
                        color: Colors.indigo,
                        metric: "Grafiklarni ko'rish",
                        onTap: () =>
                            _navigateTo(context, const DashboardScreen()),
                      ),
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.analytics_rounded,
                color: Colors.indigo, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.reportsTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                AppStrings.reportsDescription,
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          // _buildCloudToggle(context, reportProvider),
          // const SizedBox(width: 12),
          _buildTelegramSyncButton(context),
        ],
      ),
    );
  }

  Widget _buildTelegramSyncButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _handleTelegramSync(context),
      icon: const Icon(Icons.send_rounded, size: 15),
      label: Text(AppStrings.syncTelegram,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF229ED9),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }

  void _handleTelegramSync(BuildContext context) async {
    final settings = context.read<AppSettingsProvider>();

    final hasToken = settings.telegramBotToken?.isNotEmpty ?? false;
    final hasChatId = settings.telegramChatId?.isNotEmpty ?? false;

    if (!hasToken || !hasChatId) {
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
              final token = tokenController.text.trim();
              final chatId = chatController.text.trim();

              // Validatsiya
              if (token.isEmpty || chatId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Token va Chat ID bo\'sh bo\'lishi mumkin emas'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (!RegExp(r'^\d{8,11}:[-a-zA-Z0-9_]{35}$').hasMatch(token)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.invalidToken),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              if (!RegExp(r'^-?\d+$').hasMatch(chatId)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.invalidChatId),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await settings.setTelegramSettings(token, chatId);
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

      String? webAppUrl;
      if (connectivity.isServerRunning && connectivity.serverIp != null) {
        webAppUrl = 'http://${connectivity.serverIp}:${connectivity.port}/reports/view';
      }

      // Capture Screenshot
      Uint8List? imageBytes;
      try {
        if (_printKey.currentContext != null) {
          RenderRepaintBoundary boundary = _printKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
          // Capture logic needs a tiny delay to ensure proper rendering sometimes, but await is fine.
          ui.Image image = await boundary.toImage(pixelRatio: 2.0);
          ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            imageBytes = byteData.buffer.asUint8List();
          }
        }
      } catch (e) {
        debugPrint("Error taking screenshot: $e");
      }

      final errorStr = await TelegramService.sendMessage(
        token: settings.telegramBotToken!,
        chatId: settings.telegramChatId!,
        text: summary,
        webAppUrl: webAppUrl,
        imageBytes: imageBytes,
      );

      if (context.mounted) {
        final success = errorStr == null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? AppStrings.reportSentTelegram
                  : '${AppStrings.telegramError}\n($errorStr)',
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            top: BorderSide(color: color.withValues(alpha: 0.4), width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 12, color: color.withValues(alpha: 0.4)),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                metric,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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

}
