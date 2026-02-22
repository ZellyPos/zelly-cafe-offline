class TableModel {
  final int? id;
  final int locationId;
  final String name;
  final int status; // 0 = empty, 1 = occupied
  final int pricingType; // 0 = normal, 1 = hourly, 2 = fixed
  final double hourlyRate;
  final double fixedAmount;
  final double servicePercentage;
  final String?
  activeOrderId; // NEW: Track the specific order ID linked to this table
  final ActiveOrderInfo? activeOrder;

  // Layout Properties (Normalized 0..1)
  final double x;
  final double y;
  final double width;
  final double height;
  final int shape; // 0 = square, 1 = circle

  TableModel({
    this.id,
    required this.locationId,
    required this.name,
    this.status = 0,
    this.pricingType = 0,
    this.hourlyRate = 0,
    this.fixedAmount = 0,
    this.servicePercentage = 0,
    this.activeOrderId,
    this.activeOrder,
    this.x = 0,
    this.y = 0,
    this.width = 0.1,
    this.height = 0.1,
    this.shape = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'location_id': locationId,
      'name': name,
      'status': status,
      'pricing_type': pricingType,
      'hourly_rate': hourlyRate,
      'fixed_amount': fixedAmount,
      'service_percentage': servicePercentage,
      'active_order_id': activeOrderId,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'shape': shape,
    };
  }

  factory TableModel.fromMap(
    Map<String, dynamic> map, {
    ActiveOrderInfo? activeOrder,
  }) {
    return TableModel(
      id: map['id'],
      locationId: map['location_id'],
      name: map['name'],
      status: map['status'] ?? 0,
      pricingType: map['pricing_type'] ?? 0,
      hourlyRate: (map['hourly_rate'] as num?)?.toDouble() ?? 0.0,
      fixedAmount: (map['fixed_amount'] as num?)?.toDouble() ?? 0.0,
      servicePercentage: (map['service_percentage'] as num?)?.toDouble() ?? 0.0,
      activeOrderId: map['active_order_id'],
      activeOrder: activeOrder,
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      width: (map['width'] as num?)?.toDouble() ?? 0.1,
      height: (map['height'] as num?)?.toDouble() ?? 0.1,
      shape: map['shape'] ?? 0,
    );
  }

  TableModel copyWith({
    int? id,
    int? locationId,
    String? name,
    int? status,
    int? pricingType,
    double? hourlyRate,
    double? fixedAmount,
    double? servicePercentage,
    String? activeOrderId,
    ActiveOrderInfo? activeOrder,
    double? x,
    double? y,
    double? width,
    double? height,
    int? shape,
  }) {
    return TableModel(
      id: id ?? this.id,
      locationId: locationId ?? this.locationId,
      name: name ?? this.name,
      status: status ?? this.status,
      pricingType: pricingType ?? this.pricingType,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      fixedAmount: fixedAmount ?? this.fixedAmount,
      servicePercentage: servicePercentage ?? this.servicePercentage,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      activeOrder: activeOrder ?? this.activeOrder,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      shape: shape ?? this.shape,
    );
  }
}

class ActiveOrderInfo {
  final String orderId;
  final int? waiterId;
  final String? waiterName;
  final double totalAmount;
  final DateTime? openedAt;

  ActiveOrderInfo({
    required this.orderId,
    this.waiterId,
    this.waiterName,
    required this.totalAmount,
    this.openedAt,
  });
}
