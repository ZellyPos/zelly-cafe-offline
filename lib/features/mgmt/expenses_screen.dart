import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/expense_provider.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/expense.dart';
import 'expense_categories_screen.dart';
import '../../models/expense_category.dart';
import '../../providers/connectivity_provider.dart';
import '../../core/app_strings.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadExpenses(
        start: _startDate,
        end: _endDate,
        connectivity: context.read<ConnectivityProvider>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(AppStrings.expensesTitle),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ExpenseCategoriesScreen(),
                ),
              );
            },
            tooltip: AppStrings.expenseTypes,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddExpenseDialog(context),
              icon: const Icon(Icons.add),
              label: Text(AppStrings.addExpense),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: expenseProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildExpenseList(expenseProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            "${_startDate.day}.${_startDate.month}.${_startDate.year} - "
            "${_endDate.day}.${_endDate.month}.${_endDate.year}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          TextButton(
            onPressed: _selectDateRange,
            child: Text(AppStrings.selectDate),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseList(ExpenseProvider provider) {
    if (provider.expenses.isEmpty) {
      return Center(child: Text(AppStrings.noExpenses));
    }

    final total = provider.expenses.fold<double>(0, (sum, e) => sum + e.amount);

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.expenses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final expense = provider.expenses[index];
              final category = provider.categories.firstWhere(
                (c) => c.id == expense.categoryId,
                orElse: () => ExpenseCategory(name: AppStrings.noExpenseType),
              );

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  title: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${expense.note ?? ''}\n${expense.createdAt.hour.toString().padLeft(2, '0')}:${expense.createdAt.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    PriceFormatter.format(expense.amount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 18,
                    ),
                  ),
                  onLongPress: () => _confirmDelete(context, expense.id!),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.totalExpenses,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                PriceFormatter.format(total),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      context.read<ExpenseProvider>().loadExpenses(
        start: _startDate,
        end: _endDate,
        connectivity: context.read<ConnectivityProvider>(),
      );
    }
  }

  void _showAddExpenseDialog(BuildContext context) {
    final provider = context.read<ExpenseProvider>();
    int? selectedCatId = provider.categories.isNotEmpty
        ? provider.categories.first.id
        : null;
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    if (selectedCatId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.addExpenseTypeFirst),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppStrings.newExpense),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedCatId,
                decoration: InputDecoration(labelText: AppStrings.expenseType),
                items: provider.categories
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (id) => setDialogState(() => selectedCatId = id),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: AppStrings.amount,
                  suffixText: "so'm",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: AppStrings.note),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount > 0 && selectedCatId != null) {
                  context.read<ExpenseProvider>().addExpense(
                    Expense(
                      categoryId: selectedCatId!,
                      amount: amount,
                      note: noteController.text,
                      createdAt: DateTime.now(),
                    ),
                    connectivity: context.read<ConnectivityProvider>(),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.confirmDeleteTitle),
        content: Text(AppStrings.confirmDeleteExpense),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ExpenseProvider>().deleteExpense(
                id,
                connectivity: context.read<ConnectivityProvider>(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }
}
