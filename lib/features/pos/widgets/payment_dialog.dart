import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../core/theme.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/table.dart';

class StandardPaymentDialog extends StatefulWidget {
  final int orderType;
  final TableModel? table;
  final double total;

  const StandardPaymentDialog({
    super.key,
    required this.orderType,
    this.table,
    required this.total,
  });

  @override
  State<StandardPaymentDialog> createState() => _StandardPaymentDialogState();
}

class _StandardPaymentDialogState extends State<StandardPaymentDialog> {
  String _paidAmountStr = '';
  String _paymentType = 'Cash'; // Cash or Card
  bool _shouldPrintReceipt = true;

  @override
  void initState() {
    super.initState();
    // Auto-fill with total amount by default
    _paidAmountStr = widget.total.toInt().toString();
  }

  double get _paidAmount {
    if (_paymentType == 'Card' || _paymentType == 'Terminal')
      return widget.total;
    return double.tryParse(_paidAmountStr) ?? 0.0;
  }

  double get _change =>
      _paidAmount > widget.total ? _paidAmount - widget.total : 0.0;

  void _onNumpadPressed(String value) {
    if (_paymentType == 'Card' || _paymentType == 'Terminal')
      return; // Disable editing for Non-Cash

    setState(() {
      if (value == 'C') {
        _paidAmountStr = '0';
      } else if (value == '⌫') {
        if (_paidAmountStr.length > 1) {
          _paidAmountStr = _paidAmountStr.substring(
            0,
            _paidAmountStr.length - 1,
          );
        } else {
          _paidAmountStr = '0';
        }
      } else {
        if (_paidAmountStr == '0' ||
            _paidAmountStr == widget.total.toInt().toString()) {
          _paidAmountStr = value;
        } else {
          _paidAmountStr += value;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(
          MediaQuery.of(context).size.width <= 1100 ? 16 : 24,
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(
          maxWidth: 900,
        ), // Slightly wider to fit 3 buttons
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side: Payment Info
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "To'lov",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildInfoRow(
                        "To‘lanadigan summa:",
                        PriceFormatter.format(widget.total),
                        isBold: true,
                        fontSize: 22,
                      ),
                      const Divider(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "To‘langan summa:",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PriceFormatter.format(_paidAmount),
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color:
                                    (_paymentType == 'Card' ||
                                        _paymentType == 'Terminal')
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Qaytim section: Always visible
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Qaytim:",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              PriceFormatter.format(_change),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "To'lov turi:",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildPaymentTypeBtn("Naqd", 'Cash', Icons.payments),
                          const SizedBox(width: 8),
                          _buildPaymentTypeBtn(
                            "Karta",
                            'Card',
                            Icons.credit_card,
                          ),
                          const SizedBox(width: 8),
                          _buildPaymentTypeBtn(
                            "Terminal",
                            'Terminal',
                            Icons.language,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SwitchListTile(
                        title: const Text(
                          "Chek chiqarish",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          "To'lovdan so'ng printerdan chek chiqadi",
                        ),
                        value: _shouldPrintReceipt,
                        onChanged: (val) =>
                            setState(() => _shouldPrintReceipt = val),
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width <= 1100 ? 16 : 30,
                ),
                // Right Side: Numpad
                SizedBox(
                  width: MediaQuery.of(context).size.width <= 1100 ? 280 : 320,
                  child: Opacity(
                    opacity:
                        (_paymentType == 'Card' || _paymentType == 'Terminal')
                        ? 0.5
                        : 1.0,
                    child: Column(
                      children: [
                        // Compact 3x4 Grid
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          childAspectRatio: 1.3,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildNumpadBtn('1'),
                            _buildNumpadBtn('2'),
                            _buildNumpadBtn('3'),
                            _buildNumpadBtn('4'),
                            _buildNumpadBtn('5'),
                            _buildNumpadBtn('6'),
                            _buildNumpadBtn('7'),
                            _buildNumpadBtn('8'),
                            _buildNumpadBtn('9'),
                            _buildNumpadBtn(
                              'C',
                              color: Colors.orange.shade50,
                              textColor: Colors.orange.shade800,
                            ),
                            _buildNumpadBtn('0'),
                            _buildNumpadBtn(
                              '⌫',
                              color: Colors.blueGrey.shade50,
                              textColor: Colors.blueGrey.shade800,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Quick amounts in 2 rows
                        _buildQuickAmountRow([10000, 20000, 50000]),
                        const SizedBox(height: 8),
                        _buildQuickAmountRow([100000, 200000, 500000]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Bottom Action
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 64,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Ortga",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _handlePaymentValidation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "To'lovni yakunlash",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handlePaymentValidation() {
    if (_paymentType == 'Cash' && _paidAmount < widget.total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("To‘langan summa yetarli emas."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    _handlePayment();
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? color,
    bool isBold = false,
    double fontSize = 18,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, color: Colors.black87),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeBtn(String label, String type, IconData icon) {
    final isSelected = _paymentType == type;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _paymentType = type;
            if (type == 'Card' || type == 'Terminal') {
              _paidAmountStr = widget.total.toInt().toString();
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            border: Border.all(
              color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadBtn(String val, {Color? color, Color? textColor}) {
    return Material(
      color: color ?? Colors.grey.shade100,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _onNumpadPressed(val),
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            val,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAmountRow(List<int> amounts) {
    return Row(
      children: amounts
          .map(
            (a) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: OutlinedButton(
                  onPressed:
                      (_paymentType == 'Card' || _paymentType == 'Terminal')
                      ? null
                      : () => setState(() => _paidAmountStr = a.toString()),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    PriceFormatter.format(a.toDouble()),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _handlePayment() async {
    final cartProvider = context.read<CartProvider>();
    final success = await cartProvider.checkout(
      context: context,
      paymentType: _paymentType,
      orderType: widget.orderType,
      tableId: widget.table?.id,
      locationId: widget.table?.locationId,
      paidAmount: _paymentType == 'Cash' ? _paidAmount : widget.total,
      change: _paymentType == 'Cash' ? _change : 0.0,
      shouldPrint: _shouldPrintReceipt,
    );

    if (mounted) {
      if (success) {
        if (cartProvider.lastPrintError != null) {
          // Order saved but print failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Buyurtma saqlandi, lekin chek chiqarilmadi: ${cartProvider.lastPrintError}",
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          // Success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Buyurtma muvaffaqiyatli yakunlandi va chek chiqarildi!",
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("To'lovni amalga oshirishda xatolik yuz berdi"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
