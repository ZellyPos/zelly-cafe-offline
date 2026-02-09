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
import '../../core/telegram_service.dart';
import 'package:intl/intl.dart';

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

                return GridView.count(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width <= 1100 ? 16 : 32,
                  ),
                  crossAxisCount: MediaQuery.of(context).size.width <= 1100
                      ? 2
                      : 3,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: MediaQuery.of(context).size.width <= 1100
                      ? 1.6
                      : 1.4,
                  children: [
                    _buildReportCard(
                      context: context,
                      title: "Buyurtmalar",
                      subtitle: "Barcha savdo operatsiyalari",
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                      metric: "${PriceFormatter.format(totalRevenue)} so'm",
                      onTap: () =>
                          _navigateTo(context, const OrdersReportScreen()),
                    ),
                    _buildReportCard(
                      context: context,
                      title: "Taomlar",
                      subtitle: "Eng ko'p sotilgan mahsulotlar",
                      icon: Icons.restaurant_menu,
                      color: Colors.orange,
                      metric: "$orderCount taom",
                      onTap: () =>
                          _navigateTo(context, const ProductsReportScreen()),
                    ),
                    _buildReportCard(
                      context: context,
                      title: "Ofitsiantlar",
                      subtitle: "Xodimlar ish faoliyati",
                      icon: Icons.people_alt,
                      color: Colors.purple,
                      metric: "Komissiya va savdo",
                      onTap: () =>
                          _navigateTo(context, const WaitersReportScreen()),
                    ),
                    _buildReportCard(
                      context: context,
                      title: "Stollar",
                      subtitle: "Stollar bo'yicha tushum",
                      icon: Icons.table_restaurant,
                      color: Colors.indigo,
                      metric: "Faol stollar tahlili",
                      onTap: () =>
                          _navigateTo(context, const TablesReportScreen()),
                    ),
                    _buildReportCard(
                      context: context,
                      title: "Joylar",
                      subtitle: "Zallar va qavatlar bo'yicha",
                      icon: Icons.location_on,
                      color: Colors.teal,
                      metric: "Zallar kesimida",
                      onTap: () =>
                          _navigateTo(context, const LocationsReportScreen()),
                    ),
                    _buildReportCard(
                      context: context,
                      title: "Umumiy hisobot",
                      subtitle: "Kunlik Z-Report va KPI",
                      icon: Icons.analytics,
                      color: Colors.redAccent,
                      metric: "Moliyaviy xulosa",
                      onTap: () =>
                          _navigateTo(context, const GeneralReportScreen()),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "Hisobotlar",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                "Tizim faoliyati va savdo tahlili",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
              ),
            ],
          ),
          _buildTelegramSyncButton(context),
        ],
      ),
    );
  }

  Widget _buildTelegramSyncButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _handleTelegramSync(context),
      icon: const Icon(Icons.send_rounded, size: 20),
      label: const Text("Telegram Botga Sinxronizatsiya"),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF229ED9), // Telegram Blue
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
        title: const Text("Telegram Bot Sozlamalari"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: tokenController,
              decoration: const InputDecoration(
                labelText: "Bot Token",
                hintText: "12345678:ABCDE...",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chatController,
              decoration: const InputDecoration(
                labelText: "Chat ID",
                hintText: "-10012345678",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
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
            child: const Text("Saqlash va Yuborish"),
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
    ).showSnackBar(const SnackBar(content: Text("Hisobot yuborilmoqda...")));

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
                  ? "Hisobot Telegramga yuborildi!"
                  : "Xatolik: Bot token yoki Chat ID xato.",
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Text(
              metric,
              style: TextStyle(
                fontSize: 15,
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
}
