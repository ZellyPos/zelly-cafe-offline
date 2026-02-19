import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../core/theme.dart';
import '../../../core/app_strings.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/table.dart';
import 'quantity_dialog.dart';
import '../../license/widgets/license_gate.dart';

class CartPanelWidget extends StatelessWidget {
  final int orderType;
  final TableModel? table;
  final bool isCompact;
  final VoidCallback onShowPaymentDialog;
  final VoidCallback onPrintReceipt;
  final VoidCallback onCancelOrder;

  const CartPanelWidget({
    super.key,
    required this.orderType,
    required this.table,
    required this.isCompact,
    required this.onShowPaymentDialog,
    required this.onPrintReceipt,
    required this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    // Senior approach: Use Selector to only rebuild if cart items or totals change
    return Container(
      width: isCompact ? 340 : 400,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildItemsList(context),
          _buildBottomPanel(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Selector<CartProvider, int>(
      selector: (_, provider) => provider.items.length,
      builder: (context, itemCount, _) {
        final cartProvider = context.read<CartProvider>();
        return Container(
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
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => cartProvider.clearCart(
                  context.read<ConnectivityProvider>(),
                  context,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemsList(BuildContext context) {
    return Expanded(
      child: Consumer<CartProvider>(
        builder: (context, cartProvider, _) {
          final items = cartProvider.items.values.toList();
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key('cart_${item.product.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  cartProvider.removeItem(
                    item.product.id!,
                    context.read<ConnectivityProvider>(),
                    context,
                  );
                },
                child: _buildCartItem(context, item, cartProvider),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCartItem(
    BuildContext context,
    dynamic item,
    CartProvider cartProvider,
  ) {
    return InkWell(
      onTap: () async {
        final result = await showDialog<int>(
          context: context,
          builder: (context) => QuantityDialog(product: item.product),
        );
        if (result != null && result >= 0) {
          cartProvider.updateQuantity(
            item.product.id!,
            result,
            context.read<ConnectivityProvider>(),
            context,
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 6 : 16,
          vertical: isCompact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
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
            Flexible(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                        _buildQtyBtn(
                          Icons.remove,
                          () => cartProvider.updateQuantity(
                            item.product.id!,
                            item.quantity - 1,
                            context.read<ConnectivityProvider>(),
                            context,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 12 : 14,
                            ),
                          ),
                        ),
                        _buildQtyBtn(
                          Icons.add,
                          () => cartProvider.updateQuantity(
                            item.product.id!,
                            item.quantity + 1,
                            context.read<ConnectivityProvider>(),
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: isCompact ? 4 : 8),
                  Text(
                    PriceFormatter.format(item.total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 13 : 14,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: isCompact ? 16 : 20, color: Colors.blue),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        return Container(
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
              _buildTotalsBreakdown(context, cartProvider),
              const SizedBox(height: 20),
              _buildActionButtons(context, cartProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTotalsBreakdown(
    BuildContext context,
    CartProvider cartProvider,
  ) {
    return Column(
      children: [
        _buildRow("Taomlar:", cartProvider.totalAmount),
        if (orderType == 0 && table != null)
          FutureBuilder<double>(
            future: cartProvider.calculateRoomChargeForUI(context),
            builder: (context, snapshot) {
              final roomCharge = snapshot.data ?? 0;
              final serviceFee = cartProvider.calculateWaiterServiceFee(
                context,
              );
              final grandTotal =
                  cartProvider.totalAmount + roomCharge + serviceFee;
              return Column(
                children: [
                  if (roomCharge > 0) _buildRow("Xona/Stol:", roomCharge),
                  if (serviceFee > 0)
                    _buildRow("Ofitsiant xizmati:", serviceFee),
                  const Divider(height: 16),
                  _buildRow("JAMI:", grandTotal, isMain: true),
                ],
              );
            },
          )
        else
          Builder(
            builder: (context) {
              final serviceFee = cartProvider.calculateWaiterServiceFee(
                context,
              );
              final grandTotal = cartProvider.totalAmount + serviceFee;
              return Column(
                children: [
                  if (serviceFee > 0)
                    _buildRow("Ofitsiant xizmati:", serviceFee),
                  const Divider(height: 16),
                  _buildRow("JAMI:", grandTotal, isMain: true),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildRow(String label, double value, {bool isMain = false}) {
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

  Widget _buildActionButtons(BuildContext context, CartProvider cartProvider) {
    final connectivity = context.read<ConnectivityProvider>();
    final bool isEmpty = cartProvider.items.isEmpty;
    final bool isWaiter =
        (connectivity.currentUser?['role'] ?? 'admin') == 'waiter';

    return Column(
      children: [
        if (isEmpty && cartProvider.activeOrderId != null && !isWaiter)
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              onPressed: onCancelOrder,
              icon: const Icon(Icons.cancel_outlined),
              label: const Text(
                'BUYURTMANI BEKOR QILISH',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        if (!isEmpty)
          Row(
            children: [
              SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: onPrintReceipt,
                  icon: const Icon(Icons.print, size: 20),
                  label: const Text(''),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 60,
                  child: LicenseGate(
                    child: ElevatedButton(
                      onPressed: onShowPaymentDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isWaiter ? 'SAQLASH' : AppStrings.checkout,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
