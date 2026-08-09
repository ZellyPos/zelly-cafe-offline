import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/cart_provider.dart';
import '../../../core/theme.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/repositories/order_repository.dart';
import '../../../models/table.dart';

class _PaymentEntry {
  final String type;
  final double amount;
  const _PaymentEntry({required this.type, required this.amount});
}

class _TypeCfg {
  final String type;
  final String label;
  final IconData icon;
  const _TypeCfg(this.type, this.label, this.icon);
}

const _kTypes = [
  _TypeCfg('Cash',     'Naqd',      Icons.payments_rounded),
  _TypeCfg('Card',     'Karta',     Icons.credit_card_rounded),
  _TypeCfg('Terminal', 'Terminal',  Icons.language_rounded),
  _TypeCfg('Bonus',    'Bonus',     Icons.star_rounded),
  _TypeCfg('Debt',     'Qarz',      Icons.book_rounded),
  _TypeCfg('Transfer', "O'tkazma",  Icons.phone_android_rounded),
];

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

class _StandardPaymentDialogState extends State<StandardPaymentDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isProcessing = false;
  bool _shouldPrintReceipt = true;
  final TextEditingController _noteController = TextEditingController();

  static const _printPrefKey = 'payment_should_print_receipt';

  // Oddiy to'lov
  String _simpleAmountStr = '';
  String _simpleType = 'Cash';

  // To'lovni bo'lish
  final List<_PaymentEntry> _splitPayments = [];
  String _splitType = 'Cash';
  String _splitAmountStr = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _simpleAmountStr = widget.total.toInt().toString();
    _loadPrintPref();
  }

  Future<void> _loadPrintPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _shouldPrintReceipt = prefs.getBool(_printPrefKey) ?? true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ── Oddiy to'lov getters ──────────────────────────────────────────────────
  double get _simpleAmount => double.tryParse(_simpleAmountStr) ?? 0.0;
  double get _simpleChange => _simpleAmount > widget.total ? _simpleAmount - widget.total : 0.0;
  bool get _simpleCanFinish => _simpleAmount >= widget.total && !_isProcessing;

  // ── Bo'lish getters ───────────────────────────────────────────────────────
  double get _splitTotalPaid => _splitPayments.fold(0.0, (s, p) => s + p.amount);
  double get _splitRemaining => widget.total - _splitTotalPaid;
  bool get _splitCanFinish =>
      _splitRemaining.abs() < 0.01 && _splitPayments.isNotEmpty && !_isProcessing;
  double get _splitCurrentAmount => double.tryParse(_splitAmountStr) ?? 0.0;

  // ── Numpad handlers ───────────────────────────────────────────────────────
  void _onSimpleNumpad(String val) => setState(() => _applyNumpad(val, _simpleAmountStr, (v) => _simpleAmountStr = v));
  void _onSplitNumpad(String val) => setState(() => _applyNumpad(val, _splitAmountStr, (v) => _splitAmountStr = v));

  void _applyNumpad(String val, String current, void Function(String) set) {
    if (val == 'C') {
      set('');
    } else if (val == '⌫') {
      if (current.isNotEmpty) set(current.substring(0, current.length - 1));
    } else {
      set(current == '0' ? val : current + val);
    }
  }

  void _addSplitPayment() {
    if (_splitCurrentAmount <= 0 || _splitCurrentAmount > _splitRemaining + 0.01) return;
    setState(() {
      _splitPayments.add(_PaymentEntry(type: _splitType, amount: _splitCurrentAmount));
      _splitAmountStr = '';
    });
  }

  void _removeSplitPayment(int index) => setState(() => _splitPayments.removeAt(index));

  // ── Checkout ──────────────────────────────────────────────────────────────
  Future<void> _handleSimplePayment() async {
    if (!_simpleCanFinish) return;
    setState(() => _isProcessing = true);
    await _doCheckout(
      payments: [_PaymentEntry(type: _simpleType, amount: _simpleAmount)],
      change: _simpleChange,
    );
  }

  Future<void> _handleSplitPayment() async {
    if (!_splitCanFinish) return;
    setState(() => _isProcessing = true);
    await _doCheckout(payments: List.from(_splitPayments), change: 0);
  }

  Future<void> _doCheckout({
    required List<_PaymentEntry> payments,
    required double change,
  }) async {
    final cartProvider = context.read<CartProvider>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final note = _noteController.text.trim();

    final orderId = await cartProvider.checkout(
      context: context,
      paymentType: payments.first.type,
      orderType: widget.orderType,
      tableId: widget.table?.id,
      locationId: widget.table?.locationId,
      paidAmount: widget.total,
      change: change,
      shouldPrint: _shouldPrintReceipt,
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;

    if (orderId != null) {
      final orderRepo = OrderRepository();
      final now = DateTime.now().toIso8601String();
      for (final p in payments) {
        await orderRepo.insertOrderPayment({
          'order_id': orderId,
          'payment_type': p.type,
          'amount': p.amount,
          'created_at': now,
          'is_synced': 0,
        });
      }
      final printError = cartProvider.lastPrintError;
      if (printError != null) {
        messenger.showSnackBar(SnackBar(
          content: Text("Buyurtma saqlandi, lekin chek chiqarilmadi: $printError"),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ));
      }
      nav.pop(true);
    } else {
      setState(() => _isProcessing = false);
      messenger.showSnackBar(const SnackBar(
        content: Text("To'lovni amalga oshirishda xatolik yuz berdi"),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            _buildTabBar(),
            // AnimatedBuilder + shartli ko'rsatish — dialog balandligi content'ga qarab o'zgaradi
            AnimatedBuilder(
              animation: _tabController,
              builder: (_, child) {
                if (_tabController.index == 0) {
                  return _SimpleTab(
                    total: widget.total,
                    amountStr: _simpleAmountStr,
                    selectedType: _simpleType,
                    shouldPrint: _shouldPrintReceipt,
                    noteController: _noteController,
                    isProcessing: _isProcessing,
                    onNumpad: _onSimpleNumpad,
                    onTypeSelect: (t) => setState(() => _simpleType = t),
                    onQuickAmount: (a) => setState(() => _simpleAmountStr = a.toString()),
                    onFillTotal: () => setState(
                      () => _simpleAmountStr = widget.total.toInt().toString(),
                    ),
                    onPrintToggle: (v) async {
                      setState(() => _shouldPrintReceipt = v);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool(_printPrefKey, v);
                    },
                    onFinish: _simpleCanFinish ? _handleSimplePayment : null,
                    change: _simpleChange,
                    simpleAmount: _simpleAmount,
                  );
                }
                return _SplitTab(
                  total: widget.total,
                  payments: _splitPayments,
                  splitType: _splitType,
                  splitAmountStr: _splitAmountStr,
                  shouldPrint: _shouldPrintReceipt,
                  noteController: _noteController,
                  isProcessing: _isProcessing,
                  remaining: _splitRemaining,
                  currentAmount: _splitCurrentAmount,
                  onNumpad: _onSplitNumpad,
                  onTypeSelect: (t) => setState(() {
                    _splitType = t;
                    _splitAmountStr = '';
                  }),
                  onQuickAmount: (a) => setState(() => _splitAmountStr = a.toString()),
                  onFillRemaining: () => setState(
                    () => _splitAmountStr = _splitRemaining.toInt().toString(),
                  ),
                  onAddPayment: _addSplitPayment,
                  onRemovePayment: _removeSplitPayment,
                  onPrintToggle: (v) async {
                    setState(() => _shouldPrintReceipt = v);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_printPrefKey, v);
                  },
                  onFinish: _splitCanFinish ? _handleSplitPayment : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      color: AppTheme.primaryColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: _isProcessing ? null : () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            "To'lov",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Jami summa",
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.65)),
              ),
              Text(
                PriceFormatter.format(widget.total),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          tabs: const [
            Tab(text: "Oddiy to'lov"),
            Tab(text: "To'lovni bo'lish"),
          ],
        ),
      ),
    );
  }
}

