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
        color: Theme.of(context).colorScheme.surface,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
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
          color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.currentOrder,
                style: TextStyle(
                  fontSize: isCompact ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () async {
                  if (await cartProvider.checkPermission(
                    context,
                    'delete_item',
                  )) {
                    cartProvider.clearCart(
                      context.read<ConnectivityProvider>(),
                      context,
                    );
                  }
                },
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
                  color: Theme.of(context).colorScheme.error,
                  child: Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  bool hasPerm = await cartProvider.checkPermission(
                    context,
                    'delete_item',
                  );
                  if (!hasPerm) return false;

                  if (item.printedQuantity > 0) {
                    // If it has been printed, it will only be marked as cancelled (qty = 0)
                    // and must remain in the list. So we refuse the dismiss animation
                    // and update the state manually.
                    cartProvider.removeItem(
                      item.product.id!,
                      context.read<ConnectivityProvider>(),
                      context,
                    );
                    return false;
                  }

                  return true;
                },
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
        final result = await showDialog<double>(
          context: context,
          builder: (context) => QuantityDialog(product: item.product),
        );
        if (result != null && result >= 0) {
          final oldQty = item.quantity;
          if (result < oldQty) {
            final permission = result == 0 ? 'delete_item' : 'reduce_item';
            if (!await cartProvider.checkPermission(context, permission)) {
              return;
            }
          }

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
                      color: item.quantity == 0
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurface,
                      decoration: item.quantity == 0
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.quantity == 0)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'BEKOR QILINDI',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    PriceFormatter.format(item.product.price),
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
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
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQtyBtn(context, Icons.remove, () async {
                          final currentQty = item.quantity;
                          final permission = currentQty <= 1
                              ? 'delete_item'
                              : 'reduce_item';

                          if (!await cartProvider.checkPermission(
                            context,
                            permission,
                          )) {
                            return;
                          }

                          cartProvider.updateQuantity(
                            item.product.id!,
                            item.quantity - 1,
                            context.read<ConnectivityProvider>(),
                            context,
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            '${item.quantity} ${AppStrings.getUnitLabel(item.product.unit)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isCompact ? 11 : 13,
                            ),
                          ),
                        ),
                        _buildQtyBtn(
                          context,
                          Icons.add,
                          item.quantity == 0
                              ? null
                              : () => cartProvider.updateQuantity(
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
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _buildQtyBtn(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: isCompact ? 16 : 20,
          color: onTap == null
              ? Colors.grey
              : Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.05),
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
          cartProvider.hasUnconfirmedChanges
              ? SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        cartProvider.confirmTableOrder(context, connectivity),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text(
                      'TASDIQLASH',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 60,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (await cartProvider.checkPermission(
                            context,
                            'print_receipt',
                          )) {
                            onPrintReceipt();
                          }
                        },
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
