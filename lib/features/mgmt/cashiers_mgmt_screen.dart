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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kassirlar Boshqaruvi'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text("Yangi Kassir"),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
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
          ? _buildEmptyState(context)
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "Kassirlar topilmadi",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tizimga yangi kassir qo'shish uchun yuqoridagi tugmani bosing",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashierCard(BuildContext context, AppUser cashier) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.04),
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
                  color: theme.colorScheme.onSurface.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline,
                  color: theme.colorScheme.onSurface,
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "PIN: ${cashier.pin}",
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                activeColor: theme.colorScheme.primary,
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
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
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
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            cashier == null ? "Yangi Kassir" : "Tahrirlash",
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: "Ism",
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  hintText: "Masalan: Azizbek",
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: "PIN kod",
                  labelStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  hintText: "Masalan: 5555",
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
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
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text("Saqlash"),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, AppUser cashier) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            "O'chirishni tasdiqlang",
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
          content: Text(
            "${cashier.name}ni tizimdan o'chirib tashlamoqchimisiz?",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
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
        );
      },
    );
  }
}
