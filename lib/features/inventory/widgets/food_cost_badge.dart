import 'package:flutter/material.dart';

/// Food-cost foizi belgisi (§3).
///
/// `food_cost_% = tannarx / sotuv narxi × 100`. Restoranda odatda **25–35%**
/// maqbul hisoblanadi, shuning uchun rang shu chegaralarga qarab tanlanadi:
/// yashil (≤35%), sariq (≤45%), qizil (>45%).
///
/// Tannarx yoki narx noma'lum bo'lsa (0 yoki `null`) hech narsa
/// ko'rsatilmaydi — noto'g'ri 0% chalg'itadi.
class FoodCostBadge extends StatelessWidget {
  /// Bir dona mahsulotning tannarxi (retsept tannarxi yoki `avg_cost`).
  final double? cost;

  /// Sotuv narxi.
  final double price;

  /// Kichik ko'rinish (kartalar uchun).
  final bool compact;

  const FoodCostBadge({
    super.key,
    required this.cost,
    required this.price,
    this.compact = false,
  });

  /// Foizni hisoblaydi; hisoblab bo'lmasa `null`.
  static double? percentOf(double? cost, double price) {
    if (cost == null || cost <= 0 || price <= 0) return null;
    return cost / price * 100;
  }

  static Color colorFor(double percent) {
    if (percent <= 35) return Colors.green.shade700;
    if (percent <= 45) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final percent = percentOf(cost, price);
    if (percent == null) return const SizedBox.shrink();

    final color = colorFor(percent);
    return Tooltip(
      message:
          'Food-cost: tannarx sotuv narxining ${percent.toStringAsFixed(1)}% i',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 7 : 10,
          vertical: compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.pie_chart_outline_rounded,
              size: compact ? 11 : 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '${percent.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
