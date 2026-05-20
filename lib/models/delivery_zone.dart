class DeliveryZone {
  final int? id;
  final String name;
  final double fee;
  final String color;
  final bool isActive;

  const DeliveryZone({
    this.id,
    required this.name,
    required this.fee,
    this.color = '#6366F1',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'fee': fee,
        'color': color,
        'is_active': isActive ? 1 : 0,
      };

  factory DeliveryZone.fromMap(Map<String, dynamic> map) => DeliveryZone(
        id: map['id'] as int?,
        name: map['name'] as String,
        fee: (map['fee'] as num?)?.toDouble() ?? 0,
        color: map['color'] as String? ?? '#6366F1',
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  DeliveryZone copyWith({String? name, double? fee, String? color, bool? isActive}) =>
      DeliveryZone(
        id: id,
        name: name ?? this.name,
        fee: fee ?? this.fee,
        color: color ?? this.color,
        isActive: isActive ?? this.isActive,
      );
}
