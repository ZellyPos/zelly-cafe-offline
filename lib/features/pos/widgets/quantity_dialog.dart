import 'package:flutter/material.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/app_strings.dart';
import '../../../models/product.dart';

class QuantityDialog extends StatefulWidget {
  final Product product;

  const QuantityDialog({super.key, required this.product});

  @override
  State<QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<QuantityDialog> {
  String _quantityStr = '1';
  String _priceStr = '0';
  bool _isFirstInput = true;
  bool _hasDecimal = false;
  bool _isPriceMode = false;

  @override
  void initState() {
    super.initState();
    _priceStr = widget.product.price.toStringAsFixed(0);
  }

  void _onNumpadPressed(String value) {
    setState(() {
      if (value == 'C') {
        if (_isPriceMode) {
          _priceStr = '0';
        } else {
          _quantityStr = '0';
        }
        _isFirstInput = true;
        _hasDecimal = false;
      } else if (value == '⌫') {
        String current = _isPriceMode ? _priceStr : _quantityStr;
        if (current.length > 1) {
          if (current.endsWith('.')) {
            _hasDecimal = false;
          }
          current = current.substring(0, current.length - 1);
        } else {
          current = '0';
          _isFirstInput = true;
          _hasDecimal = false;
        }

        if (_isPriceMode) {
          _priceStr = current;
        } else {
          _quantityStr = current;
        }
      } else if (value == '.') {
        if (_isPriceMode) {
          return; // Price usually doesn't have decimals in this app's context, but we could allow it.
        }
        // For simplicity and common POS practice, let's say prices are whole numbers or handled differently.
        // Actually, let's allow it if needed, but the current PriceFormatter handles doubles.

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
        String current = _isPriceMode ? _priceStr : _quantityStr;
        if (_isFirstInput || current == '0') {
          current = value;
          _isFirstInput = false;
          _hasDecimal = false;
        } else {
          if (current.length < 9) {
            current += value;
          }
        }

        if (_isPriceMode) {
          _priceStr = current;
        } else {
          _quantityStr = current;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double quantity = double.tryParse(_quantityStr) ?? 0;
    final double price = double.tryParse(_priceStr) ?? 0;
    final double total = price * quantity;

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmall = screenHeight < 780;
    final spacing = isSmall ? 12.0 : 24.0;
    final btnHeight = isSmall ? 48.0 : 60.0;
    final numpadRatio = isSmall ? 2.2 : 1.6;
    final displayVertPad = isSmall ? 12.0 : 24.0;
    final numFontSize = isSmall ? 28.0 : 36.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: screenHeight * 0.92,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.product.name,
                style: TextStyle(
                  fontSize: isSmall ? 18 : 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: spacing),

              // Mode Toggle
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _buildModeTab(
                      label: "Soni",
                      icon: Icons.exposure_rounded,
                      active: !_isPriceMode,
                      isSmall: isSmall,
                      onTap: () => setState(() {
                        _isPriceMode = false;
                        _isFirstInput = true;
                        _hasDecimal = _quantityStr.contains('.');
                      }),
                    ),
                    _buildModeTab(
                      label: "Narxi",
                      icon: Icons.payments_rounded,
                      active: _isPriceMode,
                      isSmall: isSmall,
                      onTap: () => setState(() {
                        _isPriceMode = true;
                        _isFirstInput = true;
                        _hasDecimal = false;
                      }),
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing),

              // Display
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: displayVertPad,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _isPriceMode
                      ? const Color(0xFFEFF6FF)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isPriceMode
                        ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                        : const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isPriceMode
                              ? "Donasi (so'm):"
                              : "Soni (${AppStrings.getUnitLabel(widget.product.unit)}):",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          _isPriceMode
                              ? PriceFormatter.format(price)
                              : _quantityStr,
                          style: TextStyle(
                            fontSize: numFontSize,
                            fontWeight: FontWeight.w900,
                            color: _isPriceMode
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
                      child: const Divider(),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Jami summa:",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          PriceFormatter.format(total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: spacing),

              // Numpad Grid
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: numpadRatio,
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
                    color: const Color(0xFFFEF2F2),
                    textColor: const Color(0xFFEF4444),
                  ),
                  _buildNumpadBtn('0'),
                  _buildNumpadBtn(
                    '.',
                    color: _isPriceMode
                        ? const Color(0xFFF1F5F9).withValues(alpha: 0.5)
                        : null,
                    textColor: _isPriceMode ? const Color(0xFF94A3B8) : null,
                  ),
                ],
              ),

              SizedBox(height: isSmall ? 16 : 32),

              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: btnHeight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          AppStrings.cancel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: btnHeight,
                      child: ElevatedButton(
                        onPressed: (quantity > 0)
                            ? () => Navigator.pop(context, {
                                'quantity': quantity,
                                'price': price,
                              })
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "TASDIQLASH",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
    bool isSmall = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: isSmall ? 8 : 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: active
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumpadBtn(String val, {Color? color, Color? textColor}) {
    final disabled = val == '.' && _isPriceMode;
    return Material(
      color: color ?? const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: disabled ? null : () => _onNumpadPressed(val),
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Text(
            val,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: disabled
                  ? const Color(0xFFCBD5E1)
                  : (textColor ?? const Color(0xFF1E293B)),
            ),
          ),
        ),
      ),
    );
  }
}
