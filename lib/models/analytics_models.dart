/// DailySalesStats - Kunlik sotuvlar statistikasi
class DailySalesStats {
  final String date; // YYYY-MM-DD
  final double total;
  final double cash;
  final double card;
  final double debt;
  final int ordersCount;

  DailySalesStats({
    required this.date,
    required this.total,
    required this.cash,
    required this.card,
    required this.debt,
    required this.ordersCount,
  });

  factory DailySalesStats.fromMap(Map<String, dynamic> map) {
    return DailySalesStats(
      date: map['date'].toString(),
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      cash: (map['cash'] as num?)?.toDouble() ?? 0.0,
      card: (map['card'] as num?)?.toDouble() ?? 0.0,
      debt: (map['debt'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// ProductPerformance - Mahsulotlar sotilishi statistikasi
class ProductPerformance {
  final int productId;
  final String productName;
  final double qty;
  final double revenue;

  ProductPerformance({
    required this.productId,
    required this.productName,
    required this.qty,
    required this.revenue,
  });

  factory ProductPerformance.fromMap(Map<String, dynamic> map) {
    return ProductPerformance(
      productId: map['product_id'] as int,
      productName: map['product_name'] ?? 'Noma\'lum',
      qty: (map['qty'] as num?)?.toDouble() ?? 0.0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// WaiterPerformance - Ofitsiantlar ish samaradorligi
class WaiterPerformance {
  final int waiterId;
  final String waiterName;
  final int ordersCount;
  final double revenue;
  final double serviceTotal;

  WaiterPerformance({
    required this.waiterId,
    required this.waiterName,
    required this.ordersCount,
    required this.revenue,
    required this.serviceTotal,
  });

  factory WaiterPerformance.fromMap(Map<String, dynamic> map) {
    return WaiterPerformance(
      waiterId: map['waiter_id'] as int,
      waiterName: map['waiter_name'] ?? 'Kassa',
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      serviceTotal: (map['service_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
