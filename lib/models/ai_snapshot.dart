class AiSnapshot {
  final String period;
  final Map<String, dynamic> totals;
  final Map<String, double> paymentSplit;
  final Map<String, int> orderTypeSplit;
  final List<Map<String, dynamic>> topProductsQty;
  final List<Map<String, dynamic>> topProductsRevenue;
  final List<Map<String, dynamic>> bottomProducts;
  final List<Map<String, dynamic>> byWaiter;
  final List<Map<String, dynamic>> byLocation;
  final List<String> warnings;

  AiSnapshot({
    required this.period,
    required this.totals,
    required this.paymentSplit,
    required this.orderTypeSplit,
    required this.topProductsQty,
    required this.topProductsRevenue,
    required this.bottomProducts,
    required this.byWaiter,
    required this.byLocation,
    this.warnings = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'totals': totals,
      'payment_split': paymentSplit,
      'order_type_split': orderTypeSplit,
      'top_products_qty': topProductsQty,
      'top_products_revenue': topProductsRevenue,
      'bottom_products': bottomProducts,
      'by_waiter': byWaiter,
      'by_location': byLocation,
      'warnings': warnings,
    };
  }
}
