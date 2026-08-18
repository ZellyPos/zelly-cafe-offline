import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/shift_provider.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/expense.dart';
import '../../models/expense_category.dart';
import 'expense_categories_screen.dart';
import '../../providers/connectivity_provider.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shiftProvider = context.read<ShiftProvider>();
      final expenseProvider = context.read<ExpenseProvider>();
      expenseProvider.loadExpenses(shiftId: shiftProvider.activeShift?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseProvider = context.watch<ExpenseProvider>();
    final shiftProvider = context.watch<ShiftProvider>();
    final activeShift = shiftProvider.activeShift;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Xarajatlar',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.category_rounded),
            tooltip: 'Kategoriyalar',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExpenseCategoriesScreen(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () => _showAddExpenseDialog(context, activeShift?.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Xarajat qo\'shish',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(context, expenseProvider, activeShift?.id),
          if (expenseProvider.isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (expenseProvider.expenses.isEmpty)
            _buildEmpty(theme, expenseProvider)
          else
            Expanded(
              child: _buildContent(context, expenseProvider, theme),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, ExpenseProvider provider, int? shiftId) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _chip(
            context,
            label: 'Bugun',
            icon: Icons.today_rounded,
            selected: provider.filter == ExpenseFilter.today,
            onTap: () => provider.setFilter(ExpenseFilter.today, shiftId: shiftId),
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            label: 'Bu smena',
            icon: Icons.work_rounded,
            selected: provider.filter == ExpenseFilter.currentShift,
            onTap: shiftId == null
                ? null
                : () => provider.setFilter(ExpenseFilter.currentShift, shiftId: shiftId),
          ),
          const SizedBox(width: 8),
          _chip(
            context,
            label: 'Barchasi',
            icon: Icons.list_rounded,
            selected: provider.filter == ExpenseFilter.all,
            onTap: () => provider.setFilter(ExpenseFilter.all, shiftId: shiftId),
          ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: disabled
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
              : selected
              ? Colors.red.shade600
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected && !disabled
                ? Colors.red.shade600
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: disabled
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                  : selected
                  ? Colors.white
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: disabled
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : selected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme, ExpenseProvider provider) {
    final hasCats = provider.categories.isNotEmpty;
    return Expanded(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasCats ? Icons.receipt_long_rounded : Icons.category_rounded,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            const SizedBox(height: 12),
            Text(
              hasCats
                  ? 'Bu davrda xarajat yo\'q'
                  : 'Avval kategoriya qo\'shing',
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ExpenseProvider provider,
    ThemeData theme,
  ) {
    return Column(
      children: [
        if (provider.categoryTotals.isNotEmpty)
          _buildCategoryTotals(context, provider, theme),
        Expanded(child: _buildList(context, provider, theme)),
      ],
    );
  }

  Widget _buildCategoryTotals(
    BuildContext context,
    ExpenseProvider provider,
    ThemeData theme,
  ) {
    final totals = provider.categoryTotals;
    final grandTotal = totals.values.fold(0.0, (a, b) => a + b);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KATEGORIYALAR BO\'YICHA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          ...totals.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.key,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Text(
                    '${PriceFormatter.format(e.value)} so\'m',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Jami:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Text(
                '${PriceFormatter.format(grandTotal)} so\'m',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ExpenseProvider provider,
    ThemeData theme,
  ) {
    final showShift = provider.filter == ExpenseFilter.all;

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: provider.expenses.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final expense = provider.expenses[index];
        final category = provider.categories.firstWhere(
          (c) => c.id == expense.categoryId,
          orElse: () => ExpenseCategory(name: 'Boshqa'),
        );
        final timeStr =
            '${expense.createdAt.hour.toString().padLeft(2, '0')}:'
            '${expense.createdAt.minute.toString().padLeft(2, '0')}';

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.money_off_rounded,
                color: Colors.red,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (showShift && expense.shiftId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Smena #${expense.shiftId}',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (expense.note != null && expense.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      expense.note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
            trailing: Text(
              '${PriceFormatter.format(expense.amount)} so\'m',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: theme.colorScheme.error,
              ),
            ),
            onLongPress: expense.id != null
                ? () => _confirmDelete(context, expense.id!)
                : null,
          ),
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context, int? shiftId) {
    final provider = context.read<ExpenseProvider>();

    if (provider.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Avval kategoriya qo\'shing'),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Qo\'shish',
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExpenseCategoriesScreen()),
            ),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => _AddExpenseDialog(
        shiftId: shiftId,
        categories: provider.categories,
        onSave: (expense) async {
          await provider.addExpense(
            expense,
            connectivity: context.read<ConnectivityProvider>(),
            shiftId: shiftId,
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Xarajatni o\'chirish',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Bu xarajatni o\'chirishni tasdiqlaysizmi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExpenseProvider>().deleteExpense(
                id,
                connectivity: context.read<ConnectivityProvider>(),
              );
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.error),
            child: const Text('O\'chirish', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Dialog ────────────────────────────────────────────────────────────────────

class _AddExpenseDialog extends StatefulWidget {
  final int? shiftId;
  final List<ExpenseCategory> categories;
  final Future<void> Function(Expense) onSave;

  const _AddExpenseDialog({
    required this.shiftId,
    required this.categories,
    required this.onSave,
  });

  @override
  State<_AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<_AddExpenseDialog> {
  late int? _selectedCatId;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _saving = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    _selectedCatId = widget.categories.isNotEmpty ? widget.categories.first.id : null;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(' ', '')) ?? 0;
    if (amount <= 0) {
      setState(() => _amountError = 'Summa 0 dan katta bo\'lishi kerak');
      return;
    }
    if (_selectedCatId == null) return;

    setState(() { _saving = true; _amountError = null; });
    try {
      await widget.onSave(
        Expense(
          categoryId: _selectedCatId!,
          amount: amount,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          createdAt: DateTime.now(),
          shiftId: widget.shiftId,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text(
        'Yangi xarajat',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kategoriya
            DropdownButtonFormField<int>(
              initialValue: _selectedCatId,
              decoration: const InputDecoration(
                labelText: 'Kategoriya',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (id) => setState(() => _selectedCatId = id),
            ),
            const SizedBox(height: 14),

            // Summa
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (_) {
                if (_amountError != null) setState(() => _amountError = null);
              },
              decoration: InputDecoration(
                labelText: 'Summa',
                suffixText: "so'm",
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                errorText: _amountError,
              ),
            ),
            const SizedBox(height: 14),

            // Izoh
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Izoh (ixtiyoriy)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 14),

            // Smena info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.work_rounded,
                    size: 16,
                    color: widget.shiftId != null
                        ? const Color(0xFF10B981)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.shiftId != null
                        ? 'Joriy smena: #${widget.shiftId}'
                        : 'Ochiq smena yo\'q',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.shiftId != null
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.75)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
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
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text('Saqlash', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