// ── Oddiy to'lov tab ──────────────────────────────────────────────────────────

class _SimpleTab extends StatelessWidget {
  final double total;
  final String amountStr;
  final String selectedType;
  final bool shouldPrint;
  final TextEditingController noteController;
  final bool isProcessing;
  final double change;
  final double simpleAmount;
  final void Function(String) onNumpad;
  final void Function(String) onTypeSelect;
  final void Function(int) onQuickAmount;
  final VoidCallback onFillTotal;
  final void Function(bool) onPrintToggle;
  final VoidCallback? onFinish;

  const _SimpleTab({
    required this.total,
    required this.amountStr,
    required this.selectedType,
    required this.shouldPrint,
    required this.noteController,
    required this.isProcessing,
    required this.change,
    required this.simpleAmount,
    required this.onNumpad,
    required this.onTypeSelect,
    required this.onQuickAmount,
    required this.onFillTotal,
    required this.onPrintToggle,
    required this.onFinish,
  });

  bool get _isSufficient => simpleAmount >= total;
  bool get _hasChange => change > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // To'lov turi
          _sectionLabel(theme, "To'lov turi"),
          const SizedBox(height: 8),
          _TypeSelector(selected: selectedType, onSelect: onTypeSelect),
          const SizedBox(height: 14),

