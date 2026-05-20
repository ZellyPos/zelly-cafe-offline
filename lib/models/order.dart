class OrderItem {
  final int? id;
  final String orderId;
  final int productId;
  final String productName; // Joined or cached
  final double qty;
  final String? unit;
  final double price;
  final String? bundleItemsJson;
  final double printedQty;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    this.productName = '',
    required this.qty,
    this.unit,
    required this.price,
    this.bundleItemsJson,
    this.printedQty = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      'qty': qty,
      'unit': unit,
      'price': price,
      'bundle_items_json': bundleItemsJson,
      'printed_qty': printedQty,
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
      productName: productName.isNotEmpty
          ? productName
          : (map['product_name'] as String? ?? ''),
      qty: (map['qty'] as num).toDouble(),
      unit: map['unit'],
      price: (map['price'] as num).toDouble(),
      bundleItemsJson: map['bundle_items_json'],
      printedQty: (map['printed_qty'] as num? ?? 0).toDouble(),
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
  final int orderType; // 0 = dine_in, 1 = takeaway, 2 = delivery
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
  final int? dailyNumber;

  // Order note / comment
  final String? note;

  // Shift linkage
  final int? shiftId;

  // Delivery fields (orderType == 2)
  final String? customerName;
  final String? customerPhone;
  final String? deliveryAddress;
  final int deliveryStatus; // 0=yangi, 1=tayyorlanmoqda, 2=yo'lda, 3=yetkazildi, 4=bekor
  final int? courierId;
  final double deliveryFee;
  final String? deliveryNote;
  final int? zoneId;

  // Bill request flag — set when waiter prints temp receipt
  final bool billRequested;

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
    this.dailyNumber,
    this.note,
    this.shiftId,
    this.customerName,
    this.customerPhone,
    this.deliveryAddress,
    this.deliveryStatus = 0,
    this.courierId,
    this.deliveryFee = 0,
    this.deliveryNote,
    this.zoneId,
    this.billRequested = false,
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
      'daily_number': dailyNumber,
      'note': note,
      'shift_id': shiftId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'delivery_address': deliveryAddress,
      'delivery_status': deliveryStatus,
      'courier_id': courierId,
      'delivery_fee': deliveryFee,
      'delivery_note': deliveryNote,
      'zone_id': zoneId,
      'bill_requested': billRequested ? 1 : 0,
    };
  }

  /// Full payload for remote print jobs — includes display fields and items.
  Map<String, dynamic> toPrintPayload() {
    return {
      ...toMap(),
      'table_name': tableName,
      'waiter_name': waiterName,
      'location_name': locationName,
      'items': items
          .map((i) => {
                ...i.toMap(),
                'product_name': i.productName,
              })
          .toList(),
    };
  }

  factory Order.fromPrintPayload(Map<String, dynamic> map) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((i) => OrderItem.fromMap(Map<String, dynamic>.from(i as Map)))
        .toList();
    return Order.fromMap(map, items: items);
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
      dailyNumber: map['daily_number'] as int?,
      note: map['note'] as String?,
      shiftId: map['shift_id'] as int?,
      customerName: map['customer_name'] as String?,
      customerPhone: map['customer_phone'] as String?,
      deliveryAddress: map['delivery_address'] as String?,
      deliveryStatus: (map['delivery_status'] as num?)?.toInt() ?? 0,
      courierId: map['courier_id'] as int?,
      deliveryFee: (map['delivery_fee'] as num?)?.toDouble() ?? 0,
      deliveryNote: map['delivery_note'] as String?,
      zoneId: map['zone_id'] as int?,
      billRequested: (map['bill_requested'] as int? ?? 0) == 1,
    );
  }
}
