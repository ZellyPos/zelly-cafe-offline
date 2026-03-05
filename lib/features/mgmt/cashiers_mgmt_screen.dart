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
              if (cashier.permissions != null &&
                  cashier.permissions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: "Ruxsatlar belgilangan",
                    child: Icon(
                      Icons.security_rounded,
                      size: 18,
                      color: theme.colorScheme.primary.withOpacity(0.7),
                    ),
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
                activeThumbColor: theme.colorScheme.primary,
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
    List<String> selectedPermissions =
        cashier?.permissions?.split(',').where((p) => p.isNotEmpty).toList() ??
        [];

    final availablePermissions = {
      'perm_confirm_order': 'Tasdiqlash',
      'perm_delete_item': "Taomni o'chirish",
      'perm_add_item': "Taom qo'shish",
      'perm_edit_price': "Narxni o'zgartirish",
      'perm_manage_products': "Yangi taom qo'shish",
      'perm_apply_discount': 'Chegirma qo\'llash',
      'perm_checkout': 'Hisob-kitob (Checkout)',
      'perm_view_reports': 'Hisobotlar',
      'perm_manage_expenses': 'Xarajatlar',
      'perm_cancel_order': 'Buyurtmani bekor qilish',
      'perm_manage_shifts': 'Smenani yopish',
      'perm_manage_tables': 'Stollarni boshqarish',
    };

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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Ruxsatlar:",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 250,
                width: 400,
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return ListView(
                      shrinkWrap: true,
                      children: availablePermissions.entries.map((entry) {
                        return CheckboxListTile(
                          title: Text(
                            entry.value,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          value: selectedPermissions.contains(entry.key),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                selectedPermissions.add(entry.key);
                              } else {
                                selectedPermissions.remove(entry.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    );
                  },
                ),
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
                final permsString = selectedPermissions.join(',');

                if (cashier == null) {
                  await provider.addUser(
                    AppUser(
                      name: nameController.text,
                      pin: pinController.text,
                      role: 'cashier',
                      permissions: permsString,
                    ),
                    connectivity: context.read<ConnectivityProvider>(),
                  );
                } else {
                  await provider.updateUser(
                    cashier.copyWith(
                      name: nameController.text,
                      pin: pinController.text,
                      permissions: permsString,
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