          // 2 column: chap=ma'lumot, o'ng=numpad
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chap ustun
                Expanded(
                  flex: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AmountDisplay(
                        label: "To'lov summasi",
                        amountStr: amountStr,
                        amount: simpleAmount,
                        isGood: _isSufficient,
                        theme: theme,
                      ),
                      const SizedBox(height: 10),
                      _ChangeDisplay(change: change, theme: theme),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: onFillTotal,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
                        label: Text(
                          "Jami summani to'ldirish  (${PriceFormatter.format(total)})",
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Izoh (ixtiyoriy)',
                          hintText: 'Buyurtma haqida eslatma...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _PrintToggle(value: shouldPrint, onChanged: onPrintToggle),
                    ],
                  ),
                ),
                const SizedBox(width: 16),

                // O'ng ustun — numpad
                SizedBox(
                  width: 230,
                  child: _Numpad(
                    onTap: onNumpad,
                    onQuickAmount: onQuickAmount,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _FinishButton(
            isProcessing: isProcessing,
            onPressed: onFinish,
            changeLabel: _hasChange ? PriceFormatter.format(change) : null,
          ),
        ],
      ),
    );
  }
}

// ── To'lovni bo'lish tab ──────────────────────────────────────────────────────

class _SplitTab extends StatelessWidget {
  final double total;
  final List<_PaymentEntry> payments;
  final String splitType;
  final String splitAmountStr;
  final bool shouldPrint;
  final TextEditingController noteController;
  final bool isProcessing;
  final double remaining;
  final double currentAmount;
  final void Function(String) onNumpad;
  final void Function(String) onTypeSelect;
  final void Function(int) onQuickAmount;
  final VoidCallback onFillRemaining;
  final VoidCallback onAddPayment;
  final void Function(int) onRemovePayment;
  final void Function(bool) onPrintToggle;
  final VoidCallback? onFinish;

  const _SplitTab({
    required this.total,
    required this.payments,
    required this.splitType,
    required this.splitAmountStr,
    required this.shouldPrint,
    required this.noteController,
    required this.isProcessing,
    required this.remaining,
    required this.currentAmount,
    required this.onNumpad,
    required this.onTypeSelect,
    required this.onQuickAmount,
    required this.onFillRemaining,
    required this.onAddPayment,
    required this.onRemovePayment,
    required this.onPrintToggle,
    required this.onFinish,
  });

  bool get _isPaid => remaining.abs() < 0.01;

  String _labelFor(String type) =>
      _kTypes.firstWhere((c) => c.type == type, orElse: () => _TypeCfg(type, type, Icons.payment)).label;

  IconData _iconFor(String type) =>
      _kTypes.firstWhere((c) => c.type == type, orElse: () => _TypeCfg(type, type, Icons.payment)).icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = currentAmount > 0 && currentAmount <= remaining + 0.01;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Qolgan summa
          _RemainingIndicator(remaining: remaining, isPaid: _isPaid),
          const SizedBox(height: 14),

          // Qo'shilgan to'lovlar
          if (payments.isNotEmpty) ...[
            _sectionLabel(theme, "Qo'shilgan to'lovlar"),
            const SizedBox(height: 8),
            ...List.generate(payments.length, (i) {
              final p = payments[i];
              return _PaymentRow(
                icon: _iconFor(p.type),
                label: _labelFor(p.type),
                amount: p.amount,
                onRemove: () => onRemovePayment(i),
                theme: theme,
              );
            }),
            const SizedBox(height: 12),
          ],

