class TableModel {
  final int? id;
  final int locationId;
  final String name;
  final int status; // 0 = empty, 1 = occupied
  final int pricingType; // 0 = normal, 1 = hourly, 2 = fixed
  final double hourlyRate;
  final double fixedAmount;
  final double servicePercentage;
  final ActiveOrderInfo? activeOrder;

  TableModel({
    this.id,
    required this.locationId,
    required this.name,
    this.status = 0,
    this.pricingType = 0,
    this.hourlyRate = 0,
    this.fixedAmount = 0,
    this.servicePercentage = 0,
    this.activeOrder,
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
      activeOrder: activeOrder,
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
    ActiveOrderInfo? activeOrder,
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
      activeOrder: activeOrder ?? this.activeOrder,
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
