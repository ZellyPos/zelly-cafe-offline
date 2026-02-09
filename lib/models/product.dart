class Product {
  final int? id;
  final String name;
  final double price;
  final String category;
  final bool isActive;
  final String? imagePath;

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    this.isActive = true,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'is_active': isActive ? 1 : 0,
      'image_path': imagePath,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: map['price'],
      category: map['category'],
      isActive: map['is_active'] == 1,
      imagePath: map['image_path'],
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    String? category,
    bool? isActive,
    String? imagePath,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}
