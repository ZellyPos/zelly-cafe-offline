import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../core/app_strings.dart';
import '../../core/utils/price_formatter.dart';

import '../../providers/waiter_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/table.dart';
import 'widgets/payment_dialog.dart';

enum ProductSortMode {
  custom,
  popularity,
  priceLowToHigh,
  priceHighToLow,
  alphabetical,
}

class PosScreen extends StatefulWidget {
  final int orderType; // 0 = Dine-in, 1 = Saboy
  final TableModel? table;

  const PosScreen({super.key, this.orderType = 0, this.table});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String selectedCategory = AppStrings.all;
  ProductSortMode _currentSort = ProductSortMode.custom;
  Timer? _refreshTimer;
  late PageController _pageController;
  late ScrollController _categoryScrollController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _categoryScrollController = ScrollController();
    _loadSortPreference();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivity = context.read<ConnectivityProvider>();
      final cartProvider = context.read<CartProvider>();

      // Refresh products and categories for the current session policy
      context.read<ProductProvider>().loadProducts(connectivity: connectivity);
      context.read<CategoryProvider>().loadCategories(
        connectivity: connectivity,
      );

      // Validate table access for waiters
      _validateTableAccess(connectivity);

      cartProvider.loadTableOrder(
        widget.table?.id,
        widget.table?.locationId,
        connectivity,
      );

