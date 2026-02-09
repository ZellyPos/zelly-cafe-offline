import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/waiter_provider.dart';
import '../../models/waiter.dart';
import '../../core/app_strings.dart';
import '../../core/theme.dart';
import './waiter_profile_screen.dart';
import '../../providers/connectivity_provider.dart';

class WaitersMgmtScreen extends StatefulWidget {
  const WaitersMgmtScreen({super.key});

  @override
  State<WaitersMgmtScreen> createState() => _WaitersMgmtScreenState();
}

class _WaitersMgmtScreenState extends State<WaitersMgmtScreen> {
  String searchQuery = '';
  int? filterType; // 0 = Fixed, 1 = Percentage, null = All

  @override
  Widget build(BuildContext context) {
    final waiterProvider = context.watch<WaiterProvider>();
    final connectivity = context.watch<ConnectivityProvider>();
    final user = connectivity.currentUser;
    final String role = user?['role'] ?? 'admin';
    final bool isAdmin = role == 'admin';

    final filteredWaiters = waiterProvider.waiters.where((w) {
      final matchesSearch = w.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      final isKassa = w.name == "Kassa";

      bool matchesType = true;
      if (filterType != null) {
        if (filterType == 2) {
          // Kassa filter
          matchesType = isKassa;
        } else {
          matchesType = !isKassa && w.type == filterType;
        }
      }
      return matchesSearch && matchesType;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          AppStrings.waiterMgmt,
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showWaiterDialog(context),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.addWaiter),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Xodim ismi bo'yicha qidirish...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    value: filterType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    hint: const Text("Barcha turlar"),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text("Barcha turlar"),
                      ),
                      DropdownMenuItem(value: 0, child: Text("Fiksal (So'm)")),
                      DropdownMenuItem(value: 1, child: Text("Foizli (%)")),
                      DropdownMenuItem(value: 2, child: Text("Kassa")),
                    ],
                    onChanged: (val) => setState(() => filterType = val),
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: waiterProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredWaiters.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent:
                          MediaQuery.of(context).size.width <= 1100 ? 280 : 350,
                      childAspectRatio:
                          MediaQuery.of(context).size.width <= 1100 ? 1.0 : 1.1,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: filteredWaiters.length,
                    itemBuilder: (context, index) {
                      final waiter = filteredWaiters[index];
                      return _buildWaiterCard(context, waiter, isAdmin);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            "Xodimlar topilmadi",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiterCard(BuildContext context, Waiter waiter, bool isAdmin) {
    final bool isKassa = waiter.name == "Kassa";
    String typeLabel = isKassa
        ? "Kassa"
        : (waiter.type == 0 ? "Fiksal" : "Foizli");
    Color typeColor = isKassa
        ? Colors.teal
        : (waiter.type == 0 ? Colors.indigo : Colors.orange);

    String valueText = "";
    if (!isKassa) {
      valueText = waiter.type == 0
          ? "${waiter.value.toStringAsFixed(0)} so'm"
          : "${waiter.value}%";
    } else {
      valueText = "Asosiy xodim";
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WaiterProfileScreen(waiter: waiter),
              ),
            ).then((_) => setState(() {}));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        waiter.name,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width <= 1100
                              ? 18
                              : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () =>
                              _showWaiterDialog(context, waiter: waiter),
                        ),
                        if (!isKassa && isAdmin)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, waiter, isAdmin),
                          ),
                      ],
                    ),
                  ],
                ),
                Text(
                  valueText,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                if (!isKassa && waiter.pinCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'PIN: ${waiter.pinCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blueGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBadge(typeLabel, typeColor),
                    if (!isKassa)
                      Icon(
                        waiter.isActive == 1
                            ? Icons.check_circle
                            : Icons.cancel,
                        color: waiter.isActive == 1 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Waiter waiter, bool isAdmin) async {
    final waiterProvider = context.read<WaiterProvider>();
    final success = await waiterProvider.deleteWaiter(
      waiter.id!,
      isAdmin: isAdmin,
    );

    if (!context.mounted) return;

    if (!success) {
      String errorMsg = "Ushbu xodimda buyurtmalar mavjud. O'chirish imkonsiz!";
      if (!isAdmin) {
        errorMsg = "Xodimlarni o'chirish huquqi faqat adminga berilgan!";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Xodim muvaffaqiyatli o'chirildi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showWaiterDialog(BuildContext context, {Waiter? waiter}) {
    final nameController = TextEditingController(text: waiter?.name ?? '');
    final valueController = TextEditingController(
      text: waiter?.value.toString() ?? '',
    );
    final pinController = TextEditingController(text: waiter?.pinCode ?? '');
    int selectedType = waiter?.type ?? 0;
    int isActive = waiter?.isActive ?? 1;
    bool isKassa = waiter?.name == "Kassa";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            waiter == null ? AppStrings.addWaiter : AppStrings.editWaiter,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                enabled: !isKassa,
                decoration: InputDecoration(
                  labelText: AppStrings.waiterName,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (!isKassa) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: AppStrings.waiterType,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text(AppStrings.fixed)),
                    DropdownMenuItem(
                      value: 1,
                      child: Text(AppStrings.percentage),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() => selectedType = val!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: selectedType == 0
                        ? "Xizmat haqi (Summa)"
                        : "Xizmat haqi (Foizli %)",
                    hintText: selectedType == 0
                        ? "Masalan: 5000"
                        : "Masalan: 10",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  decoration: InputDecoration(
                    labelText: 'PIN kod (LAN Kirish uchun)',
                    hintText: 'Faqat raqamlar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Faol xodim'),
                  value: isActive == 1,
                  onChanged: (val) =>
                      setDialogState(() => isActive = val ? 1 : 0),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                AppStrings.cancel,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty && !isKassa) return;
                final newWaiter = Waiter(
                  id: waiter?.id,
                  name: nameController.text,
                  type: isKassa ? 0 : selectedType,
                  value: isKassa
                      ? 0.0
                      : (double.tryParse(valueController.text) ?? 0.0),
                  pinCode: isKassa
                      ? null
                      : pinController.text.isEmpty
                      ? null
                      : pinController.text,
                  isActive: isActive,
                );
                if (waiter == null) {
                  context.read<WaiterProvider>().addWaiter(newWaiter);
                } else {
                  context.read<WaiterProvider>().updateWaiter(newWaiter);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      ),
    );
  }
}
