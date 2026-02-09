import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/customer.dart';
import '../../models/transaction.dart';

class OutlaysScreen extends StatefulWidget {
  final Customer customer;
  const OutlaysScreen({super.key, required this.customer});

  @override
  State<OutlaysScreen> createState() => _OutlaysScreenState();
}

class _OutlaysScreenState extends State<OutlaysScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadTransactions(widget.customer.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final currentCustomer = customerProvider.customers.firstWhere(
      (c) => c.id == widget.customer.id,
      orElse: () => widget.customer,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(currentCustomer.name),
        actions: [
          _buildActionButton(
            context,
            'Chiqim',
            Colors.red.shade600,
            Icons.remove_circle_outline,
            'outlay',
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            context,
            'To\'lov',
            Colors.green.shade600,
            Icons.add_circle_outline,
            'payment',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildCustomerSummary(currentCustomer),
          Expanded(
            child: customerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTransactionList(customerProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    Color color,
    IconData icon,
    String type,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => _showTransactionDialog(context, type, label, color),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildCustomerSummary(Customer customer) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem("Qarz", customer.debt, Colors.red),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildSummaryItem("Haqqi", customer.credit, Colors.green),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          _buildSummaryItem(
            "Balans",
            customer.credit - customer.debt,
            (customer.credit - customer.debt) >= 0 ? Colors.green : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          PriceFormatter.format(amount),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList(CustomerProvider provider) {
    if (provider.transactions.isEmpty) {
      return const Center(child: Text('Tranzaksiyalar mavjud emas'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: provider.transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = provider.transactions[index];
        final isOutlay = tx.type == 'outlay';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (isOutlay ? Colors.red : Colors.green)
                  .withOpacity(0.1),
              child: Icon(
                isOutlay ? Icons.arrow_outward : Icons.arrow_downward,
                color: isOutlay ? Colors.red : Colors.green,
                size: 20,
              ),
            ),
            title: Text(
              isOutlay ? 'Chiqim' : 'To\'lov',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${tx.note ?? ''}\n${tx.createdAt.day}.${tx.createdAt.month}.${tx.createdAt.year} ${tx.createdAt.hour}:${tx.createdAt.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              PriceFormatter.format(tx.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isOutlay ? Colors.red : Colors.green,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTransactionDialog(
    BuildContext context,
    String type,
    String title,
    Color color,
  ) {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Summa',
                suffixText: 'so\'m',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Izoh (nima uchun)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                context.read<CustomerProvider>().addTransaction(
                  Transaction(
                    customerId: widget.customer.id,
                    type: type,
                    amount: amount,
                    note: noteController.text,
                    createdAt: DateTime.now(),
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}
