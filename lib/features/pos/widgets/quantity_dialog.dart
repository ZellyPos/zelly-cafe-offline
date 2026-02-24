import 'package:flutter/material.dart';
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
  bool _hasDecimal = false;

  void _onNumpadPressed(String value) {
    setState(() {
      if (value == 'C') {
        _quantityStr = '0';
        _isFirstInput = true;
        _hasDecimal = false;
      } else if (value == '⌫') {
        if (_quantityStr.length > 1) {
          if (_quantityStr.endsWith('.')) {
            _hasDecimal = false;
          }
          _quantityStr = _quantityStr.substring(0, _quantityStr.length - 1);
        } else {
          _quantityStr = '0';
          _isFirstInput = true;
          _hasDecimal = false;
        }
      } else if (value == '.') {
        if (!_hasDecimal) {
          if (_isFirstInput) {
            _quantityStr = '0.';
            _isFirstInput = false;
          } else {
            _quantityStr += '.';
          }
          _hasDecimal = true;
        }
      } else {
        if (_isFirstInput || _quantityStr == '0') {
          _quantityStr = value;
          _isFirstInput = false;
        } else {
          if (_quantityStr.length < 7) {
            _quantityStr += value;
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double quantity = double.tryParse(_quantityStr) ?? 0;
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
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              PriceFormatter.format(widget.product.price),
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const Divider(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Soni:",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    _quantityStr,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Umumiy summa:",
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  PriceFormatter.format(total),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            if (widget.product.quantity != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Mavjud qoldiq:",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    widget.product.unit == 'kg'
                        ? "${widget.product.quantity!.toStringAsFixed(2)} kg"
                        : "${widget.product.quantity!.toStringAsFixed(0)} ta",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: quantity > widget.product.quantity!
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (quantity > widget.product.quantity!)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    "Omborda mahsulot yetarli emas!",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
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
                  '⌫',
                  color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                  textColor: Theme.of(context).colorScheme.error,
                ),

                // _buildNumpadBtn(
                //   'C',
                //   color: Theme.of(
                //     context,
                //   ).colorScheme.secondary.withOpacity(0.1),
                //   textColor: Theme.of(context).colorScheme.secondary,
                // ),
                _buildNumpadBtn('0'),
                _buildNumpadBtn('.'),
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
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        "Bekor qilish",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.error,
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
                      onPressed:
                          (quantity > 0 &&
                              (widget.product.quantity == null ||
                                  quantity <= widget.product.quantity!))
                          ? () => Navigator.pop(context, quantity)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
      color: color ?? Theme.of(context).colorScheme.surface,
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
              color: textColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
