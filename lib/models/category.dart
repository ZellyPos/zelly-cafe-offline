class Category {
  final int? id;
  final String name;
  final String? color; // Hex color string
  final int sortOrder;

  Category({this.id, required this.name, this.color, this.sortOrder = 0});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'color': color, 'sort_order': sortOrder};
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
    );
  }

  Category copyWith({int? id, String? name, String? color, int? sortOrder}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
