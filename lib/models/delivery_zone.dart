class DeliveryZone {
  final int? id;
  final String name;
  final double fee;
  final String color;
  final bool isActive;
  final String? polygonJson;

  const DeliveryZone({
    this.id,
    required this.name,
    required this.fee,
    this.color = '#6366F1',
    this.isActive = true,
    this.polygonJson,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fee': fee,
        'color': color,
        'is_active': isActive ? 1 : 0,
        'polygon_json': polygonJson,
      };

  factory DeliveryZone.fromMap(Map<String, dynamic> map) => DeliveryZone(
        id: map['id'] as int?,
        name: map['name'] as String,
        fee: (map['fee'] as num?)?.toDouble() ?? 0,
        color: map['color'] as String? ?? '#6366F1',
        isActive: (map['is_active'] as int? ?? 1) == 1,
        polygonJson: map['polygon_json'] as String?,
      );

  DeliveryZone copyWith({
    String? name,
    double? fee,
    String? color,
    bool? isActive,
    Object? polygonJson = _sentinel,
  }) =>
      DeliveryZone(
        id: id,
        name: name ?? this.name,
        fee: fee ?? this.fee,
        color: color ?? this.color,
        isActive: isActive ?? this.isActive,
        polygonJson: polygonJson == _sentinel ? this.polygonJson : polygonJson as String?,
      );
}

const _sentinel = Object();
