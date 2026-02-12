import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/customer_provider.dart';
import '../../core/utils/price_formatter.dart';
import '../../models/customer.dart';
import 'outlays_screen.dart';
import '../../core/app_strings.dart';
import '../../providers/connectivity_provider.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers(
        connectivity: context.read<ConnectivityProvider>(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(AppStrings.customersTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddCustomerDialog(context),
              icon: const Icon(Icons.person_add),
              label: Text(AppStrings.newCustomer),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4C1D95),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: customerProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildCustomerList(customerProvider),
    );
  }

  Widget _buildCustomerList(CustomerProvider provider) {
    if (provider.customers.isEmpty) {
      return Center(child: Text(AppStrings.emptyCustomers));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: provider.customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final customer = provider.customers[index];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OutlaysScreen(customer: customer),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF4C1D95).withOpacity(0.1),
                    child: const Icon(Icons.person, color: Color(0xFF4C1D95)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        if (customer.phone != null &&
                            customer.phone!.isNotEmpty)
                          Text(
                            customer.phone!,
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (customer.debt > 0)
                        Text(
                          "${AppStrings.debtLabel}: ${PriceFormatter.format(customer.debt)}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (customer.credit > 0)
                        Text(
                          "${AppStrings.creditLabel}: ${PriceFormatter.format(customer.credit)}",
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (customer.debt == 0 && customer.credit == 0)
                        Text(
                          "${AppStrings.balanceLabel}: 0",
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAddCustomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.addCustomerTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: AppStrings.fullName),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: AppStrings.phoneNumber),
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
              if (nameController.text.isNotEmpty) {
                context.read<CustomerProvider>().addCustomer(
                  Customer(
                    name: nameController.text,
                    phone: phoneController.text,
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
    );
  }
}
