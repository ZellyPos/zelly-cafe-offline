class OrderItem {
  final int? id;
  final String orderId;
  final int productId;
  final String productName; // Joined or cached
  final int qty;
  final double price;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    this.productName = '',
    required this.qty,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'qty': qty,
      'price': price,
    };
  }

  factory OrderItem.fromMap(
    Map<String, dynamic> map, {
    String productName = '',
  }) {
    return OrderItem(
      id: map['id'],
      orderId: map['order_id'],
      productId: map['product_id'],
      productName: productName,
      qty: map['qty'],
      price: map['price'],
    );
  }
}

class Order {
  final String id;
  final double total;
  final String paymentType;
  final DateTime createdAt;
  final List<OrderItem> items;

  // New Restaurant Mode fields
  final int orderType; // 0 = dine_in, 1 = takeaway
  final int? tableId;
  final int? locationId;
  final int? waiterId;
  final int status; // 0 = open, 1 = paid/closed

  // Room Pricing fields
  final DateTime? openedAt;
  final DateTime? closedAt;
  final double roomCharge;

  // Waiter Service Fee fields
  final double foodTotal;
  final double roomTotal; // This should be same as roomCharge
  final double serviceTotal;
  final double grandTotal;

  // Metadata for printing/reports
  final String? tableName;
  final String? locationName;
  final String? waiterName;

  // Payment details
  final double paidAmount;
  final double change;

  Order({
    required this.id,
    required this.total,
    required this.paymentType,
    required this.createdAt,
    this.items = const [],
    this.orderType = 0,
    this.tableId,
    this.locationId,
    this.waiterId,
    this.status = 1,
    this.openedAt,
    this.closedAt,
    this.roomCharge = 0,
    this.tableName,
    this.locationName,
    this.waiterName,
    this.paidAmount = 0,
    this.change = 0,
    this.foodTotal = 0,
    this.roomTotal = 0,
    this.serviceTotal = 0,
    this.grandTotal = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'total': total,
      'payment_type': paymentType,
      'created_at': createdAt.toIso8601String(),
      'order_type': orderType,
      'table_id': tableId,
      'location_id': locationId,
      'waiter_id': waiterId,
      'status': status,
      'opened_at': openedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'room_charge': roomCharge,
      'paid_amount': paidAmount,
      'receipt_change':
          change, // 'change' is a keyword in some contexts, using receipt_change
      'food_total': foodTotal,
      'room_total': roomTotal,
      'service_total': serviceTotal,
      'grand_total': grandTotal,
    };
  }

  factory Order.fromMap(
    Map<String, dynamic> map, {
    List<OrderItem> items = const [],
  }) {
    return Order(
      id: map['id'],
      total: (map['total'] as num).toDouble(),
      paymentType: map['payment_type'],
      createdAt: DateTime.parse(map['created_at']),
      items: items,
      orderType: map['order_type'] ?? 0,
      tableId: map['table_id'],
      locationId: map['location_id'],
      waiterId: map['waiter_id'],
      status: map['status'] ?? 1,
      openedAt: map['opened_at'] != null
          ? DateTime.parse(map['opened_at'])
          : null,
      closedAt: map['closed_at'] != null
          ? DateTime.parse(map['closed_at'])
          : null,
      roomCharge: (map['room_charge'] as num?)?.toDouble() ?? 0.0,
      tableName: map['table_name'],
      locationName: map['location_name'],
      waiterName: map['waiter_name'],
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0.0,
      change: (map['receipt_change'] as num?)?.toDouble() ?? 0.0,
      foodTotal: (map['food_total'] as num?)?.toDouble() ?? 0.0,
      roomTotal: (map['room_total'] as num?)?.toDouble() ?? 0.0,
      serviceTotal: (map['service_total'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grand_total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
