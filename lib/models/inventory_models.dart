class Ingredient {
  final int? id;
  final String name;
  final String baseUnit; // 'g', 'ml', 'pcs'
  final double minStock;
  final bool isActive;

  Ingredient({
    this.id,
    required this.name,
    required this.baseUnit,
    this.minStock = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'base_unit': baseUnit,
      'min_stock': minStock,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      id: map['id'],
      name: map['name'],
      baseUnit: map['base_unit'],
      minStock: (map['min_stock'] as num).toDouble(),
      isActive: map['is_active'] == 1,
    );
  }
}

class IngredientStock {
  final int ingredientId;
  final double onHand;
  final DateTime? updatedAt;

  IngredientStock({
    required this.ingredientId,
    required this.onHand,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'ingredient_id': ingredientId,
      'on_hand': onHand,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory IngredientStock.fromMap(Map<String, dynamic> map) {
    return IngredientStock(
      ingredientId: map['ingredient_id'],
      onHand: (map['on_hand'] as num).toDouble(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }
}

enum MovementType { IN, OUT, ADJUST, RETURN }

class StockMovement {
  final int? id;
  final int ingredientId;
  final MovementType type;
  final double qty;
  final String? reason;
  final String? refTable;
  final String? refId;
  final String? note;
  final DateTime createdAt;
  final int? createdBy;

  StockMovement({
    this.id,
    required this.ingredientId,
    required this.type,
    required this.qty,
    this.reason,
    this.refTable,
    this.refId,
    this.note,
    required this.createdAt,
    this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ingredient_id': ingredientId,
      'type': type.name,
      'qty': qty,
      'reason': reason,
      'ref_table': refTable,
      'ref_id': refId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'],
      ingredientId: map['ingredient_id'],
      type: MovementType.values.byName(map['type']),
      qty: (map['qty'] as num).toDouble(),
      reason: map['reason'],
      refTable: map['ref_table'],
      refId: map['ref_id'],
      note: map['note'],
      createdAt: DateTime.parse(map['created_at']),
      createdBy: map['created_by'],
    );
  }
}

class Recipe {
  final int? id;
  final int productId;
  final double yieldQty;
  final bool isActive;
  final List<RecipeItem> items;

  Recipe({
    this.id,
    required this.productId,
    this.yieldQty = 1.0,
    this.isActive = true,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'yield_qty': yieldQty,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Recipe.fromMap(
    Map<String, dynamic> map, {
    List<RecipeItem> items = const [],
  }) {
    return Recipe(
      id: map['id'],
      productId: map['product_id'],
      yieldQty: (map['yield_qty'] as num).toDouble(),
      isActive: map['is_active'] == 1,
      items: items,
    );
  }
}

class RecipeItem {
  final int? id;
  final int recipeId;
  final int ingredientId;
  final double qty;
  final String? ingredientName; // UI helper

  RecipeItem({
    this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.qty,
    this.ingredientName,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'ingredient_id': ingredientId,
      'qty': qty,
    };
  }

  factory RecipeItem.fromMap(
    Map<String, dynamic> map, {
    String? ingredientName,
  }) {
    return RecipeItem(
      id: map['id'],
      recipeId: map['recipe_id'],
      ingredientId: map['ingredient_id'],
      qty: (map['qty'] as num).toDouble(),
      ingredientName: ingredientName,
    );
  }

  RecipeItem copyWith({
    int? id,
    int? recipeId,
    int? ingredientId,
    double? qty,
    String? ingredientName,
  }) {
    return RecipeItem(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      ingredientId: ingredientId ?? this.ingredientId,
      qty: qty ?? this.qty,
      ingredientName: ingredientName ?? this.ingredientName,
    );
  }
}

class OrderInventoryFlag {
  final String orderId;
  final bool deducted;
  final DateTime? deductedAt;
  final bool reversed;
  final DateTime? reversedAt;

  OrderInventoryFlag({
    required this.orderId,
    this.deducted = false,
    this.deductedAt,
    this.reversed = false,
    this.reversedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'order_id': orderId,
      'deducted': deducted ? 1 : 0,
      'deducted_at': deductedAt?.toIso8601String(),
      'reversed': reversed ? 1 : 0,
      'reversed_at': reversedAt?.toIso8601String(),
    };
  }

  factory OrderInventoryFlag.fromMap(Map<String, dynamic> map) {
    return OrderInventoryFlag(
      orderId: map['order_id'],
      deducted: map['deducted'] == 1,
      deductedAt: map['deducted_at'] != null
          ? DateTime.parse(map['deducted_at'])
          : null,
      reversed: map['reversed'] == 1,
      reversedAt: map['reversed_at'] != null
          ? DateTime.parse(map['reversed_at'])
          : null,
    );
  }
}
