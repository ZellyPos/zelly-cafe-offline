class Category {
  final int? id;
  final String name;
  final String? color; // Hex color string
  final int sortOrder;
  final String? imagePath;

  Category({
    this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
      'image_path': imagePath,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: (map['id'] as num?)?.toInt(),
      name: map['name'] as String,
      color: map['color'] as String?,
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      imagePath: map['image_path'] as String?,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? color,
    int? sortOrder,
    Object? imagePath = _sentinel,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      imagePath: imagePath == _sentinel ? this.imagePath : imagePath as String?,
    );
  }
}

const _sentinel = Object();
