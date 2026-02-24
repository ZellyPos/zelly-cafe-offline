import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../core/utils/price_formatter.dart';

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

  @override
  Widget build(BuildContext context) {
    // We use context.select to only rebuild if the category color might have changed
    // (though categories usually don't change often, it's good practice)
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

    final bool isDarkColor =
        categoryColor != null && categoryColor.computeLuminance() < 0.5;

    return InkWell(
      onTap: () {
        context.read<CartProvider>().addItem(
          product,
          context.read<ConnectivityProvider>(),
          context,
        );
      },
      onLongPress: () => onShowQuantityDialog(context, product),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        color: categoryColor ?? Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImage(context, isDarkColor),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: isCompact ? 14 : 16,
                      height: 1.1,
                      color: isDarkColor
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isCompact ? 2 : 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        PriceFormatter.format(product.price),
                        style: TextStyle(
                          color: isDarkColor
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (product.quantity != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkColor
                                    ? Colors.white24
                                    : Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${product.quantity!.toStringAsFixed(0)} ta",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDarkColor
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (product.isSet) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(BuildContext context, bool isDarkColor) {
    return SizedBox(
      height: isCompact ? 100 : 120,
      child: Container(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        child: Builder(
          builder: (context) {
            final connectivity = context.read<ConnectivityProvider>();
            final imageUrl = connectivity.getImageUrl(product.imagePath);

            if (imageUrl != null) {
              if (imageUrl.startsWith('http')) {
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) =>
                      _buildPlaceholder(context, isDarkColor),
                );
              } else if (File(imageUrl).existsSync()) {
                return Image.file(
                  File(imageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              }
            }
            return _buildPlaceholder(context, isDarkColor);
          },
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, bool isDarkColor) {
    return Center(
      child: Icon(
        Icons.fastfood,
        size: isCompact ? 32 : 40,
        color: isDarkColor
            ? Colors.white.withOpacity(0.7)
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
      ),
    );
  }
}
