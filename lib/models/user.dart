class AppUser {
  final int? id;
  final String name;
  final String pin;
  final String role;
  final int isActive;
  final String? permissions;

  AppUser({
    this.id,
    required this.name,
    required this.pin,
    required this.role,
    this.isActive = 1,
    this.permissions,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      name: map['name'],
      pin: map['pin'],
      role: map['role'],
      isActive: map['is_active'] ?? 1,
      permissions: map['permissions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'pin': pin,
      'role': role,
      'is_active': isActive,
      'permissions': permissions,
    };
  }

  AppUser copyWith({
    int? id,
    String? name,
    String? pin,
    String? role,
    int? isActive,
    String? permissions,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
    );
  }
}
