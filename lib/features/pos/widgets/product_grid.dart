import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/product.dart';
import '../../../providers/product_provider.dart';
import '../../../core/app_strings.dart';
import '../pos_screen.dart';
import 'product_card.dart';

class ProductGridWidget extends StatelessWidget {
  final PageController pageController;
  final List<String> categories;
  final String selectedCategory;
  final ProductSortMode currentSort;
  final bool isCompact;
  final Function(int) onPageChanged;
  final Function(BuildContext, Product) onShowQuantityDialog;

  const ProductGridWidget({
    super.key,
    required this.pageController,
    required this.categories,
    required this.selectedCategory,
    required this.currentSort,
    required this.isCompact,
    required this.onPageChanged,
    required this.onShowQuantityDialog,
  });

  @override
  Widget build(BuildContext context) {
    // Senior approach: Use Selector to only rebuild if products change
    return Selector<ProductProvider, List<Product>>(
      selector: (_, provider) =>
          provider.products.where((p) => p.isActive).toList(),
      shouldRebuild: (prev, next) {
        if (prev.length != next.length) return true;
        for (int i = 0; i < prev.length; i++) {
          if (prev[i] != next[i]) return true;
        }
        return false;
      },
      builder: (context, allProducts, _) {
        final productProvider = context.read<ProductProvider>();

        return PageView.builder(
          controller: pageController,
          itemCount: categories.length,
          onPageChanged: onPageChanged,
          itemBuilder: (context, catIndex) {
            final currentCat = categories[catIndex];
            final List<Product> pageProducts = currentCat == AppStrings.all
                ? allProducts
                : allProducts.where((p) => p.category == currentCat).toList();

            // apply current sorting logic
            final sortedProducts = _sortProducts(pageProducts, productProvider);

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width >= 1600
                    ? 6
                    : (MediaQuery.of(context).size.width >= 1200 ? 5 : 4),
                childAspectRatio: isCompact ? 0.9 : 1.1,
                crossAxisSpacing: isCompact ? 8 : 12,
                mainAxisSpacing: isCompact ? 8 : 12,
              ),
              itemCount: sortedProducts.length,
              itemBuilder: (context, index) {
                return ProductCardWidget(
                  product: sortedProducts[index],
                  isCompact: isCompact,
                  onShowQuantityDialog: onShowQuantityDialog,
                );
              },
            );
          },
        );
      },
    );
  }

  List<Product> _sortProducts(
    List<Product> products,
    ProductProvider provider,
  ) {
    final list = List<Product>.from(products);
    switch (currentSort) {
      case ProductSortMode.popularity:
        list.sort((a, b) {
          final aSales = provider.getProductSalesCount(a.id ?? 0);
          final bSales = provider.getProductSalesCount(b.id ?? 0);
          return bSales.compareTo(aSales);
        });
        break;
      case ProductSortMode.priceLowToHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortMode.priceHighToLow:
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSortMode.alphabetical:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
        break;
      case ProductSortMode.custom:
        // Assume already sorted by sortOrder if provider provides them sorted
        // or we could sort here if needed
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        break;
    }
    return list;
  }
}
