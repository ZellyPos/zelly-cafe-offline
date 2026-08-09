import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/waiter_repository.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/waiter_payment.dart';
import '../../providers/shift_provider.dart';
import '../../providers/connectivity_provider.dart';

// ── Period enum ───────────────────────────────────────────────────────────────

enum WaiterPeriod { shift, today, week, month, all }

extension WaiterPeriodExt on WaiterPeriod {
  String get label {
    switch (this) {
      case WaiterPeriod.shift:  return 'Bu smena';
      case WaiterPeriod.today:  return 'Bugun';
      case WaiterPeriod.week:   return 'Bu hafta';
      case WaiterPeriod.month:  return 'Bu oy';
      case WaiterPeriod.all:    return 'Barchasi';
    }
  }
}

// ── Main screen ───────────────────────────────────────────────────────────────

class WaiterPaymentsScreen extends StatefulWidget {
  const WaiterPaymentsScreen({super.key});

  @override
  State<WaiterPaymentsScreen> createState() => _WaiterPaymentsScreenState();
}

class _WaiterPaymentsScreenState extends State<WaiterPaymentsScreen> {
  WaiterPeriod _period = WaiterPeriod.month;
  List<Map<String, dynamic>> _stats = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  ({String? from, String? to, int? shiftId}) get _dateRange {
    final shift = context.read<ShiftProvider>().activeShift;
    final now = DateTime.now();

    switch (_period) {
      case WaiterPeriod.shift:
        return (from: null, to: null, shiftId: shift?.id);
      case WaiterPeriod.today:
        final d = '${now.year}-${_p(now.month)}-${_p(now.day)}';
        return (from: d, to: d, shiftId: null);
      case WaiterPeriod.week:
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return (
          from: '${monday.year}-${_p(monday.month)}-${_p(monday.day)}',
          to: '${now.year}-${_p(now.month)}-${_p(now.day)}',
          shiftId: null,
        );
      case WaiterPeriod.month:
        return (
          from: '${now.year}-${_p(now.month)}-01',
          to: '${now.year}-${_p(now.month)}-${_p(now.day)}',
          shiftId: null,
        );
      case WaiterPeriod.all:
        return (from: null, to: null, shiftId: null);
    }
  }

