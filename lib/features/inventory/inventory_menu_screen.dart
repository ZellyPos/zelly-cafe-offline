import 'package:flutter/material.dart';

import 'screens/stock_flow_screen.dart';
import 'screens/stock_history_new_screen.dart';
import 'screens/stocktaking_screen.dart';
import 'screens/warehouse_screen.dart';

/// Ombor bo'limi menyusi.
///
/// Barcha ekranlar `docs/ombor_final.md` §4 spetsifikatsiyasi bo'yicha:
/// qoldiqlar (2 tab), kirim/chiqim, tarix va inventarizatsiya.
class InventoryMenuScreen extends StatelessWidget {
  const InventoryMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ombor Bo\'limi'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        children: [
          _buildMenuCard(
            context,
            title: 'Qoldiqlar',
            subtitle: 'Mahsulot va xomashyo · pishirish',
            icon: Icons.warehouse_outlined,
            color: Colors.teal,
            screen: const WarehouseScreen(),
          ),
          _buildMenuCard(
            context,
            title: 'Kirim / Chiqim',
            subtitle: 'Tannarx va yetkazuvchi bilan',
            icon: Icons.swap_vert_circle_outlined,
            color: Colors.blue,
            screen: const StockFlowScreen(),
          ),
          _buildMenuCard(
            context,
            title: 'Inventarizatsiya',
            subtitle: 'Real songa tenglashtirish',
            icon: Icons.fact_check_outlined,
            color: Colors.orange,
            screen: const StocktakingScreen(),
          ),
          _buildMenuCard(
            context,
            title: 'Harakatlar tarixi',
            subtitle: 'Kirim, chiqim, pishirish, sotuv',
            icon: Icons.history_outlined,
            color: Colors.purple,
            screen: const StockHistoryNewScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
