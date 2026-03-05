import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/connectivity_provider.dart';
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
    final theme = Theme.of(context);
    return Container(
      width: isCompact ? 340 : 400,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: const Border(left: BorderSide(color: Color(0xFFF1F5F9))),
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
    final theme = Theme.of(context);
    return Selector<CartProvider, int>(
      selector: (_, provider) => provider.items.length,
      builder: (context, itemCount, _) {
        final cartProvider = context.read<CartProvider>();
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: isCompact ? 16 : 24,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.currentOrder,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    "$itemCount ta mahsulot",
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (itemCount > 0)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
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
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: const Color(0xFFF1F5F9),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Savat bo'sh",
                    style: TextStyle(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Dismissible(
                key: Key('cart_${item.product.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_rounded, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  bool hasPerm = await cartProvider.checkPermission(
                    context,
                    'delete_item',
                  );
                  if (!hasPerm) return false;

                  if (item.printedQuantity > 0) {
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
    final theme = Theme.of(context);
    final isCancelled = item.quantity == 0;
    return InkWell(
      onTap: () async {
        if (!await cartProvider.checkPermission(context, 'perm_edit_price')) {
          return;
        }
        final result = await showDialog(
          context: context,
          builder: (context) => QuantityDialog(product: item.product),
        );
        if (result != null && result is Map) {
          final double newQty = result['quantity'];
          final double newPrice = result['price'];

          if (newQty < item.quantity) {
            final permission = newQty == 0 ? 'perm_delete_item' : 'reduce_item';
            if (!await cartProvider.checkPermission(context, permission)) {
              return;
            }
          }

          cartProvider.updateItem(
            item.product.id!,
            quantity: newQty,
            price: newPrice,
            connectivity: context.read<ConnectivityProvider>(),
            context: context,
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCancelled ? const Color(0xFFFEF2F2).withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCancelled
                ? const Color(0xFFFCA5A5).withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isCancelled
                          ? const Color(0xFFEF4444)
                          : theme.colorScheme.onSurface,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${PriceFormatter.format(item.product.price)} so'm",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildQtyBtn(context, Icons.remove_rounded, () async {
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _buildQtyBtn(
                      context,
                      Icons.add_rounded,
                      isCancelled
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
                const SizedBox(height: 4),
                Text(
                  PriceFormatter.format(item.total),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isCancelled
                        ? const Color(0xFFEF4444)
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF475569),
        ),
      ),
    );
  }

  Widget _buildBottomPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<CartProvider>(
      builder: (context, cartProvider, _) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildTotalsBreakdown(context, cartProvider),
              const SizedBox(height: 24),
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
        _buildRow(context, "Taomlar jami", cartProvider.totalAmount),
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
                  if (roomCharge > 0)
                    _buildRow(context, "Xona / Stol", roomCharge),
                  if (serviceFee > 0)
                    _buildRow(context, "Xizmat haqi", serviceFee),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFFF1F5F9)),
                  ),
                  _buildRow(
                    context,
                    "TO'LANADIGAN SUMMA:",
                    grandTotal,
                    isMain: true,
                  ),
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
                    _buildRow(context, "Xizmat haqi", serviceFee),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFFF1F5F9)),
                  ),
                  _buildRow(
                    context,
                    "TO'LANADIGAN SUMMA:",
                    grandTotal,
                    isMain: true,
                  ),
                ],
              );
            },
          ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label,
    double value, {
    bool isMain = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMain ? 4 : 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMain ? 15 : 13,
              fontWeight: isMain ? FontWeight.w800 : FontWeight.w600,
              color: isMain
                  ? theme.colorScheme.onSurface
                  : const Color(0xFF94A3B8),
              letterSpacing: isMain ? -0.2 : 0,
            ),
          ),
          Text(
            PriceFormatter.format(value),
            style: TextStyle(
              fontSize: isMain ? 22 : 14,
              fontWeight: FontWeight.w900,
              color: isMain
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, CartProvider cartProvider) {
    final connectivity = context.read<ConnectivityProvider>();
    final bool isEmpty = cartProvider.items.isEmpty;
    final String role = connectivity.currentUser?['role'] ?? 'admin';
    final bool isWaiter = role == 'waiter';

    return Column(
      children: [
        if (isEmpty && cartProvider.activeOrderId != null && !isWaiter)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: onCancelOrder,
              icon: const Icon(Icons.cancel_outlined, size: 20),
              label: const Text(
                'BUYURTMANI BEKOR QILISH',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFEF4444),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        if (!isEmpty)
          (cartProvider.hasUnconfirmedChanges &&
                  cartProvider.hasPermission(context, 'perm_confirm_order'))
              ? SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (await cartProvider.checkPermission(
                        context,
                        'perm_confirm_order',
                      )) {
                        cartProvider.confirmTableOrder(context, connectivity);
                      }
                    },
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 20,
                    ),
                    label: const Text(
                      'BUYURTMANI TASDIQLASH',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    SizedBox(
                      height: 56,
                      width: 64,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (await cartProvider.checkPermission(
                            context,
                            'print_receipt',
                          )) {
                            onPrintReceipt();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF1F5F9),
                          foregroundColor: const Color(0xFF475569),
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Icon(Icons.print_outlined, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: LicenseGate(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (await cartProvider.checkPermission(
                                context,
                                'perm_checkout',
                              )) {
                                onShowPaymentDialog();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              (isWaiter ? 'SAQLASH' : AppStrings.checkout)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
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
