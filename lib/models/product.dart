class Product {
  final int? id;
  final String name;
  final double price;
  final String category;
  final bool isActive;
  final String? imagePath;
  final bool isSet;
  final List<BundleItem>? bundleItems;
  final int sortOrder;

  Product({
    this.id,
    required this.name,
    required this.price,
    required this.category,
    this.isActive = true,
    this.imagePath,
    this.isSet = false,
    this.bundleItems,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
      'is_active': isActive ? 1 : 0,
      'image_path': imagePath,
      'is_set': isSet ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory Product.fromMap(
    Map<String, dynamic> map, {
    List<BundleItem>? bundleItems,
  }) {
    return Product(
      id: map['id'],
      name: map['name'],
      price: (map['price'] as num).toDouble(),
      category: map['category'],
      isActive: map['is_active'] == 1,
      imagePath: map['image_path'],
      isSet: map['is_set'] == 1,
      bundleItems: bundleItems,
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    String? category,
    bool? isActive,
    String? imagePath,
    bool? isSet,
    List<BundleItem>? bundleItems,
    int? sortOrder,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      imagePath: imagePath ?? this.imagePath,
      isSet: isSet ?? this.isSet,
      bundleItems: bundleItems ?? this.bundleItems,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

class BundleItem {
  final int? id;
  final int bundleId;
  final int productId;
  final double quantity;
  final String? productName; // Helper for UI

  BundleItem({
    this.id,
    required this.bundleId,
    required this.productId,
    this.quantity = 1.0,
    this.productName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bundle_id': bundleId,
      'product_id': productId,
      'quantity': quantity,
    };
  }

  factory BundleItem.fromMap(Map<String, dynamic> map) {
    return BundleItem(
      id: map['id'],
      bundleId: map['bundle_id'],
      productId: map['product_id'],
      quantity: (map['quantity'] as num).toDouble(),
      productName: map['product_name'] as String?,
    );
  }

  BundleItem copyWith({
    int? id,
    int? bundleId,
    int? productId,
    double? quantity,
    String? productName,
  }) {
    return BundleItem(
      id: id ?? this.id,
      bundleId: bundleId ?? this.bundleId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      productName: productName ?? this.productName,
    );
  }
}
