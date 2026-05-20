import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../widgets/open_shift_dialog.dart';
import '../widgets/cash_movement_dialog.dart';
import 'close_shift_screen.dart';
import 'shift_history_screen.dart';
import '../../../features/settings/shift_settings_screen.dart';

class ShiftHubScreen extends StatefulWidget {
  const ShiftHubScreen({super.key});

  @override
  State<ShiftHubScreen> createState() => _ShiftHubScreenState();
}

class _ShiftHubScreenState extends State<ShiftHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Holat'),
    Tab(icon: Icon(Icons.lock_rounded, size: 18), text: 'Yopish'),
    Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Tarixi'),
    Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'Sozlamalar'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Smena',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          indicatorColor: const Color(0xFF6366F1),
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          dividerColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ShiftStatusTab(onGoToClose: () => _tabController.animateTo(1)),
          const CloseShiftScreen(embedded: true),
          const ShiftHistoryScreen(embedded: true),
          const ShiftSettingsScreen(embedded: true),
        ],
      ),
    );
  }
}

// ── Holat tab ─────────────────────────────────────────────────────────────────

class _ShiftStatusTab extends StatelessWidget {
  final VoidCallback onGoToClose;
  const _ShiftStatusTab({required this.onGoToClose});

  @override
  Widget build(BuildContext context) {
    final shiftProvider = context.watch<ShiftProvider>();
    final shift = shiftProvider.activeShift;
    final theme = Theme.of(context);

    if (shift == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 36, color: Colors.red),
            ),
            const SizedBox(height: 20),
            const Text(
              'Smena yopiq',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buyurtma qabul qilish uchun smenani oching',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const OpenShiftDialog(),
              ),
              icon: const Icon(Icons.lock_open_rounded, size: 20),
              label: const Text(
                'Smena ochish',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    // Smena ochiq
    final summary = shiftProvider.liveSummary;
    final elapsed = shiftProvider.elapsedTime;
    final elapsedStr =
        '${elapsed.inHours} soat ${elapsed.inMinutes % 60} daqiqa';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status banner ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.lock_open_rounded,
                      color: Color(0xFF10B981), size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Smena ochiq',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '#${shift.id}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        elapsedStr,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Statistika kartochkalari ───────────────────────────────────────
          if (summary != null)
            Row(
              children: [
                _statCard(
                  label: 'Naqd savdo',
                  value: '${PriceFormatter.format(summary.totalCashSales)} so\'m',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF10B981),
                  theme: theme,
                ),
                const SizedBox(width: 16),
                _statCard(
                  label: 'Karta savdo',
                  value: '${PriceFormatter.format(summary.totalCardSales)} so\'m',
                  icon: Icons.credit_card_rounded,
                  color: const Color(0xFF6366F1),
                  theme: theme,
                ),
                const SizedBox(width: 16),
                _statCard(
                  label: 'Jami savdo',
                  value: '${PriceFormatter.format(summary.totalSales)} so\'m',
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFFF59E0B),
                  theme: theme,
                ),
              ],
            ),

          const SizedBox(height: 24),

          // ── Amallar ────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Kassa harakati',
                  subtitle: 'Kirim / Chiqim',
                  color: const Color(0xFFF59E0B),
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const CashMovementDialog(),
                  ),
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _actionButton(
                  icon: Icons.lock_rounded,
                  label: 'Smena yopish',
                  subtitle: 'Hisobotni ko\'rish va yopish',
                  color: Colors.red,
                  onTap: onGoToClose,
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required ThemeData theme,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
