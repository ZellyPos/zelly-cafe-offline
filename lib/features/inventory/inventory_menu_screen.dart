import 'package:flutter/material.dart';

import 'screens/ingredients_screen.dart';
import 'screens/stock_management_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/stock_history_screen.dart';

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
            title: 'Xom-ashyolar',
            subtitle: 'Ingredientlar ro\'yxati',
            icon: Icons.egg_outlined,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IngredientsScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            title: 'Kirim / Chiqim',
            subtitle: 'Zaxirani boshqarish',
            icon: Icons.swap_vert_circle_outlined,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockManagementScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            title: 'Retseptlar',
            subtitle: 'BOM (Bill of Materials)',
            icon: Icons.receipt_long_outlined,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecipesScreen()),
            ),
          ),
          _buildMenuCard(
            context,
            title: 'Harakatlar Tarixi',
            subtitle: 'Ombor loglari',
            icon: Icons.history_outlined,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockHistoryScreen()),
            ),
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
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
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
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
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
