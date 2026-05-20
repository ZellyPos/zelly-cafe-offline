class Courier {
  final int? id;
  final String name;
  final String? phone;
  final bool isActive;

  const Courier({
    this.id,
    required this.name,
    this.phone,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'is_active': isActive ? 1 : 0,
      };

  factory Courier.fromMap(Map<String, dynamic> map) => Courier(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Courier copyWith({String? name, String? phone, bool? isActive}) => Courier(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        isActive: isActive ?? this.isActive,
      );
}
