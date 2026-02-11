import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user.dart';
import '../../providers/connectivity_provider.dart';

class CashiersMgmtScreen extends StatelessWidget {
  const CashiersMgmtScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final cashiers = userProvider.cashiers;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Kassirlar Boshqaruvi'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text("Yangi Kassir"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: userProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : cashiers.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: MediaQuery.of(context).size.width <= 1100
                    ? 350
                    : 400,
                mainAxisExtent: MediaQuery.of(context).size.width <= 1100
                    ? 160
                    : 180,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: cashiers.length,
              itemBuilder: (context, index) {
                final cashier = cashiers[index];
                return _buildCashierCard(context, cashier);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Kassirlar topilmadi",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Tizimga yangi kassir qo'shish uchun yuqoridagi tugmani bosing",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCashierCard(BuildContext context, AppUser cashier) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.black,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cashier.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "PIN: ${cashier.pin}",
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: cashier.isActive == 1,
                onChanged: (val) {
                  context.read<UserProvider>().updateUser(
                    cashier.copyWith(isActive: val ? 1 : 0),
                    connectivity: context.read<ConnectivityProvider>(),
                  );
                },
                activeColor: Colors.black,
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddEditDialog(context, cashier),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Tahrirlash"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _confirmDelete(context, cashier),
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: "O'chirish",
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, [AppUser? cashier]) {
    final nameController = TextEditingController(text: cashier?.name);
    final pinController = TextEditingController(text: cashier?.pin);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(cashier == null ? "Yangi Kassir" : "Tahrirlash"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Ism",
                hintText: "Masalan: Azizbek",
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: "PIN kod",
                hintText: "Masalan: 5555",
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Bekor qilish"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || pinController.text.isEmpty) {
                return;
              }

              final provider = context.read<UserProvider>();
              if (cashier == null) {
                await provider.addUser(
                  AppUser(
                    name: nameController.text,
                    pin: pinController.text,
                    role: 'cashier',
                  ),
                  connectivity: context.read<ConnectivityProvider>(),
                );
              } else {
                await provider.updateUser(
                  cashier.copyWith(
                    name: nameController.text,
                    pin: pinController.text,
                  ),
                  connectivity: context.read<ConnectivityProvider>(),
                );
              }

              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppUser cashier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("O'chirishni tasdiqlang"),
        content: Text("${cashier.name}ni tizimdan o'chirib tashlamoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yo'q"),
          ),
          TextButton(
            onPressed: () async {
              final success = await context.read<UserProvider>().deleteUser(
                cashier.id!,
                connectivity: context.read<ConnectivityProvider>(),
              );
              if (context.mounted) {
                Navigator.pop(context);
                if (!success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("O'chirib bo'lmadi!"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              "Ha, o'chirilsin",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
