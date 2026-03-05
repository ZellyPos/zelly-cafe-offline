import 'dart:ui';
import 'package:flutter/material.dart';

class NavigationMenuDialog extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const NavigationMenuDialog({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: 600,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    _buildGrid(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Asosiy Menyu',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Kerakli bo\'limni tanlang',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.1),
            padding: const EdgeInsets.all(8),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context) {
    final items = [
      {'icon': Icons.table_bar_rounded, 'label': 'Stollar', 'index': 0},
      {'icon': Icons.inventory_2_rounded, 'label': 'Mahsulotlar', 'index': 1},
      {'icon': Icons.category_rounded, 'label': 'Kategoriyalar', 'index': 2},
      {'icon': Icons.layers_rounded, 'label': 'Zallar', 'index': 3},
      {
        'icon': Icons.settings_input_component_rounded,
        'label': 'Stol Sozl.',
        'index': 4,
      },
      {'icon': Icons.people_rounded, 'label': 'Ofitsiantlar', 'index': 5},
      {'icon': Icons.print_rounded, 'label': 'Printerlar', 'index': 7},
      {'icon': Icons.receipt_long_rounded, 'label': 'Chek Sozl.', 'index': 8},
      {'icon': Icons.bar_chart_rounded, 'label': 'Hisobotlar', 'index': 6},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = selectedIndex == item['index'];
        return _buildMenuItem(context, item, isSelected);
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    Map<String, dynamic> item,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () {
        onItemSelected(item['index'] as int);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item['icon'] as IconData, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            Text(
              item['label'] as String,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
