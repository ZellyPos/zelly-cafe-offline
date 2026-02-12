import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../models/product.dart';

class QuantityDialog extends StatefulWidget {
  final Product product;

  const QuantityDialog({super.key, required this.product});

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  String _quantityStr = '1';
  bool _isFirstInput = true;

  void _onNumpadPressed(String value) {
    setState(() {
      if (value == 'C') {
        _quantityStr = '0';
        _isFirstInput = true;
      } else if (value == '⌫') {
        if (_quantityStr.length > 1) {
          _quantityStr = _quantityStr.substring(0, _quantityStr.length - 1);
        } else {
          _quantityStr = '0';
          _isFirstInput = true;
        }
      } else {
        if (_isFirstInput || _quantityStr == '0') {
          _quantityStr = value;
          _isFirstInput = false;
        } else {
          if (_quantityStr.length < 5) {
            _quantityStr += value;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final int quantity = int.tryParse(_quantityStr) ?? 0;
    final double total = widget.product.price * quantity;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              PriceFormatter.format(widget.product.price),
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const Divider(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Soni:",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    _quantityStr,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Umumiy summa:",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  PriceFormatter.format(total),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Numpad Grid
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              childAspectRatio: 1.5,
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
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Bekor qilish",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: quantity > 0
                          ? () => Navigator.pop(context, quantity)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Qo'shish",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor ?? Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
