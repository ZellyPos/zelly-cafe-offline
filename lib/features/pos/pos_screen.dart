import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/theme.dart';
import '../../core/app_strings.dart';
import '../../core/printing_service.dart';
import '../../providers/waiter_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/product.dart';
import '../../models/table.dart';
import '../../models/order.dart';
import '../../models/waiter.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/quantity_dialog.dart';
import 'widgets/product_grid.dart';
import 'widgets/cart_panel.dart';

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
          SnackBar(
            content: Text(AppStrings.tableOccupiedError),
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
    final categoryProvider = context.watch<CategoryProvider>();

    final categories = [
      AppStrings.all,
      ...categoryProvider.categories.map((c) => c.name),
    ];

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
                  _buildDineInHeader(context, isCompact)
                else if (widget.orderType == 1)
                  _buildSaboyHeader(context),

                // Category Bar
                _buildCategoryBar(
                  context,
                  categories,
                  categoryProvider,
                  isCompact,
                ),

                // Products Grid
                Expanded(
                  child: ProductGridWidget(
                    pageController: _pageController,
                    categories: categories,
                    selectedCategory: selectedCategory,
                    currentSort: _currentSort,
                    isCompact: isCompact,
                    onPageChanged: (index) {
                      setState(() => selectedCategory = categories[index]);
                      _scrollToCategory(index);
                    },
                    onShowQuantityDialog: _showQuantityDialog,
                  ),
                ),
              ],
            ),
          ),

          // Right Side: Order Panel
          CartPanelWidget(
            orderType: widget.orderType,
            table: widget.table,
            isCompact: isCompact,
            onShowPaymentDialog: () {
              final role =
                  context.read<ConnectivityProvider>().currentUser?['role'] ??
                  'admin';
              if (role == 'waiter') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppStrings.orderSaved),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(context);
              } else {
                _showPaymentDialog(context);
              }
            },
            onPrintReceipt: () => _printCurrentOrderReceipt(context),
            onCancelOrder: () => _showCancelOrderDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDineInHeader(BuildContext context, bool isCompact) {
    final cartProvider = context.read<CartProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isDark
          ? theme.colorScheme.surface
          : theme.colorScheme.primaryContainer.withOpacity(0.3),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: Text('⬅ ${AppStrings.back}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(width: isCompact ? 10 : 20),
          const Icon(Icons.table_bar, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Text(
            '${AppStrings.tableLabel}: ${widget.table!.name}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isCompact ? 14 : 16,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _showChangeTableDialog(context),
            icon: const Icon(Icons.swap_horiz, color: Colors.blue),
            tooltip: AppStrings.changeTable,
            iconSize: 20,
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _showMergeTableDialog(context),
            icon: const Icon(Icons.merge_type, color: Colors.blue),
            tooltip: 'Stollarni birlashtirish',
            iconSize: 20,
          ),
          SizedBox(width: isCompact ? 12 : 24),
          const Icon(Icons.person, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _showWaiterSelectionDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.white12
                        : Colors.blue.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cartProvider.activeWaiterId != null
                            ? context
                                  .watch<WaiterProvider>()
                                  .waiters
                                  .firstWhere(
                                    (w) => w.id == cartProvider.activeWaiterId,
                                    orElse: () => Waiter(
                                      name: AppStrings.kassa,
                                      type: 0,
                                      value: 0,
                                    ),
                                  )
                                  .name
                            : AppStrings.waiterKassa,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildTimerInfo(context, cartProvider, isCompact),
          const SizedBox(width: 12),
          const SizedBox(width: 12),
          const SizedBox(width: 12),
          _buildSortButton(context),
        ],
      ),
    );
  }

  Widget _buildSaboyHeader(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      color: isDark
          ? theme.colorScheme.surface
          : Colors.orange.withOpacity(0.1),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('⬅ Orqaga'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const Spacer(),
          _buildSortButton(context),
        ],
      ),
    );
  }

  Widget _buildTimerInfo(
    BuildContext context,
    CartProvider cartProvider,
    bool isCompact,
  ) {
    if (cartProvider.activeOpenedAt == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              "Daq: ${DateTime.now().difference(cartProvider.activeOpenedAt!).inMinutes}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.orange : Colors.orange.shade900,
                fontSize: isCompact ? 11 : 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryBar(
    BuildContext context,
    List<String> categories,
    CategoryProvider categoryProvider,
    bool isCompact,
  ) {
    return Container(
      height: 75,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildBurgerButton(context, categories, categoryProvider),
          Expanded(
            child: _buildCategoryList(categories, categoryProvider, isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildBurgerButton(
    BuildContext context,
    List<String> categories,
    CategoryProvider categoryProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => _showCategoryModal(context, categories, categoryProvider),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.grid_view_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    List<String> categories,
    CategoryProvider categoryProvider,
    bool isCompact,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView.separated(
      controller: _categoryScrollController,
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final isSelected = selectedCategory == cat;
        Color? catColor;
        if (cat != AppStrings.all) {
          try {
            final category = categoryProvider.categories.firstWhere(
              (c) => c.name == cat,
            );
            if (category.color != null) {
              catColor = Color(
                int.parse(category.color!.replaceFirst('#', '0xFF')),
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
                  : (isDark ? Colors.white70 : Colors.black),
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
              (isDark
                  ? theme.colorScheme.surface
                  : theme.dividerColor.withOpacity(0.1)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        );
      },
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
        // Refresh products to update stock quantities
        context.read<ProductProvider>().loadProducts(
          connectivity: context.read<ConnectivityProvider>(),
        );

        if (cartProvider.lastPrintError != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                AppStrings.printerError,
                style: const TextStyle(color: Colors.red),
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
            SnackBar(
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

  Widget _buildSortButton(BuildContext context) {
    final theme = Theme.of(context);
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
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
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
        final theme = Theme.of(context);
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
                            color: catColor ?? theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color: AppTheme.primaryColor,
                                    width: 2,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadowColor.withOpacity(0.05),
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
                                  : theme.colorScheme.onSurface,
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

  Future<void> _showQuantityDialog(
    BuildContext context,
    Product product,
  ) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => QuantityDialog(product: product),
    );

    if (result != null && result > 0 && mounted) {
      context.read<CartProvider>().addItem(
        product,
        context.read<ConnectivityProvider>(),
        context,
        result,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} savatga qo\'shildi ($result ta)'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _printCurrentOrderReceipt(BuildContext context) async {
    final cartProvider = context.read<CartProvider>();

    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Savda bo\'sh! Chek chiqarib bo\'lmaydi.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Convert CartItems to OrderItems
      final orderItems = cartProvider.items.entries.map((entry) {
        final cartItem = entry.value;
        return OrderItem(
          orderId: DateTime.now().millisecondsSinceEpoch.toString(),
          productId: cartItem.product.id ?? 0,
          productName: cartItem.product.name,
          qty: cartItem.quantity,
          price: cartItem.product.price,
        );
      }).toList();

      // Create a temporary order for receipt printing
      final order = Order(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        total: cartProvider.totalAmount,
        paymentType: 'pending',
        createdAt: DateTime.now(),
        items: orderItems,
        orderType: widget.orderType,
        tableId: widget.table?.id,
        locationId: widget.table?.locationId,
        waiterId: cartProvider.activeWaiterId,
        status: 0, // Open order
        tableName: widget.table?.name,
        foodTotal: cartProvider.totalAmount,
        grandTotal: cartProvider.totalAmount,
      );

      // Print the receipt
      final success = await PrintingService.printReceipt(order: order);

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chek muvaffaqiyatli chiqarildi!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chek chiqarishda xatolik yuz berdi!'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMergeTableDialog(BuildContext context) {
    final tableProvider = context.read<TableProvider>();
    final cartProvider = context.read<CartProvider>();
    final connectivity = context.read<ConnectivityProvider>();

    int selectedTabIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Dialog(
            backgroundColor: theme.colorScheme.surface,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              width: 900,
              height: 600,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(
                        Icons.merge_type,
                        color: Colors.blue,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Stollarni birlashtirish',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Quyidagi stollardan birini tanlang. Uning buyurtmasi ushbu stolga qo\'shiladi.',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Location Tabs
                  Consumer<LocationProvider>(
                    builder: (context, locProv, child) {
                      final locations = locProv.locations;
                      if (locations.isEmpty) {
                        return const Center(
                          child: Text('Lokatsiyalar topilmadi'),
                        );
                      }

                      return Column(
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: locations.asMap().entries.map((entry) {
                                final index = entry.key;
                                final location = entry.value;
                                final isSelected = index == selectedTabIndex;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() => selectedTabIndex = index);
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : theme.dividerColor.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        location.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Tab Content - Table Grid
                          SizedBox(
                            height: 420,
                            child: FutureBuilder<List<TableModel>>(
                              future: tableProvider.getTablesForLocation(
                                locations[selectedTabIndex].id,
                              ),
                              builder: (context, tableSnapshot) {
                                if (tableSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (!tableSnapshot.hasData ||
                                    tableSnapshot.data!.isEmpty) {
                                  return const Center(
                                    child: Text('Stollar yo\'q'),
                                  );
                                }

                                final tables = tableSnapshot.data!;

                                return Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 6,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                        ),
                                    itemCount: tables.length,
                                    itemBuilder: (context, index) {
                                      final table = tables[index];
                                      if (table.id == widget.table?.id) {
                                        return const SizedBox.shrink();
                                      }

                                      return InkWell(
                                        onTap: () async {
                                          final bool
                                          confirmed = await showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: const Text('Tasdiqlash'),
                                              content: Text(
                                                '${table.name} stoli buyurtmasi ushbu stolga birlashtirilsinmi?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        false,
                                                      ),
                                                  child: const Text('Yo\'q'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                        context,
                                                        true,
                                                      ),
                                                  child: const Text(
                                                    'Ha, birlashtirish',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed && context.mounted) {
                                            final success = await cartProvider
                                                .mergeTable(
                                                  table.id!,
                                                  widget.table!.id!,
                                                  connectivity,
                                                );

                                            if (context.mounted) {
                                              if (success) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Stollar muvaffaqiyatli birlashtirildi',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                                Navigator.pop(context);
                                              } else {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Xatolik yuz berdi',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: theme.colorScheme.surface,
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.shadowColor
                                                    .withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.table_bar,
                                                size: 28,
                                                color: table.status == 1
                                                    ? Colors.red
                                                    : Colors.green,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                table.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                table.status == 1
                                                    ? 'Band'
                                                    : 'Bo\'sh',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: table.status == 1
                                                      ? Colors.red
                                                      : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChangeTableDialog(BuildContext context) {
    final tableProvider = context.read<TableProvider>();
    final cartProvider = context.read<CartProvider>();

    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avval buyurtma qiling!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int selectedTabIndex = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          return Dialog(
            backgroundColor: theme.colorScheme.surface,
            insetPadding: EdgeInsets.zero,
            child: Container(
              width: 900,
              height: 600,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.swap_horiz,
                        color: theme.colorScheme.onSurface,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.changeTable,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Location Tabs
                  Consumer<LocationProvider>(
                    builder: (context, locationProvider, child) {
                      final locations = locationProvider.locations;

                      if (locations.isEmpty) {
                        return const Center(
                          child: Text('Lokatsiyalar topilmadi'),
                        );
                      }

                      return Column(
                        children: [
                          // Tab Bar - category style
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: locations.asMap().entries.map((entry) {
                                final index = entry.key;
                                final location = entry.value;
                                final isSelected = index == selectedTabIndex;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedTabIndex = index;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : theme.dividerColor.withOpacity(
                                                0.1,
                                              ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: isSelected
                                            ? Border.all(
                                                color: AppTheme.primaryColor,
                                                width: 2,
                                              )
                                            : null,
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.shadowColor
                                                .withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        location.name,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : theme.colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Tab Content
                          SizedBox(
                            height: 450,
                            child: FutureBuilder<List<TableModel>>(
                              future: tableProvider.getTablesForLocation(
                                locations[selectedTabIndex].id,
                              ),
                              builder: (context, tableSnapshot) {
                                if (tableSnapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                if (!tableSnapshot.hasData ||
                                    tableSnapshot.data!.isEmpty) {
                                  return const Center(
                                    child: Text('Bu lokatsiyada stollar yo\'q'),
                                  );
                                }

                                final tables = tableSnapshot.data!
                                    .where(
                                      (table) =>
                                          table.id != widget.table?.id &&
                                          table.status != 1,
                                    )
                                    .toList();

                                return Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: GridView.builder(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 6,
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 1.0,
                                        ),
                                    itemCount: tables.length,
                                    itemBuilder: (context, index) {
                                      final table = tables[index];
                                      return InkWell(
                                        onTap: () =>
                                            _moveOrderToTable(context, table),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: theme.colorScheme.surface,
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.shadowColor
                                                    .withOpacity(0.1),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.table_bar,
                                                size: 28,
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withOpacity(0.4),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                table.name ??
                                                    'Stol ${table.id}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                  color: theme
                                                      .colorScheme
                                                      .onSurface,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              Text(
                                                table.status == 1
                                                    ? 'Band'
                                                    : 'Bo\'sh',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: table.status == 1
                                                      ? Colors.red
                                                      : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _moveOrderToTable(BuildContext context, TableModel newTable) async {
    final cartProvider = context.read<CartProvider>();
    final tableProvider = context.read<TableProvider>();

    try {
      // Move order to new table
      await cartProvider.moveToTable(newTable.id!, newTable.locationId);

      // Update table statuses
      await tableProvider.updateTableStatus(
        widget.table!.id!,
        0,
      ); // Old table becomes available
      await tableProvider.updateTableStatus(
        newTable.id!,
        1,
      ); // New table becomes occupied

      Navigator.pop(context); // Close dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Buyurtma ${newTable.name ?? 'Stol ${newTable.id}'} ga ko\'chirildi!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to new table (replace current screen)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PosScreen(orderType: widget.orderType, table: newTable),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showWaiterSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ofitsiantni tanlang',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Consumer<WaiterProvider>(
                  builder: (context, waiterProvider, _) {
                    final waiters = waiterProvider.waiters;
                    final cartProvider = context.read<CartProvider>();

                    return GridView.builder(
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: waiters.length,
                      itemBuilder: (context, index) {
                        final waiter = waiters[index];
                        final isSelected =
                            cartProvider.activeWaiterId == waiter.id;

                        return InkWell(
                          onTap: () {
                            cartProvider.setWaiter(waiter.id, context);
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.person,
                                  color: isSelected ? Colors.blue : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    waiter.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
