import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/waiter_provider.dart';
import '../../models/waiter.dart';
import '../../core/app_strings.dart';
import './waiter_profile_screen.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/ai_action_button.dart';
import '../../providers/ai_provider.dart';

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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.waiterMgmt,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                AiActionButton(
                  onAnalyze: () {
                    final now = DateTime.now();
                    final from = now.subtract(const Duration(days: 30));
                    context.read<AiProvider>().getWaiterAnalysis(from, now);
                  },
                  label: AppStrings.aiAnalysis,
                  dialogTitle: AppStrings.staffAnalysis,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showWaiterDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text(AppStrings.addWaiter),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: AppStrings.searchWaiterHint,
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? const Color(0xFFF1F5F9)
                          : theme.colorScheme.onSurface.withOpacity(0.05),
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
                    initialValue: filterType,
                    dropdownColor: theme.colorScheme.surface,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? const Color(0xFFF1F5F9)
                          : theme.colorScheme.onSurface.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    hint: Text(AppStrings.allTypes),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(AppStrings.allTypes),
                      ),
                      DropdownMenuItem(
                        value: 0,
                        child: Text(AppStrings.fixedLabel),
                      ),
                      DropdownMenuItem(
                        value: 1,
                        child: Text(AppStrings.percentageLabel),
                      ),
                      DropdownMenuItem(value: 2, child: Text(AppStrings.kassa)),
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
                          MediaQuery.of(context).size.width <= 1100 ? 200 : 240,
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.noWaitersFound,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiterCard(BuildContext context, Waiter waiter, bool isAdmin) {
    final bool isKassa = waiter.name == "Kassa";
    String typeLabel = isKassa
        ? AppStrings.kassa
        : (waiter.type == 0 ? AppStrings.fixed : AppStrings.percentage);
    Color typeColor = isKassa
        ? Colors.teal
        : (waiter.type == 0 ? Colors.indigo : Colors.orange);

    String valueText = "";
    if (!isKassa) {
      valueText = waiter.type == 0
          ? "${waiter.value.toStringAsFixed(0)} so'm"
          : "${waiter.value}%";
    } else {
      valueText = AppStrings.primaryStaff;
    }

    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.onSurface.withOpacity(0.1),
        ),
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
            padding: const EdgeInsets.all(12),
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
                              ? 15
                              : 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
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
                            size: 20,
                          ),
                          onPressed: () =>
                              _showWaiterDialog(context, waiter: waiter),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        if (!isKassa && isAdmin) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                _confirmDelete(context, waiter, isAdmin),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                Text(
                  valueText,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (!isKassa && waiter.pinCode != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'PIN: ${waiter.pinCode}',
                      style: const TextStyle(
                        fontSize: 11,
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
                        size: 18,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Waiter waiter, bool isAdmin) async {
    final waiterProvider = context.read<WaiterProvider>();
    final success = await waiterProvider.deleteWaiter(
      waiter.id!,
      isAdmin: isAdmin,
      connectivity: context.read<ConnectivityProvider>(),
    );

    if (!context.mounted) return;

    if (!success) {
      String errorMsg = AppStrings.waiterHasOrdersError;
      if (!isAdmin) {
        errorMsg = AppStrings.adminOnlyError;
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
        SnackBar(
          content: Text(AppStrings.waiterDeletedSuccess),
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
    List<String> selectedPermissions = List.from(waiter?.permissions ?? []);

    final List<Map<String, String>> availablePermissions = [
      {'id': 'delete_item', 'label': AppStrings.permDeleteItem},
      {'id': 'print_receipt', 'label': AppStrings.permPrintReceipt},
      {'id': 'edit_price', 'label': AppStrings.permEditPrice},
      {'id': 'change_table', 'label': AppStrings.permChangeTable},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;

          InputDecoration modernDecoration(
            String label,
            IconData icon, {
            String? hint,
          }) {
            return InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(
                icon,
                color: theme.colorScheme.primary.withOpacity(0.7),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.grey.shade50,
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Header ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            waiter == null ? Icons.person_add : Icons.edit_note,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          waiter == null
                              ? AppStrings.addWaiter
                              : AppStrings.editWaiter,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),

                  // --- Content ---
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Base Info Section
                          Text(
                            "Asosiy ma'lumotlar",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            enabled: !isKassa,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: modernDecoration(
                              AppStrings.waiterName,
                              Icons.person_outline,
                            ),
                          ),

                          if (!isKassa) ...[
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              value: selectedType,
                              dropdownColor: theme.colorScheme.surface,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: modernDecoration(
                                AppStrings.waiterType,
                                Icons.category_outlined,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              items: [
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text(AppStrings.fixed),
                                ),
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
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: modernDecoration(
                                selectedType == 0
                                    ? AppStrings.serviceFeeFixed
                                    : AppStrings.serviceFeePercentage,
                                Icons.payments_outlined,
                                hint: selectedType == 0
                                    ? AppStrings.exampleFixed
                                    : AppStrings.examplePercentage,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: pinController,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                              decoration: modernDecoration(
                                AppStrings.pinCodeLabel,
                                Icons.vibration_outlined,
                                hint: AppStrings.digitsOnlyHint,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SwitchListTile(
                                title: Text(
                                  AppStrings.activeStaff,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                value: isActive == 1,
                                onChanged: (val) => setDialogState(
                                  () => isActive = val ? 1 : 0,
                                ),
                                contentPadding: EdgeInsets.zero,
                                activeColor: theme.colorScheme.primary,
                              ),
                            ),

                            const SizedBox(height: 24),
                            // Permissions Section
                            Text(
                              AppStrings.permissions.toUpperCase(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: availablePermissions.map((perm) {
                                  final isSelected = selectedPermissions
                                      .contains(perm['id']);
                                  return CheckboxListTile(
                                    title: Text(
                                      perm['label']!,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    value: isSelected,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) {
                                          selectedPermissions.add(perm['id']!);
                                        } else {
                                          selectedPermissions.remove(
                                            perm['id'],
                                          );
                                        }
                                      });
                                    },
                                    dense: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: theme.colorScheme.primary,
                                    checkboxShape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // --- Footer ---
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              AppStrings.cancel,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              if (nameController.text.isEmpty && !isKassa)
                                return;
                              final newWaiter = Waiter(
                                id: waiter?.id,
                                name: nameController.text,
                                type: isKassa ? 0 : selectedType,
                                value: isKassa
                                    ? 0.0
                                    : (double.tryParse(valueController.text) ??
                                          0.0),
                                pinCode: isKassa
                                    ? null
                                    : pinController.text.isEmpty
                                    ? null
                                    : pinController.text,
                                isActive: isActive,
                                permissions: selectedPermissions,
                              );
                              if (waiter == null) {
                                context.read<WaiterProvider>().addWaiter(
                                  newWaiter,
                                  connectivity: context
                                      .read<ConnectivityProvider>(),
                                );
                              } else {
                                context.read<WaiterProvider>().updateWaiter(
                                  newWaiter,
                                  connectivity: context
                                      .read<ConnectivityProvider>(),
                                );
                              }
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              AppStrings.save,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
