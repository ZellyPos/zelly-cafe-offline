import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/shift_provider.dart';
import '../../../providers/connectivity_provider.dart';
import '../../../core/utils/price_formatter.dart';

class CashMovementDialog extends StatefulWidget {
  final String initialType; // 'IN' or 'OUT'
  const CashMovementDialog({super.key, this.initialType = 'IN'});

  @override
  State<CashMovementDialog> createState() => _CashMovementDialogState();
}

class _CashMovementDialogState extends State<CashMovementDialog> {
  late String _type;
  String _input = '0';
  String? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _isLoading = false;

  static const _inReasons = [
    'Inkassatsiya',
    'Qarz qaytarish',
    'Avans',
    'Boshqa kirim',
  ];
  static const _outReasons = [
    'Xarajat',
    'Inkassatsiya chiqimi',
    'Qarz berish',
    'Maosh',
    'Boshqa chiqim',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<String> get _reasons => _type == 'IN' ? _inReasons : _outReasons;
  double get _amount => double.tryParse(_input) ?? 0;

  void _onKey(String key) {
    setState(() {
      if (key == '⌫') {
        _input = _input.length <= 1 ? '0' : _input.substring(0, _input.length - 1);
      } else if (key == '000') {
        if (_input != '0') _input += '000';
      } else {
        if (_input == '0') {
          _input = key;
        } else if (_input.length < 10) {
          _input += key;
        }
      }
    });
  }

  Future<void> _confirm() async {
    if (_amount <= 0) {
      _showErr('Summa 0 dan katta bo\'lishi kerak');
      return;
    }
    if (_selectedReason == null) {
      _showErr('Sabab tanlang');
      return;
    }

    final connectivity = context.read<ConnectivityProvider>();
    final shiftProvider = context.read<ShiftProvider>();
    final rawId = connectivity.currentUser?['id'];
    final int userId = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    setState(() => _isLoading = true);
    try {
      await shiftProvider.addMovement(
        amount: _amount,
        type: _type,
        reason: _selectedReason!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        userId: userId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) _showErr(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = _type == 'IN';
    final accent = isIn ? const Color(0xFF10B981) : Colors.red;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(
                    isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isIn ? 'Kassa kirimi (IN)' : 'Kassa chiqimi (OUT)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Tur tanlash ──────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _typeBtn(
                          label: 'KIRIM',
                          icon: Icons.arrow_downward_rounded,
                          color: const Color(0xFF10B981),
                          selected: _type == 'IN',
                          onTap: () => setState(() {
                            _type = 'IN';
                            _selectedReason = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _typeBtn(
                          label: 'CHIQIM',
                          icon: Icons.arrow_upward_rounded,
                          color: Colors.red,
                          selected: _type == 'OUT',
                          onTap: () => setState(() {
                            _type = 'OUT';
                            _selectedReason = null;
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Summa ────────────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summa',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          PriceFormatter.format(_amount),
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: -1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Numpad ───────────────────────────────────────────────
                  _buildNumpad(theme),
                  const SizedBox(height: 16),

                  // ── Sabab tanlash ────────────────────────────────────────
                  Text(
                    'Sabab',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reasons.map((r) {
                      final sel = _selectedReason == r;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedReason = r),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: sel
                                ? accent.withValues(alpha: 0.12)
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel ? accent : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            r,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel
                                  ? accent
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // ── Izoh ─────────────────────────────────────────────────
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: 'Izoh (ixtiyoriy)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Tasdiqlash ───────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _confirm,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              isIn
                                  ? Icons.arrow_downward_rounded
                                  : Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                      label: Text(
                        isIn ? 'KIRIM SAQLASH' : 'CHIQIM SAQLASH',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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

  Widget _typeBtn({
    required String label,
    required IconData icon,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad(ThemeData theme) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['000', '0', '⌫'],
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: keys.expand((r) => r).map((key) {
        final isDel = key == '⌫';
        return InkWell(
          onTap: () => _onKey(key),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              color: isDel
                  ? Colors.red.withValues(alpha: 0.07)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: isDel
                ? const Icon(Icons.backspace_rounded, size: 18, color: Colors.red)
                : Text(
                    key,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        );
      }).toList(),
    );
  }
}
