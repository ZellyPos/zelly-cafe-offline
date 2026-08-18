import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/app_strings.dart';
import '../../../core/theme.dart';

class ProductCardWidget extends StatelessWidget {
  final Product product;
  final bool isCompact;
  final Function(BuildContext, Product) onShowQuantityDialog;

  const ProductCardWidget({
    super.key,
    required this.product,
    required this.isCompact,
    required this.onShowQuantityDialog,
  });

  static const _accent = Color(0xFF6366F1);

  /// Tugagan taom rangi (§9) — karta butunlay qizil hoshiyali bo'ladi.
  static const _outOfStock = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = context.select<CategoryProvider, Color?>((provider) {
      final category = provider.categories.firstWhere(
        (c) => c.name == product.category,
        orElse: () => Category(name: product.category),
      );
      if (category.color == null) return null;
      try {
        return Color(int.parse(category.color!.replaceFirst('#', '0xFF')));
      } catch (e) {
        return null;
      }
    });

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final qtyInCart = product.id != null
            ? cart.getProductCartQuantity(product.id!)
            : 0.0;
        final inCart = qtyInCart > 0;
        // Taom tugagan (§9): qoldig'i yuritiladi va savatdagisini hisobga
        // olganda hech narsa qolmagan. Savatdagi belgidan ustun turadi —
        // "tugagan" holat muhimroq.
        final outOfStock =
            product.quantity != null && (product.quantity! - qtyInCart) <= 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: outOfStock
                ? _outOfStock.withValues(alpha: 0.08)
                : inCart
                ? _accent.withValues(alpha: 0.07)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            boxShadow: AppTheme.softShadow,
            border: Border.all(
              color: outOfStock
                  ? _outOfStock.withValues(alpha: 0.55)
                  : inCart
                  ? _accent.withValues(alpha: 0.35)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.read<CartProvider>().addItem(
                    product,
                    context.read<ConnectivityProvider>(),
                    context,
                  ),
              onLongPress: () => onShowQuantityDialog(context, product),
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImage(
                    context,
                    categoryColor,
                    inCart,
                    qtyInCart,
                    theme,
                    outOfStock,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: isCompact ? 14 : 16,
                            height: 1.1,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${PriceFormatter.format(product.price)} so'm",
                                    style: TextStyle(
                                      color: const Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: isCompact ? 13 : 15,
                                    ),
                                  ),
                                  Text(
                                    '/ ${AppStrings.getUnitLabel(product.unit)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.4),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (product.quantity != null)
                              _buildStockBadge(
                                  product.quantity! - qtyInCart, theme),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(
    BuildContext context,
    Color? categoryColor,
    bool inCart,
    double qtyInCart,
    ThemeData theme,
    bool outOfStock,
  ) {
    return Expanded(
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: outOfStock
                  ? _outOfStock.withValues(alpha: 0.06)
                  : inCart
                  ? _accent.withValues(alpha: 0.05)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.borderRadius),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Builder(
              builder: (context) {
                final connectivity = context.read<ConnectivityProvider>();
                final imageUrl = connectivity.getImageUrl(product.imagePath);
                if (imageUrl != null) {
                  if (imageUrl.startsWith('http')) {
                    return Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildPlaceholder(theme),
                    );
                  } else {
                    return Image.file(
                      File(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _buildPlaceholder(theme),
                    );
                  }
                }
                return _buildPlaceholder(theme);
              },
            ),
          ),

          // Kategoriya rangi
          if (categoryColor != null)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: categoryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),

          // Set belgisi
          if (product.isSet)
            Positioned(
              top: 8,
              right: inCart ? 36 : 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Colors.orange,
                ),
              ),
            ),

          // Cartdagi miqdor badge
          if (inCart)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '×${qtyInCart.toStringAsFixed(qtyInCart % 1 == 0 ? 0 : 1)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(double displayQty, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: displayQty <= 5
            ? Colors.red.withValues(alpha: 0.1)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: displayQty <= 5
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 10,
            color: displayQty <= 5
                ? Colors.red
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 4),
          Text(
            displayQty <= 0
                ? 'Tugadi'
                : 'Qoldi: ${displayQty.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 10,
              color: displayQty <= 5
                  ? Colors.red
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.fastfood_rounded,
        size: isCompact ? 32 : 40,
        color: const Color(0xFFE2E8F0),
      ),
    );
  }
}