          // To'lov qo'shish (faqat qolgan > 0 bo'lsa)
          if (!_isPaid) ...[
            _sectionLabel(theme, "To'lov qo'shish"),
            const SizedBox(height: 8),
            _TypeSelector(selected: splitType, onSelect: onTypeSelect),
            const SizedBox(height: 12),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chap: summa + qo'shish
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AmountDisplay(
                        label: _labelFor(splitType),
                        amountStr: splitAmountStr,
                        amount: currentAmount,
                        isGood: canAdd && currentAmount > 0,
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: onFillRemaining,
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 13),
                        label: Text(
                          "Qolgan summani to'ldirish  (${PriceFormatter.format(remaining)})",
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                          foregroundColor: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton.icon(
                          onPressed: canAdd ? onAddPayment : null,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text(
                            "Qo'shish",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // O'ng: numpad
                SizedBox(
                  width: 230,
                  child: _Numpad(
                    onTap: onNumpad,
                    onQuickAmount: onQuickAmount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Izoh
          TextField(
            controller: noteController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Izoh (ixtiyoriy)',
              hintText: 'Buyurtma haqida eslatma...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 6),
          _PrintToggle(value: shouldPrint, onChanged: onPrintToggle),
          const SizedBox(height: 12),

          _FinishButton(isProcessing: isProcessing, onPressed: onFinish),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const _TypeSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _kTypes.map((cfg) {
          final isSelected = selected == cfg.type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(cfg.type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withValues(alpha: 0.06),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : AppTheme.primaryColor.withValues(alpha: 0.22),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(cfg.icon, size: 18, color: isSelected ? Colors.white : AppTheme.primaryColor),
                    const SizedBox(height: 3),
                    Text(
                      cfg.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AmountDisplay extends StatelessWidget {
  final String label;
  final String amountStr;
  final double amount;
  final bool isGood;
  final ThemeData theme;

  const _AmountDisplay({
    required this.label,
    required this.amountStr,
    required this.amount,
    required this.isGood,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF10B981);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: isGood
            ? green.withValues(alpha: 0.07)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGood
              ? green.withValues(alpha: 0.3)
              : theme.colorScheme.outline.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            amountStr.isEmpty ? '0' : PriceFormatter.format(amount),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: isGood ? green : theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ChangeDisplay extends StatelessWidget {
  final double change;
  final ThemeData theme;

  const _ChangeDisplay({required this.change, required this.theme});

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3B82F6);
    final hasChange = change > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: hasChange ? blue.withValues(alpha: 0.07) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasChange ? blue.withValues(alpha: 0.25) : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 18,
                color: hasChange ? blue : theme.colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 8),
              Text(
                "Qaytim",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: hasChange ? blue : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          Text(
            PriceFormatter.format(change),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: hasChange ? blue : theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _RemainingIndicator extends StatelessWidget {
  final double remaining;
  final bool isPaid;

  const _RemainingIndicator({required this.remaining, required this.isPaid});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF10B981);
    const orange = Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isPaid ? green.withValues(alpha: 0.09) : orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaid ? green.withValues(alpha: 0.35) : orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isPaid ? Icons.check_circle_rounded : Icons.account_balance_wallet_rounded,
                size: 20,
                color: isPaid ? green : orange,
              ),
              const SizedBox(width: 8),
              Text(
                isPaid ? "To'liq to'landi" : "Qolgan summa:",
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isPaid ? green : orange,
                ),
              ),
            ],
          ),
          if (!isPaid)
            Text(
              PriceFormatter.format(remaining),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double amount;
  final VoidCallback onRemove;
  final ThemeData theme;

  const _PaymentRow({
    required this.icon,
    required this.label,
    required this.amount,
    required this.onRemove,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Text(
            PriceFormatter.format(amount),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onTap;
  final void Function(int) onQuickAmount;

  const _Numpad({required this.onTap, required this.onQuickAmount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget btn(String val, {Color? bg, Color? fg}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Material(
            color: bg ?? theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onTap(val),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 56,
                child: Center(
                  child: val == '⌫'
                      ? Icon(Icons.backspace_outlined, size: 22,
                          color: fg ?? theme.colorScheme.onSurface)
                      : Text(
                          val,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: fg ?? theme.colorScheme.onSurface,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget quickBtn(int amount) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: OutlinedButton(
            onPressed: () => onQuickAmount(amount),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              _short(amount),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: [btn('1'), btn('2'), btn('3')]),
        Row(children: [btn('4'), btn('5'), btn('6')]),
        Row(children: [btn('7'), btn('8'), btn('9')]),
        Row(children: [
          btn('C',  bg: Colors.orange.shade50,   fg: Colors.orange.shade800),
          btn('0'),
          btn('⌫', bg: Colors.blueGrey.shade50, fg: Colors.blueGrey.shade700),
        ]),
        const SizedBox(height: 6),
        Row(children: [quickBtn(10000),  quickBtn(20000),  quickBtn(50000)]),
        Row(children: [quickBtn(100000), quickBtn(200000), quickBtn(500000)]),
      ],
    );
  }

  String _short(int a) {
    if (a >= 1000000) return '${(a / 1000000).toStringAsFixed(1)}M';
    if (a >= 1000)    return '${(a / 1000).toStringAsFixed(0)}K';
    return a.toString();
  }
}

class _PrintToggle extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;

  const _PrintToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text("Chek chiqarish", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: const Text("To'lovdan so'ng printerdan chek chiqadi", style: TextStyle(fontSize: 12)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: Colors.green,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FinishButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback? onPressed;
  final String? changeLabel;

  const _FinishButton({
    required this.isProcessing,
    required this.onPressed,
    this.changeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.secondaryColor,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: isProcessing
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text(
                    "To'lovni yakunlash",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (changeLabel != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Qaytim: $changeLabel",
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

// ── Helper ────────────────────────────────────────────────────────────────────

Widget _sectionLabel(ThemeData theme, String text) {
  return Text(
    text,
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
    ),
  );
}