  String _p(int n) => n.toString().padLeft(2, '0');

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final range = _dateRange;
      final data = await WaiterRepository().getAllWaitersStats(
        fromDate: range.from,
        toDate: range.to,
        shiftId: range.shiftId,
      );
      if (mounted) setState(() { _stats = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _earned(Map<String, dynamic> row) {
    final type = (row['type'] as num?)?.toInt() ?? 0;
    final value = (row['value'] as num?)?.toDouble() ?? 0;
    final orders = (row['order_count'] as num?)?.toInt() ?? 0;
    final sales = (row['total_sales'] as num?)?.toDouble() ?? 0;
    if (row['name'] == 'Kassa') return 0;
    return type == 1 ? sales * (value / 100) : orders * value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasShift = context.watch<ShiftProvider>().hasOpenShift;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Ofisant to\'lovlari',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yangilash',
            onPressed: _load,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodFilter(theme, hasShift),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_stats.isEmpty)
            _buildEmpty(theme)
          else
            Expanded(child: _buildList(theme)),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter(ThemeData theme, bool hasShift) {
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: WaiterPeriod.values.map((p) {
            final disabled = p == WaiterPeriod.shift && !hasShift;
            final selected = _period == p;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: disabled
                    ? null
                    : () {
                        setState(() => _period = p);
                        _load();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: disabled
                        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.4)
                        : selected
                        ? const Color(0xFF6366F1)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    p.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: disabled
                          ? theme.colorScheme.onSurface.withOpacity(0.3)
                          : selected
                          ? Colors.white
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_alt_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.1),
            ),
            const SizedBox(height: 12),
            Text(
              'Ofisantlar topilmadi',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _stats.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _WaiterCard(
        row: _stats[i],
        earned: _earned(_stats[i]),
        period: _period,
        onPaymentDone: _load,
      ),
    );
  }
}

// ── Waiter Card ───────────────────────────────────────────────────────────────

class _WaiterCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final double earned;
  final WaiterPeriod period;
  final VoidCallback onPaymentDone;

  const _WaiterCard({
    required this.row,
    required this.earned,
    required this.period,
    required this.onPaymentDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (row['name'] as String?) ?? '';
    final type = (row['type'] as num?)?.toInt() ?? 0;
    final value = (row['value'] as num?)?.toDouble() ?? 0;
    final isActive = (row['is_active'] as num?)?.toInt() == 1;
    final orderCount = (row['order_count'] as num?)?.toInt() ?? 0;
    final totalSales = (row['total_sales'] as num?)?.toDouble() ?? 0;
    final totalPaid = (row['total_paid'] as num?)?.toDouble() ?? 0;
    final unpaid = (earned - totalPaid).clamp(0.0, double.infinity);
    final isKassa = name == 'Kassa';
    final noRate = value <= 0 && !isKassa;

    String typeLabel;
    if (isKassa) {
      typeLabel = 'Kassir';
    } else if (noRate) {
      typeLabel = 'To\'lov belgilanmagan';
    } else {
      typeLabel = type == 1
          ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% foiz'
          : '${PriceFormatter.format(value)} so\'m / buyurtma';
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unpaid > 0
              ? Colors.red.withOpacity(0.2)
              : theme.dividerColor.withOpacity(0.12),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                _avatar(name, theme),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        typeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: noRate
                              ? Colors.orange
                              : theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isActive
                        ? const Color(0xFF10B981)
                        : Colors.grey).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? 'Faol' : 'Nofaol',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive ? const Color(0xFF10B981) : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            if (!isKassa) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Stats table
              _statRow(theme, 'Buyurtmalar:', '$orderCount ta'),
              const SizedBox(height: 6),
              _statRow(
                theme,
                'Savdo:',
                '${PriceFormatter.format(totalSales)} so\'m',
              ),
              const SizedBox(height: 6),
              _statRow(
                theme,
                'Hisoblangan:',
                '${PriceFormatter.format(earned)} so\'m',
                color: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 6),
              _statRow(
                theme,
                'To\'langan:',
                '${PriceFormatter.format(totalPaid)} so\'m',
                color: const Color(0xFF10B981),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
              _statRow(
                theme,
                'Qoldiq:',
                unpaid > 0
                    ? '${PriceFormatter.format(unpaid)} so\'m'
                    : 'To\'liq to\'langan',
                color: unpaid > 0 ? Colors.red : const Color(0xFF10B981),
                bold: true,
              ),

              const SizedBox(height: 14),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showHistory(context, row),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Tarix'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: noRate
                          ? null
                          : () => _showPaymentDialog(context, row, unpaid),
                      icon: const Icon(Icons.payments_rounded, size: 16),
                      label: const Text(
                        'To\'lov qilish',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF6366F1).withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name, ThemeData theme) {
    const colors = [
      Color(0xFF6C5CE7), Color(0xFF00B894), Color(0xFF0984E3),
      Color(0xFFE17055), Color(0xFFFDAB3D), Color(0xFF74B9FF),
    ];
    final color = colors[name.hashCode.abs() % colors.length];
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _statRow(
    ThemeData theme,
    String label,
    String value, {
    Color? color,
    bool bold = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    Map<String, dynamic> row,
    double unpaid,
  ) {
    showDialog(
      context: context,
      builder: (_) => _PaymentDialog(
        waiterName: (row['name'] as String?) ?? '',
        waiterId: (row['id'] as num).toInt(),
        unpaid: unpaid,
        onDone: onPaymentDone,
      ),
    );
  }

  void _showHistory(BuildContext context, Map<String, dynamic> row) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WaiterPaymentHistoryScreen(
          waiterId: (row['id'] as num).toInt(),
          waiterName: (row['name'] as String?) ?? '',
        ),
      ),
    );
  }
}

// ── Payment Dialog ────────────────────────────────────────────────────────────

class _PaymentDialog extends StatefulWidget {
  final String waiterName;
  final int waiterId;
  final double unpaid;
  final VoidCallback onDone;

  const _PaymentDialog({
    required this.waiterName,
    required this.waiterId,
    required this.unpaid,
    required this.onDone,
  });

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String? _amountError;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(' ', '')) ?? 0;
    if (amount <= 0) {
      setState(() => _amountError = 'Summa 0 dan katta bo\'lishi kerak');
      return;
    }
    if (amount > widget.unpaid + 0.01) {
      setState(() => _amountError = 'Qoldiqdan oshib ketdi (${PriceFormatter.format(widget.unpaid)})');
      return;
    }

    setState(() { _saving = true; _amountError = null; });
    try {
      final connectivity = context.read<ConnectivityProvider>();
      final user = connectivity.currentUser;
      final createdBy = user?['name']?.toString() ?? 'Admin';

      await WaiterRepository().addWaiterPayment(
        waiterId: widget.waiterId,
        amount: amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        createdBy: createdBy,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onDone();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(
        '${widget.waiterName} ga to\'lov',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  _row(theme, 'Hisoblangan:', widget.unpaid),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: theme.dividerColor.withOpacity(0.3)),
                  const SizedBox(height: 6),
                  _row(theme, 'Qoldiq:', widget.unpaid, color: Colors.red, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Amount input
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: InputDecoration(
                labelText: 'Summa',
                suffixText: "so'm",
                border: const OutlineInputBorder(),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 8),

            // Fill button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _amountCtrl.text =
                    widget.unpaid.toInt().toString(),
                child: Text(
                  'Barchasini to\'la (${PriceFormatter.format(widget.unpaid)} so\'m)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Note
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Bekor qilish'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text('To\'lash',
                  style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, String label, double value,
      {Color? color, bool bold = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
        Text(
          '${PriceFormatter.format(value)} so\'m',
          style: TextStyle(
            fontSize: bold ? 14 : 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ── Payment History Screen ────────────────────────────────────────────────────

class _WaiterPaymentHistoryScreen extends StatefulWidget {
  final int waiterId;
  final String waiterName;

  const _WaiterPaymentHistoryScreen({
    required this.waiterId,
    required this.waiterName,
  });

  @override
  State<_WaiterPaymentHistoryScreen> createState() =>
      _WaiterPaymentHistoryScreenState();
}

class _WaiterPaymentHistoryScreenState
    extends State<_WaiterPaymentHistoryScreen> {
  List<WaiterPayment> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await WaiterRepository()
          .getWaiterPaymentHistory(widget.waiterId);
      if (mounted) {
        setState(() {
          _payments = rows.map((r) => WaiterPayment.fromMap(r)).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _payments.fold(0.0, (s, p) => s + p.amount);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          '${widget.waiterName} — To\'lov tarixi',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payments.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To\'lovlar tarixi yo\'q',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _payments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _buildPaymentTile(_payments[i], theme),
                  ),
                ),
                // Total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withOpacity(0.15),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Jami to\'langan:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${PriceFormatter.format(total)} so\'m',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPaymentTile(WaiterPayment p, ThemeData theme) {
    final dt = DateTime.tryParse(p.paidAt);
    final dateStr = dt != null
        ? '${_p(dt.day)}.${_p(dt.month)}.${dt.year}'
        : p.paidAt.substring(0, 10);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF10B981),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateStr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const Spacer(),
                    Text(
                      '${PriceFormatter.format(p.amount)} so\'m',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                if (p.createdBy.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      p.createdBy,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                if (p.note != null && p.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Izoh: ${p.note}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
