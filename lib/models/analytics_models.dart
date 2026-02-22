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
      productId: (map['product_id'] as num?)?.toInt() ?? 0,
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
      waiterId: (map['waiter_id'] as num?)?.toInt() ?? 0,
      waiterName: map['waiter_name'] ?? 'Kassa',
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      serviceTotal: (map['service_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// TablePerformance - Stollar bo'yicha tushum
class TablePerformance {
  final int? tableId;
  final String tableName;
  final double revenue;
  final int ordersCount;

  TablePerformance({
    this.tableId,
    required this.tableName,
    required this.revenue,
    required this.ordersCount,
  });

  factory TablePerformance.fromMap(Map<String, dynamic> map) {
    return TablePerformance(
      tableId: (map['table_id'] as num?)?.toInt(),
      tableName: map['table_name'] ?? 'Noma\'lum',
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
      ordersCount: (map['orders_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// LocationPerformance - Zallar bo'yicha tushum
class LocationPerformance {
  final int? locationId;
  final String locationName;
  final double revenue;

  LocationPerformance({
    this.locationId,
    required this.locationName,
    required this.revenue,
  });

  factory LocationPerformance.fromMap(Map<String, dynamic> map) {
    return LocationPerformance(
      locationId: (map['location_id'] as num?)?.toInt(),
      locationName: map['location_name'] ?? 'Noma\'lum',
      revenue: (map['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// PaymentTypeStats - To'lov turlari bo'yicha statistika
class PaymentTypeStats {
  final String type;
  final double amount;
  final double percentage;

  PaymentTypeStats({
    required this.type,
    required this.amount,
    required this.percentage,
  });

  factory PaymentTypeStats.fromMap(Map<String, dynamic> map, double total) {
    final amount = (map['amount'] as num?)?.toDouble() ?? 0.0;
    return PaymentTypeStats(
      type: map['payment_type'] ?? 'Boshqa',
      amount: amount,
      percentage: total > 0 ? (amount / total) * 100 : 0.0,
    );
  }
}