      final waiterProvider = context.read<WaiterProvider>();
      if (waiterProvider.waiters.isEmpty) {
        waiterProvider.loadWaiters();
      }
    });
  }

  void _validateTableAccess(ConnectivityProvider connectivity) {
    if (widget.table == null) return;

    final role = connectivity.currentUser?['role'] ?? 'admin';

    // Only validate for waiters
    if (role == 'waiter') {
      final userId = connectivity.currentUser?['id'];
      final table = widget.table!;

      // Check if table is occupied by another waiter
      if (table.status == 1 &&
          table.activeOrder?.waiterId != null &&
          table.activeOrder?.waiterId != userId) {
        // Show error and navigate back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bu stol boshqa ofitsiantga biriktirilgan!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pageController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  void _scrollToCategory(int index) {
    if (_categoryScrollController.hasClients) {
      _categoryScrollController.animateTo(
        index * 100.0, // Approximate width per chip + separator
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSort = prefs.getString('pos_product_sort');
    if (savedSort != null) {
      setState(() {
        _currentSort = ProductSortMode.values.firstWhere(
          (e) => e.toString() == savedSort,
          orElse: () => ProductSortMode.custom,
        );
      });
    }
  }

  Future<void> _saveSortPreference(ProductSortMode sort) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_product_sort', sort.toString());
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final cartProvider = context.watch<CartProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final categories = [
      AppStrings.all,
      ...categoryProvider.categories.map((c) => c.name),
    ];
    final allProducts = productProvider.products
        .where((p) => p.isActive)
        .toList();

    // Group by category sort order then product sort order when in custom mode
    if (_currentSort == ProductSortMode.custom) {
      final categoryOrders = {
        for (var cat in categoryProvider.categories) cat.name: cat.sortOrder,
      };
      allProducts.sort((a, b) {
        final aCatOrder = categoryOrders[a.category] ?? 999;
        final bCatOrder = categoryOrders[b.category] ?? 999;
        if (aCatOrder != bCatOrder) return aCatOrder.compareTo(bCatOrder);
        return a.sortOrder.compareTo(b.sortOrder);
      });
    }

    var filteredProducts = selectedCategory == AppStrings.all
        ? allProducts
        : allProducts.where((p) => p.category == selectedCategory).toList();

    // Sort by sales count in "Barchasi" (All) category ONLY if mode is popularity
    if (selectedCategory == AppStrings.all &&
        _currentSort == ProductSortMode.popularity) {
      filteredProducts.sort((a, b) {
        final aSales = productProvider.getProductSalesCount(a.id ?? 0);
        final bSales = productProvider.getProductSalesCount(b.id ?? 0);
        return bSales.compareTo(aSales); // Descending order (most sold first)
      });
    }

    final size = MediaQuery.of(context).size;
    final bool isCompact = size.width <= 1100 || size.height <= 800;

    return Scaffold(
      body: Row(
        children: [
          // Left Side: Products Grid
          Expanded(
            flex: 2,
            child: Column(
              children: [
                // Context Header (Table/Waiter info)
                if (widget.orderType == 0 && widget.table != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('⬅ Orqaga'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: isCompact
                                ? const EdgeInsets.symmetric(horizontal: 12)
                                : null,
                          ),
                        ),
                        SizedBox(width: isCompact ? 10 : 20),
                        const Icon(
                          Icons.table_bar,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Stol: ${widget.table!.name}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isCompact ? 14 : 16,
                          ),
                        ),
                        SizedBox(width: isCompact ? 12 : 24),
                        // Waiter Selector
                        const Icon(Icons.person, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OffsetantDropdown(cartProvider: cartProvider),
                        ),
                        if (cartProvider.activeOpenedAt != null) ...[
                          SizedBox(width: isCompact ? 12 : 24),
                          const Icon(Icons.timer, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isCompact
                                ? "${cartProvider.activeOpenedAt!.hour.toString().padLeft(2, '0')}:${cartProvider.activeOpenedAt!.minute.toString().padLeft(2, '0')}"
                                : "Ochilgan: ${cartProvider.activeOpenedAt!.hour.toString().padLeft(2, '0')}:${cartProvider.activeOpenedAt!.minute.toString().padLeft(2, '0')}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 12 : 14,
                            ),
                          ),
                          if (widget.table?.pricingType == 1) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "Daq: ${DateTime.now().difference(cartProvider.activeOpenedAt!).inMinutes}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange.shade900,
                                  fontSize: isCompact ? 11 : 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(width: 12),
                        _buildSortButton(),
                      ],
                    ),
                  )
                else if (widget.orderType == 1)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('⬅ Orqaga'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        const Icon(Icons.shopping_bag, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Text(
                          'SABOY (Olib ketish)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        _buildSortButton(),
                      ],
                    ),
                  ),
                // Category Bar
                Container(
                  height: 75,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Fixed Burger Button
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () => _showCategoryModal(
                            context,
                            categories,
                            categoryProvider,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      // Scrollable Categories
                      Expanded(
                        child: ListView.separated(
                          controller: _categoryScrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = selectedCategory == cat;

                            // Get category color
                            Color? catColor;
                            if (cat != AppStrings.all) {
                              try {
                                final category = categoryProvider.categories
                                    .firstWhere((c) => c.name == cat);
                                if (category.color != null) {
                                  catColor = Color(
                                    int.parse(
                                      category.color!.replaceFirst('#', '0xFF'),
                                    ),
                                  );
                                }
                              } catch (_) {}
                            }

                            return ChoiceChip(
                              label: Text(
                                cat,
                                style: TextStyle(
                                  fontSize: isCompact ? 16 : 18,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (val) {
                                if (val) {
                                  setState(() => selectedCategory = cat);
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                  _scrollToCategory(index);
                                }
                              },
                              selectedColor: catColor ?? AppTheme.primaryColor,
                              backgroundColor:
                                  catColor?.withOpacity(1) ??
                                  Colors.grey.shade100,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Products Grid with PageView for Swiping
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: productProvider.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: categories.length,
                            onPageChanged: (index) {
                              setState(() {
                                selectedCategory = categories[index];
                              });
                              _scrollToCategory(index);
                            },
                            itemBuilder: (context, catIndex) {
                              final currentCat = categories[catIndex];
                              final List<Product> pageProducts =
                                  currentCat == AppStrings.all
                                  ? allProducts
                                  : allProducts
                                        .where((p) => p.category == currentCat)
                                        .toList();

                              // Apply sorting
                              switch (_currentSort) {
                                case ProductSortMode.popularity:
                                  pageProducts.sort((a, b) {
                                    final aSales = productProvider
                                        .getProductSalesCount(a.id ?? 0);
                                    final bSales = productProvider
                                        .getProductSalesCount(b.id ?? 0);
                                    return bSales.compareTo(aSales);
                                  });
                                  break;
                                case ProductSortMode.priceLowToHigh:
                                  pageProducts.sort(
                                    (a, b) => a.price.compareTo(b.price),
                                  );
                                  break;
                                case ProductSortMode.priceHighToLow:
                                  pageProducts.sort(
                                    (a, b) => b.price.compareTo(a.price),
                                  );
                                  break;
                                case ProductSortMode.alphabetical:
                                  pageProducts.sort(
                                    (a, b) => a.name.toLowerCase().compareTo(
                                      b.name.toLowerCase(),
                                    ),
                                  );
                                  break;
                                case ProductSortMode.custom:
                                  // Already sorted by sort_order from provider
                                  break;
                              }

                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount:
                                          MediaQuery.of(context).size.width >=
                                              1600
                                          ? 6
                                          : (MediaQuery.of(
                                                      context,
                                                    ).size.width >=
                                                    1200
                                                ? 5
                                                : 4),
                                      childAspectRatio: isCompact ? 0.9 : 1.1,
                                      crossAxisSpacing: isCompact ? 8 : 12,
                                      mainAxisSpacing: isCompact ? 8 : 12,
                                    ),
                                itemCount: pageProducts.length,
                                itemBuilder: (context, index) {
                                  final product = pageProducts[index];
                                  return _buildProductCard(
                                    context,
                                    product,
                                    isCompact,
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),

          // Right Side: Order Panel
          Container(
            width: isCompact ? 340 : 400,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                // Cart Header
                Container(
                  padding: EdgeInsets.all(isCompact ? 12 : 20),
                  color: Colors.grey.shade50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppStrings.currentOrder,
                        style: TextStyle(
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => cartProvider.clearCart(
                          context.read<ConnectivityProvider>(),
                          context,
                        ),
                      ),
                    ],
                  ),
                ),
                // Items List
                Expanded(
                  child: ListView.builder(
                    itemCount: cartProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = cartProvider.items.values.toList()[index];
                      return Dismissible(
                        key: Key('cart_${item.product.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          cartProvider.removeItem(
                            item.product.id!,
                            context.read<ConnectivityProvider>(),
                            context,
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isCompact ? 6 : 16,
                            vertical: isCompact ? 8 : 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Product Name Block
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.product.name,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isCompact ? 13 : 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      PriceFormatter.format(item.product.price),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: isCompact ? 11 : 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              // Controls & Total
                              Flexible(
                                flex: 4,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Qty Stepper
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                        vertical: 2,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildQtyIconBtn(
                                            Icons.remove,
                                            isCompact,
                                            () => cartProvider.updateQuantity(
                                              item.product.id!,
                                              item.quantity - 1,
                                              context
                                                  .read<ConnectivityProvider>(),
                                              context,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 2,
                                            ),
                                            child: Text(
                                              '${item.quantity}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isCompact ? 12 : 14,
                                              ),
                                            ),
                                          ),
                                          _buildQtyIconBtn(
                                            Icons.add,
                                            isCompact,
                                            () => cartProvider.updateQuantity(
                                              item.product.id!,
                                              item.quantity + 1,
                                              context
                                                  .read<ConnectivityProvider>(),
                                              context,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: isCompact ? 4 : 8),
                                    // Line Total
                                    Flexible(
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minWidth: isCompact ? 60 : 80,
                                          maxWidth: isCompact ? 90 : 110,
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            PriceFormatter.format(item.total),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isCompact ? 13 : 14,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Totals & Checkout
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Totals Breakdown
                      Column(
                        children: [
                          _buildSummaryRow(
                            "Taomlar:",
                            cartProvider.totalAmount,
                            isCompact,
                          ),
                          widget.orderType == 0 && widget.table != null
                              ? FutureBuilder<double>(
                                  future: cartProvider.calculateRoomChargeForUI(
                                    context,
                                  ),
                                  builder: (context, snapshot) {
                                    final roomCharge = snapshot.data ?? 0;
                                    final serviceFee = cartProvider
                                        .calculateWaiterServiceFee(context);
                                    final grandTotal =
                                        cartProvider.totalAmount +
                                        roomCharge +
                                        serviceFee;

                                    return Column(
                                      children: [
                                        if (roomCharge > 0)
                                          _buildSummaryRow(
                                            "Xona/Stol:",
                                            roomCharge,
                                            isCompact,
                                          ),
                                        if (serviceFee > 0)
                                          _buildSummaryRow(
                                            "Ofitsiant xizmati:",
                                            serviceFee,
                                            isCompact,
                                          ),
                                        const Divider(height: 16),
                                        _buildSummaryRow(
                                          "JAMI:",
                                          grandTotal,
                                          isCompact,
                                          isMain: true,
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : Builder(
                                  builder: (context) {
                                    final serviceFee = cartProvider
                                        .calculateWaiterServiceFee(context);
                                    final grandTotal =
                                        cartProvider.totalAmount + serviceFee;
                                    return Column(
                                      children: [
                                        if (serviceFee > 0)
                                          _buildSummaryRow(
                                            "Ofitsiant xizmati:",
                                            serviceFee,
                                            isCompact,
                                          ),
                                        const Divider(height: 16),
                                        _buildSummaryRow(
                                          "JAMI:",
                                          grandTotal,
                                          isCompact,
                                          isMain: true,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Cancel Order Button (only for empty carts and cashier/admin)
                      if (cartProvider.items.isEmpty &&
                          cartProvider.activeOrderId != null &&
                          (context
                                      .read<ConnectivityProvider>()
                                      .currentUser?['role'] ??
                                  'admin') !=
                              'waiter')
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: () => _showCancelOrderDialog(context),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text(
                              'BUYURTMANI BEKOR QILISH',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      // Checkout Button
                      if (cartProvider.items.isNotEmpty)
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: cartProvider.items.isEmpty
                                ? null
                                : () {
                                    final role =
                                        context
                                            .read<ConnectivityProvider>()
                                            .currentUser?['role'] ??
                                        'admin';
                                    if (role == 'waiter') {
                                      // Waiters just save/update
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Buyurtma saqlandi!'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      Navigator.pop(context);
                                    } else {
                                      _showPaymentDialog(context);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              (context
                                              .read<ConnectivityProvider>()
                                              .currentUser?['role'] ??
                                          'admin') ==
                                      'waiter'
                                  ? 'SAQLASH'
                                  : AppStrings.checkout,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    bool isCompact,
  ) {
    // Look up category color
    final categoryProvider = context.read<CategoryProvider>();
    final category = categoryProvider.categories.firstWhere(
      (c) => c.name == product.category,
      orElse: () => Category(name: product.category),
    );

    Color? categoryColor;
    if (category.color != null) {
      try {
        categoryColor = Color(
          int.parse(category.color!.replaceFirst('#', '0xFF')),
        );
      } catch (e) {
        // Fallback to default
      }
    }

    final bool isDarkColor =
        categoryColor != null && categoryColor.computeLuminance() < 0.5;

    return InkWell(
      onTap: () => context.read<CartProvider>().addItem(
        product,
        context.read<ConnectivityProvider>(),
        context,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        color: categoryColor ?? Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: isCompact ? 100 : 120,
              child: Container(
                color: Colors.white.withOpacity(0.5),
                child: Builder(
                  builder: (context) {
                    final connectivity = context.read<ConnectivityProvider>();
                    final imageUrl = connectivity.getImageUrl(
                      product.imagePath,
                    );

                    if (imageUrl != null) {
                      if (imageUrl.startsWith('http')) {
                        return Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              Icons.broken_image,
                              size: isCompact ? 32 : 40,
                              color: isDarkColor
                                  ? Colors.white70
                                  : Colors.grey.shade400,
                            ),
                          ),
                        );
                      } else if (File(imageUrl).existsSync()) {
                        return Image.file(
                          File(imageUrl),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        );
                      }
                    }

                    return Center(
                      child: Icon(
                        Icons.fastfood,
                        size: isCompact ? 32 : 40,
                        color: isDarkColor
                            ? Colors.white70
                            : Colors.grey.shade400,
                      ),
                    );
                  },
                ),
              ),
            ),
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
                          : const Color(0xFF1E293B),
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
                              : AppTheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (product.isSet)
                        const Icon(
                          Icons.auto_awesome,
                          size: 14,
                          color: Colors.amber,
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

  Widget _buildQtyIconBtn(
    IconData icon,
    bool isCompact,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: isCompact ? 16 : 20, color: Colors.blue),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    double value,
    bool isCompact, {
    bool isMain = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 2 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMain ? (isCompact ? 18 : 20) : (isCompact ? 14 : 16),
              fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            PriceFormatter.format(value),
            style: TextStyle(
              fontSize: isMain ? (isCompact ? 22 : 24) : (isCompact ? 14 : 16),
              fontWeight: FontWeight.bold,
              color: isMain ? AppTheme.secondaryColor : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context) async {
    final cartProvider = context.read<CartProvider>();
    // Waiter is no longer mandatory; defaults to "Kassa"

    final double charge = await cartProvider.calculateRoomChargeForUI(context);
    final double serviceFee = cartProvider.calculateWaiterServiceFee(context);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StandardPaymentDialog(
        orderType: widget.orderType,
        table: widget.table,
        total: cartProvider.totalAmount + charge + serviceFee,
      ),
    ).then((success) {
      if (success == true) {
        if (cartProvider.lastPrintError != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                AppStrings.printerError,
                style: TextStyle(color: Colors.red),
              ),
              content: Text(
                '${AppStrings.printerError}\n\n${cartProvider.lastPrintError}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.paymentSuccess),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
        }
      }
    });
  }

  void _showCancelOrderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Buyurtmani bekor qilish',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Haqiqatan ham bu buyurtmani bekor qilmoqchimisiz? '
          'Stol bo\'sh holatga qaytariladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('YO\'Q'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final cartProvider = context.read<CartProvider>();
              final connectivity = context.read<ConnectivityProvider>();

              final success = await cartProvider.cancelOrder(connectivity);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Buyurtma bekor qilindi'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context); // Return to tables screen
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Xatolik yuz berdi'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('HA, BEKOR QILISH'),
          ),
        ],
      ),
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<ProductSortMode>(
      initialValue: _currentSort,
      onSelected: (ProductSortMode result) {
        setState(() {
          _currentSort = result;
        });
        _saveSortPreference(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              _currentSort == ProductSortMode.custom
                  ? "Mening tartibim"
                  : _currentSort == ProductSortMode.popularity
                  ? "Ommabop"
                  : _currentSort == ProductSortMode.priceHighToLow
                  ? "Qimmat"
                  : _currentSort == ProductSortMode.priceLowToHigh
                  ? "Arzon"
                  : "Alfabit",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ProductSortMode>>[
        const PopupMenuItem<ProductSortMode>(
          value: ProductSortMode.custom,
          child: Text("Sizning tartibingiz"),
        ),
        const PopupMenuItem<ProductSortMode>(
          value: ProductSortMode.popularity,
          child: Text("Ommabop (Sotuv bo'yicha)"),
        ),
        const PopupMenuItem<ProductSortMode>(
          value: ProductSortMode.priceHighToLow,
          child: Text('Qimmat'),
        ),
        const PopupMenuItem<ProductSortMode>(
          value: ProductSortMode.priceLowToHigh,
          child: Text('Arzon'),
        ),
        const PopupMenuItem<ProductSortMode>(
          value: ProductSortMode.alphabetical,
          child: Text('Alfabit bo\'yicha'),
        ),
      ],
    );
  }

  void _showCategoryModal(
    BuildContext context,
    List<String> categories,
    CategoryProvider categoryProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final size = MediaQuery.of(context).size;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: size.width * 0.8,
            height: size.height * 0.8,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kategoriyalar',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = selectedCategory == cat;

                      Color? catColor;
                      if (cat != AppStrings.all) {
                        try {
                          final category = categoryProvider.categories
                              .firstWhere((c) => c.name == cat);
                          if (category.color != null) {
                            catColor = Color(
                              int.parse(
                                category.color!.replaceFirst('#', '0xFF'),
                              ),
                            );
                          }
                        } catch (_) {}
                      }

                      final bool isDark =
                          catColor != null && catColor.computeLuminance() < 0.5;

                      return InkWell(
                        onTap: () {
                          setState(() => selectedCategory = cat);
                          _pageController.jumpToPage(index);
                          _scrollToCategory(index);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: catColor ?? Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            cat,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: catColor != null
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.black,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PaymentDialog extends StatelessWidget {
  final int orderType;
  final TableModel? table;

  const PaymentDialog({super.key, required this.orderType, this.table});

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(32),
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              AppStrings.payment,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            Text(
              AppStrings.amountDue,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            Text(
              PriceFormatter.format(cartProvider.totalAmount),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: _buildPaymentOption(
                    context,
                    AppStrings.cash,
                    Icons.payments,
                    () => _processPayment(context, 'Cash'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildPaymentOption(
                    context,
                    AppStrings.card,
                    Icons.credit_card,
                    () => _processPayment(context, 'Card'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                AppStrings.cancel,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: AppTheme.primaryColor),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment(BuildContext context, String method) async {
    final cartProvider = context.read<CartProvider>();
    final success = await cartProvider.checkout(
      context: context,
      paymentType: method,
      orderType: orderType,
      tableId: table?.id,
      locationId: table?.locationId,
    );

    if (context.mounted) {
      Navigator.pop(context);
      if (success) {
        if (cartProvider.lastPrintError != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(
                AppStrings.printerError,
                style: TextStyle(color: Colors.red),
              ),
              content: Text(
                '${AppStrings.printerError}\n\n${cartProvider.lastPrintError}',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(AppStrings.paymentSuccess),
              backgroundColor: AppTheme.secondaryColor,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.paymentFailed),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}

class OffsetantDropdown extends StatelessWidget {
  final CartProvider cartProvider;

  const OffsetantDropdown({super.key, required this.cartProvider});

  @override
  Widget build(BuildContext context) {
    return Consumer<WaiterProvider>(
      builder: (context, waiterProvider, _) {
        final waiters = waiterProvider.waiters;
        return DropdownButton<int>(
          value: cartProvider.activeWaiterId,
          hint: const Text("Ofitsiant: Kassa"),
          isExpanded: true,
          underline: const SizedBox(),
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
          items: waiters.map((w) {
            return DropdownMenuItem<int>(value: w.id, child: Text(w.name));
          }).toList(),
          onChanged: (val) {
            cartProvider.setWaiter(val, context);
          },
        );
      },
    );
  }
}
