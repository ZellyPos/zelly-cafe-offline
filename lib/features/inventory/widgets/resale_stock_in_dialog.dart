import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';

/// Bitta resale mahsulot uchun tezkor "Kirim" (§A).
///
/// Ombor kartasidagi "Kirim" tugmasidan ochiladi. Ko'p mahsulotli kirim uchun
/// alohida Kirim/Chiqim sahifasi bor (§4.5).
///
/// Saqlansa `true` qaytaradi.
class ResaleStockInDialog extends StatefulWidget {
  final Product product;

  const ResaleStockInDialog({super.key, required this.product});

  static Future<bool?> show(BuildContext context, Product product) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ResaleStockInDialog(product: product),
    );
  }

  @override
  State<ResaleStockInDialog> createState() => _ResaleStockInDialogState();
}

class _ResaleStockInDialogState extends State<ResaleStockInDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _supplierController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Oldingi tannarx boshlang'ich qiymat sifatida — odatda o'zgarmaydi.
    final avg = widget.product.avgCost;
    if (avg > 0) _costController.text = avg.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _supplierController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final productId = widget.product.id;
    if (productId == null) return;

    final qty = double.parse(_qtyController.text.trim().replaceAll(',', '.'));
    final cost =
        double.tryParse(_costController.text.trim().replaceAll(',', '.')) ?? 0;
    final supplier = _supplierController.text.trim();

    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().resaleStockIn(
        productId: productId,
        qty: qty,
        cost: cost,
        supplier: supplier.isEmpty ? null : supplier,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Xatolik: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kirim',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.product.name,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.hintColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Column(
                  children: [
                    _field(
                      controller: _qtyController,
                      label: 'Miqdor',
                      icon: Icons.numbers_rounded,
                      numeric: true,
                      autofocus: true,
                      validator: (v) {
                        final n = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                        if (n == null || n <= 0) return 'Musbat son kiriting';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _costController,
                      label: 'Tannarx (1 dona uchun)',
                      icon: Icons.payments_outlined,
                      numeric: true,
                    ),
                    const SizedBox(height: 14),
                    _field(
                      controller: _supplierController,
                      label: 'Kimdan olindi',
                      icon: Icons.local_shipping_outlined,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Bekor qilish'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Saqlash'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool numeric = false,
    bool autofocus = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      enabled: !_saving,
      validator: validator,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
