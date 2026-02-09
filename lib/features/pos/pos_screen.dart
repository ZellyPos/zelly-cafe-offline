import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/theme.dart';
import '../../models/product.dart';
import '../../core/app_strings.dart';
import '../../core/utils/price_formatter.dart';

import '../../providers/waiter_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/table.dart';
import 'widgets/payment_dialog.dart';

class PosScreen extends StatefulWidget {
  final int orderType; // 0 = Dine-in, 1 = Saboy
  final TableModel? table;

  const PosScreen({super.key, this.orderType = 0, this.table});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  String selectedCategory = AppStrings.all;
  Timer? _refreshTimer;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivity = context.read<ConnectivityProvider>();
      final cartProvider = context.read<CartProvider>();

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
    super.dispose();
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

    var filteredProducts = selectedCategory == AppStrings.all
        ? allProducts
        : allProducts.where((p) => p.category == selectedCategory).toList();

    // Sort by sales count in "Barchasi" (All) category
    if (selectedCategory == AppStrings.all) {
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
                        ],
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
                      ],
                    ),
                  ),
                // Category Bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            color: isSelected ? Colors.white : Colors.black,
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
                          }
                        },
                        selectedColor: AppTheme.primaryColor,
                        padding: isCompact
                            ? const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              )
                            : null,
                      );
                    },
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
                            },
                            itemBuilder: (context, catIndex) {
                              final currentCat = categories[catIndex];
                              final List<Product> pageProducts =
                                  currentCat == AppStrings.all
                                  ? allProducts
                                  : allProducts
                                        .where((p) => p.category == currentCat)
                                        .toList();

                              // Sort by sales count in "Barchasi" (All) category
                              if (currentCat == AppStrings.all) {
                                pageProducts.sort((a, b) {
                                  final aSales = productProvider
                                      .getProductSalesCount(a.id ?? 0);
                                  final bSales = productProvider
                                      .getProductSalesCount(b.id ?? 0);
                                  return bSales.compareTo(aSales);
                                });
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
                                      childAspectRatio: isCompact ? 0.72 : 0.8,
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
                      return Container(
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
    return InkWell(
      onTap: () => context.read<CartProvider>().addItem(
        product,
        context.read<ConnectivityProvider>(),
        context,
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: Colors.grey.shade100,
                child:
                    product.imagePath != null &&
                        File(product.imagePath!).existsSync()
                    ? Image.file(
                        File(product.imagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Center(
                        child: Icon(
                          Icons.fastfood,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
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
                      fontSize: isCompact ? 16 : 18,
                      height: 1.1,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isCompact ? 2 : 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        PriceFormatter.format(product.price),
                        style: const TextStyle(
                          color: AppTheme.secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
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
