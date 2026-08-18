import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/waiter_provider.dart';
import '../../models/waiter.dart';
import '../../core/app_strings.dart';
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
      final isKassa = w.name == 'Kassa';

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
                OutlinedButton.icon(
                  onPressed: () => _showBulkDialog(context),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Ommaviy o\'zgartirish'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6C5CE7),
                    side: const BorderSide(color: Color(0xFF6C5CE7)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: theme.brightness == Brightness.light
                          ? const Color(0xFFF1F5F9)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
                          : theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.noWaitersFound,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiterCard(BuildContext context, Waiter waiter, bool isAdmin) {
    final bool isKassa = waiter.name == 'Kassa';
    String typeLabel = isKassa
        ? AppStrings.kassa
        : (waiter.type == 0 ? AppStrings.fixed : AppStrings.percentage);
    Color typeColor = isKassa
        ? Colors.teal
        : (waiter.type == 0 ? Colors.indigo : Colors.orange);

    String valueText = '';
    if (!isKassa) {
      valueText = waiter.type == 0
          ? "${waiter.value.toStringAsFixed(0)} so'm"
          : '${waiter.value}%';
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
            color: theme.shadowColor.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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

  void _showBulkDialog(BuildContext context) {
    final waiterProvider = context.read<WaiterProvider>();
    final nonKassa = waiterProvider.waiters.where((w) => w.name != 'Kassa').toList();
    if (nonKassa.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xodimlar mavjud emas')),
      );
      return;
    }

    int selectedType = 1;
    int? bulkFilter;
    final valueController = TextEditingController();
    bool isLoading = false;
    final Map<String, bool?> permStates = {}; // null=unchanged, true=add, false=remove

    const perms = [
      {'id': 'perm_confirm_order', 'label': 'Buyurtmani tasdiqlash'},
      {'id': 'delete_item', 'label': 'Taomni o\'chirish'},
      {'id': 'reduce_item', 'label': 'Miqdorni kamaytirish'},
      {'id': 'print_receipt', 'label': 'Chek chiqarish'},
      {'id': 'perm_edit_price', 'label': 'Narxni o\'zgartirish'},
      {'id': 'perm_manage_tables', 'label': 'Stol almashtirish'},
      {'id': 'perm_checkout', 'label': 'Hisob-kitob qilish'},
      {'id': 'perm_view_reports', 'label': 'Hisobotlarni ko\'rish'},
      {'id': 'perm_manage_expenses', 'label': 'Xarajatlarni boshqarish'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 2,
        child: StatefulBuilder(
          builder: (ctx, setS) {
            final theme = Theme.of(ctx);
            final isDark = theme.brightness == Brightness.dark;
            final affected = bulkFilter == null
                ? nonKassa.length
                : nonKassa.where((w) => w.type == bulkFilter).length;

            Widget filterChips() => Row(
              children: [
                _bulkChip(ctx, label: 'Barchasi', selected: bulkFilter == null, onTap: () => setS(() => bulkFilter = null)),
                const SizedBox(width: 8),
                _bulkChip(ctx, label: 'Foizlilar', selected: bulkFilter == 1, onTap: () => setS(() => bulkFilter = 1)),
                const SizedBox(width: 8),
                _bulkChip(ctx, label: 'Fiksedlar', selected: bulkFilter == 0, onTap: () => setS(() => bulkFilter = 0)),
              ],
            );

            Widget affectedBanner() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF6C5CE7)),
                  const SizedBox(width: 8),
                  Text(
                    '$affected ta xodimga qo\'llanadi',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF6C5CE7)),
                  ),
                ],
              ),
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 480,
                constraints: const BoxConstraints(maxHeight: 680),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF6C5CE7),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Ommaviy o\'zgartirish',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: const Icon(Icons.close, color: Colors.white),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    // TabBar
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF6C5CE7).withValues(alpha: 0.08)
                            : const Color(0xFF6C5CE7).withValues(alpha: 0.04),
                        border: Border(
                          bottom: BorderSide(
                            color: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      child: TabBar(
                        tabs: const [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.percent_rounded, size: 15),
                                SizedBox(width: 6),
                                Text('Komissiya'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded, size: 15),
                                SizedBox(width: 6),
                                Text('Ruxsatlar'),
                              ],
                            ),
                          ),
                        ],
                        labelColor: const Color(0xFF6C5CE7),
                        unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                        indicatorColor: const Color(0xFF6C5CE7),
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                      ),
                    ),

                    // Tab content
                    Flexible(
                      child: TabBarView(
                        children: [
                          // ─── Tab 1: Komissiya ───
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kimga qo\'llansin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                const SizedBox(height: 8),
                                filterChips(),
                                const SizedBox(height: 18),
                                Text('Yangi hisoblash turi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setS(() => selectedType = 1),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: selectedType == 1
                                                ? const Color(0xFF6C5CE7).withValues(alpha: 0.1)
                                                : theme.colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: selectedType == 1 ? const Color(0xFF6C5CE7) : Colors.transparent, width: 1.5),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.percent_rounded, size: 22, color: selectedType == 1 ? const Color(0xFF6C5CE7) : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                              const SizedBox(height: 4),
                                              Text('Foiz (%)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selectedType == 1 ? const Color(0xFF6C5CE7) : theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setS(() => selectedType = 0),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: selectedType == 0
                                                ? const Color(0xFFE17055).withValues(alpha: 0.1)
                                                : theme.colorScheme.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: selectedType == 0 ? const Color(0xFFE17055) : Colors.transparent, width: 1.5),
                                          ),
                                          child: Column(
                                            children: [
                                              Icon(Icons.attach_money_rounded, size: 22, color: selectedType == 0 ? const Color(0xFFE17055) : theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                              const SizedBox(height: 4),
                                              Text('Fiksed (so\'m)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selectedType == 0 ? const Color(0xFFE17055) : theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: valueController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: InputDecoration(
                                    labelText: selectedType == 1 ? 'Foiz miqdori (masalan: 10)' : 'Fiksed summa (masalan: 50000)',
                                    suffixText: selectedType == 1 ? '%' : 'so\'m',
                                    prefixIcon: Icon(
                                      selectedType == 1 ? Icons.percent_rounded : Icons.attach_money_rounded,
                                      color: selectedType == 1 ? const Color(0xFF6C5CE7) : const Color(0xFFE17055),
                                      size: 20,
                                    ),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: selectedType == 1 ? const Color(0xFF6C5CE7) : const Color(0xFFE17055), width: 1.5),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                affectedBanner(),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading ? null : () async {
                                      final val = double.tryParse(valueController.text.trim());
                                      if (val == null || val <= 0) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(content: Text('To\'g\'ri qiymat kiriting'), backgroundColor: Colors.red),
                                        );
                                        return;
                                      }
                                      setS(() => isLoading = true);
                                      final err = await waiterProvider.bulkUpdateCommission(type: selectedType, value: val, onlyCurrentType: bulkFilter);
                                      if (!ctx.mounted) return;
                                      setS(() => isLoading = false);
                                      if (err != null) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                                      } else {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$affected ta xodim yangilandi'), backgroundColor: Colors.green),
                                        );
                                      }
                                    },
                                    icon: isLoading
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('QO\'LLASH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6C5CE7),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ─── Tab 2: Ruxsatlar ───
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kimga qo\'llansin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                const SizedBox(height: 8),
                                filterChips(),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Text('Ruxsatlarni tanlang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                    const Spacer(),
                                    // legend
                                    Row(
                                      children: [
                                        Icon(Icons.add_circle_rounded, size: 13, color: const Color(0xFF00B894).withValues(alpha: 0.8)),
                                        const SizedBox(width: 3),
                                        Text('Qo\'sh', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                                        const SizedBox(width: 10),
                                        Icon(Icons.remove_circle_rounded, size: 13, color: const Color(0xFFE17055).withValues(alpha: 0.8)),
                                        const SizedBox(width: 3),
                                        Text('O\'chir', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.07)),
                                  ),
                                  child: Column(
                                    children: perms.asMap().entries.map((entry) {
                                      final i = entry.key;
                                      final perm = entry.value;
                                      final id = perm['id']!;
                                      final state = permStates[id];
                                      final isLast = i == perms.length - 1;
                                      final isFirst = i == 0;

                                      final Color stateColor = state == true
                                          ? const Color(0xFF00B894)
                                          : state == false
                                              ? const Color(0xFFE17055)
                                              : theme.colorScheme.onSurface.withValues(alpha: 0.25);
                                      final IconData stateIcon = state == true
                                          ? Icons.add_circle_rounded
                                          : state == false
                                              ? Icons.remove_circle_rounded
                                              : Icons.radio_button_unchecked_rounded;

                                      return ClipRRect(
                                        borderRadius: BorderRadius.vertical(
                                          top: isFirst ? const Radius.circular(14) : Radius.zero,
                                          bottom: isLast ? const Radius.circular(14) : Radius.zero,
                                        ),
                                        child: InkWell(
                                          onTap: () => setS(() {
                                            if (state == null) {
                                              permStates[id] = true;
                                            } else if (state == true) {
                                              permStates[id] = false;
                                            } else {
                                              permStates.remove(id);
                                            }
                                          }),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                            decoration: BoxDecoration(
                                              color: state == true
                                                  ? const Color(0xFF00B894).withValues(alpha: 0.05)
                                                  : state == false
                                                      ? const Color(0xFFE17055).withValues(alpha: 0.05)
                                                      : Colors.transparent,
                                              border: isLast ? null : Border(
                                                bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                AnimatedSwitcher(
                                                  duration: const Duration(milliseconds: 180),
                                                  child: Icon(stateIcon, key: ValueKey(state), size: 20, color: stateColor),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    perm['label']!,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w500,
                                                      color: theme.colorScheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                if (state != null)
                                                  AnimatedContainer(
                                                    duration: const Duration(milliseconds: 150),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: stateColor.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      state == true ? 'QO\'SHILADI' : 'O\'CHIRILADI',
                                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: stateColor),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.touch_app_outlined, size: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Bosing: o\'zgarmaydi → qo\'shiladi → o\'chiriladi',
                                      style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                affectedBanner(),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: isLoading ? null : () async {
                                      final toAdd = permStates.entries.where((e) => e.value == true).map((e) => e.key).toList();
                                      final toRemove = permStates.entries.where((e) => e.value == false).map((e) => e.key).toList();
                                      if (toAdd.isEmpty && toRemove.isEmpty) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(content: Text('Hech qanday o\'zgartirish tanlanmadi')),
                                        );
                                        return;
                                      }
                                      setS(() => isLoading = true);
                                      final err = await waiterProvider.bulkUpdatePermissions(add: toAdd, remove: toRemove, onlyCurrentType: bulkFilter);
                                      if (!ctx.mounted) return;
                                      setS(() => isLoading = false);
                                      if (err != null) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                                      } else {
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('$affected ta xodim ruxsatlari yangilandi'), backgroundColor: Colors.green),
                                        );
                                      }
                                    },
                                    icon: isLoading
                                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('RUXSATLARNI QO\'LLASH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00B894),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }

  Widget _bulkChip(BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF6C5CE7) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? const Color(0xFF6C5CE7)
                : theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  void _showWaiterDialog(BuildContext context, {Waiter? waiter}) {
    final nameController = TextEditingController(text: waiter?.name ?? '');
    final valueController = TextEditingController(
      text: waiter?.value.toString() ?? '',
    );
    final pinController = TextEditingController(text: waiter?.pinCode ?? '');
    int selectedType = waiter?.type ?? 0;
    int isActive = waiter?.isActive ?? 1;
    bool isKassa = waiter?.name == 'Kassa';
    List<String> selectedPermissions = List.from(waiter?.permissions ?? []);

    final List<Map<String, String>> availablePermissions = [
      {'id': 'perm_confirm_order', 'label': 'Buyurtmani tasdiqlash'},
      {'id': 'delete_item', 'label': 'Taomni o\'chirish'},
      {'id': 'reduce_item', 'label': 'Miqdorni kamaytirish'},
      {'id': 'print_receipt', 'label': 'Chek chiqarish'},
      {'id': 'perm_edit_price', 'label': 'Narxni o\'zgartirish'},
      {'id': 'perm_manage_tables', 'label': 'Stol almashtirish'},
      {'id': 'perm_checkout', 'label': 'Hisob-kitob qilish'},
      {'id': 'perm_view_reports', 'label': 'Hisobotlarni ko\'rish'},
      {'id': 'perm_manage_expenses', 'label': 'Xarajatlarni boshqarish'},
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
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade50,
              labelStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
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
                    color: Colors.black.withValues(alpha: 0.2),
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
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                              initialValue: selectedType,
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
                                    ? Colors.white.withValues(alpha: 0.05)
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
                                activeThumbColor: theme.colorScheme.primary,
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
                                    ? Colors.white.withValues(alpha: 0.05)
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
                            onPressed: () async {
                              if (nameController.text.isEmpty && !isKassa) {
                                return;
                              }
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
                              final connectivity =
                                  context.read<ConnectivityProvider>();
                              final waiterProv =
                                  context.read<WaiterProvider>();
                              final error = waiter == null
                                  ? await waiterProv.addWaiter(newWaiter,
                                      connectivity: connectivity)
                                  : await waiterProv.updateWaiter(newWaiter,
                                      connectivity: connectivity);
                              if (error != null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(error),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                                return;
                              }
                              if (context.mounted) Navigator.pop(context);
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
