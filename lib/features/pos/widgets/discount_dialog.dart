import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/theme.dart';

/// Butun buyurtmaga chegirma berish dialogi
class OrderDiscountDialog extends StatefulWidget {
  final double foodTotal;
  final String? currentDiscountType;
  final double currentDiscountValue;
  final String? currentDiscountNote;

  const OrderDiscountDialog({
    super.key,
    required this.foodTotal,
    this.currentDiscountType,
    this.currentDiscountValue = 0,
    this.currentDiscountNote,
  });

  @override
  State<OrderDiscountDialog> createState() => _OrderDiscountDialogState();
}

class _OrderDiscountDialogState extends State<OrderDiscountDialog> {
  late String _type; // 'percent' | 'fixed'
  late TextEditingController _valueCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _type = widget.currentDiscountType ?? 'percent';
    _valueCtrl = TextEditingController(
      text: widget.currentDiscountValue > 0
          ? widget.currentDiscountValue.toStringAsFixed(
              widget.currentDiscountType == 'percent' ? 0 : 0)
          : '',
    );
    _noteCtrl = TextEditingController(text: widget.currentDiscountNote ?? '');
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_valueCtrl.text) ?? 0;

  double get _discountAmount {
    if (_value <= 0) return 0;
    if (_type == 'percent') {
      return (widget.foodTotal * _value / 100).clamp(0, widget.foodTotal);
    }
    return _value.clamp(0, widget.foodTotal);
  }

  String? _validate() {
    if (_value <= 0) return "Chegirma miqdorini kiriting";
    if (_type == 'percent' && _value > 100) {
      return "Foiz 100% dan oshib ketdi";
    }
    if (_type == 'fixed' && _value > widget.foodTotal) {
      return "Chegirma jami summadan oshib ketdi";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _value > 0 ? _validate() : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sarlavha
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_offer_rounded,
                        color: Colors.orange, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    "Buyurtmaga chegirma",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Chegirma turi
              Row(
                children: [
                  Expanded(
                    child: _typeBtn(
                      label: "Foiz (%)",
                      icon: Icons.percent_rounded,
                      selected: _type == 'percent',
                      onTap: () => setState(() => _type = 'percent'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _typeBtn(
                      label: "Summa (so'm)",
                      icon: Icons.attach_money_rounded,
                      selected: _type == 'fixed',
                      onTap: () => setState(() => _type = 'fixed'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Miqdor kiritish
              TextField(
                controller: _valueCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _type == 'percent' ? "Foiz (%)" : "Summa (so'm)",
                  hintText: "0",
                  suffixText: _type == 'percent' ? "%" : "so'm",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: error,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 10),

              // Preview
              if (_value > 0 && error == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Chegirma:",
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange)),
                      Text(
                        "- ${PriceFormatter.format(_discountAmount)} so'm",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),

              // Izoh
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: "Chegirma sababi (ixtiyoriy)",
                  hintText: "Masalan: VIP mijoz",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Tugmalar
              Row(
                children: [
                  // Chegirmani olib tashlash (faqat mavjud bo'lsa)
                  if (widget.currentDiscountType != null)
                    TextButton.icon(
                      onPressed: () =>
                          Navigator.pop(context, _DiscountResult.remove()),
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.red, size: 18),
                      label: const Text("Olib tashlash",
                          style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Bekor"),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _validate() == null && _value > 0
                        ? () => Navigator.pop(
                            context,
                            _DiscountResult.apply(
                              type: _type,
                              value: _value,
                              note: _noteCtrl.text.trim().isEmpty
                                  ? null
                                  : _noteCtrl.text.trim(),
                            ))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Qo'llash",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor
                : Colors.grey.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppTheme.primaryColor : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? AppTheme.primaryColor : Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mahsulot qatoriga chegirma berish dialogi
class ItemDiscountDialog extends StatefulWidget {
  final String productName;
  final double itemTotal;
  final double currentDiscount;

  const ItemDiscountDialog({
    super.key,
    required this.productName,
    required this.itemTotal,
    this.currentDiscount = 0,
  });

  @override
  State<ItemDiscountDialog> createState() => _ItemDiscountDialogState();
}

class _ItemDiscountDialogState extends State<ItemDiscountDialog> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.currentDiscount > 0
          ? widget.currentDiscount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_ctrl.text) ?? 0;

  String? _validate() {
    if (_amount <= 0) return "Chegirma miqdorini kiriting";
    if (_amount > widget.itemTotal) {
      return "Chegirma mahsulot summasidan oshib ketdi";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final error = _amount > 0 ? _validate() : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sarlavha
              Text(
                widget.productName,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                "Jami: ${PriceFormatter.format(widget.itemTotal)} so'm",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // Summa kiritish
              TextField(
                controller: _ctrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: "Chegirma summasi (so'm)",
                  hintText: "0",
                  suffixText: "so'm",
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  errorText: error,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 10),

              // Preview
              if (_amount > 0 && error == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.red.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Net summa:",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      Text(
                        "${PriceFormatter.format(widget.itemTotal - _amount)} so'm",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Tugmalar
              Row(
                children: [
                  if (widget.currentDiscount > 0)
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, _ItemDiscountResult.remove()),
                      child: const Text("Olib tashlash",
                          style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("Bekor"),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _validate() == null && _amount > 0
                        ? () => Navigator.pop(
                            context, _ItemDiscountResult.apply(_amount))
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text("Qo'shish",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Return value types ──────────────────────────────────────────────────────

class _DiscountResult {
  final bool remove;
  final String? type;
  final double? value;
  final String? note;

  const _DiscountResult._({
    required this.remove,
    this.type,
    this.value,
    this.note,
  });

  factory _DiscountResult.remove() =>
      const _DiscountResult._(remove: true);

  factory _DiscountResult.apply({
    required String type,
    required double value,
    String? note,
  }) =>
      _DiscountResult._(remove: false, type: type, value: value, note: note);
}

class _ItemDiscountResult {
  final bool remove;
  final double? amount;

  const _ItemDiscountResult._({required this.remove, this.amount});

  factory _ItemDiscountResult.remove() =>
      const _ItemDiscountResult._(remove: true);

  factory _ItemDiscountResult.apply(double amount) =>
      _ItemDiscountResult._(remove: false, amount: amount);
}

// ── Public helpers (cart_panel da ishlatiladi) ──────────────────────────────

/// Order chegirma dialogi chiqarish va natijani CartProvider ga uzatish
Future<void> showOrderDiscountDialog(
  BuildContext context, {
  required double foodTotal,
  required String? currentType,
  required double currentValue,
  required String? currentNote,
  required void Function(String type, double value, String? note) onApply,
  required void Function() onRemove,
}) async {
  final result = await showDialog<_DiscountResult>(
    context: context,
    builder: (_) => OrderDiscountDialog(
      foodTotal: foodTotal,
      currentDiscountType: currentType,
      currentDiscountValue: currentValue,
      currentDiscountNote: currentNote,
    ),
  );
  if (result == null) return;
  if (result.remove) {
    onRemove();
  } else {
    onApply(result.type!, result.value!, result.note);
  }
}

/// Item chegirma dialogi chiqarish va natijani qaytarish
Future<void> showItemDiscountDialog(
  BuildContext context, {
  required String productName,
  required double itemTotal,
  required double currentDiscount,
  required void Function(double amount) onApply,
  required void Function() onRemove,
}) async {
  final result = await showDialog<_ItemDiscountResult>(
    context: context,
    builder: (_) => ItemDiscountDialog(
      productName: productName,
      itemTotal: itemTotal,
      currentDiscount: currentDiscount,
    ),
  );
  if (result == null) return;
  if (result.remove) {
    onRemove();
  } else {
    onApply(result.amount!);
  }
}
