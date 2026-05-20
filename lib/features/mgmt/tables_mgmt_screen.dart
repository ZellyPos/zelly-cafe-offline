import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/table_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/table.dart';
import '../../models/location.dart';
import '../../core/app_strings.dart';
import '../../providers/connectivity_provider.dart';

class TablesMgmtScreen extends StatefulWidget {
  const TablesMgmtScreen({super.key});

  @override
  State<TablesMgmtScreen> createState() => _TablesMgmtScreenState();
}

class _TablesMgmtScreenState extends State<TablesMgmtScreen> {
  String searchQuery = '';
  int? filterLocationId;

  @override
  Widget build(BuildContext context) {
    final tableProvider = context.watch<TableProvider>();
    final locationProvider = context.watch<LocationProvider>();

    final filteredTables = tableProvider.tables.where((t) {
      final matchesSearch = t.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      final matchesLocation =
          filterLocationId == null || t.locationId == filterLocationId;
      return matchesSearch && matchesLocation;
    }).toList();

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.tableMgmt,
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
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showBulkEditDialog(context),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Ommaviy tahrirlash'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EA5E9),
                side: const BorderSide(color: Color(0xFF0EA5E9)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton.icon(
              onPressed: () => _showBulkAddDialog(context),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Ommaviy qo\'shish'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
                side: const BorderSide(color: Color(0xFF8B5CF6)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showTableDialog(context),
                icon: const Icon(Icons.add),
                label: Text(AppStrings.addTable),
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
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: "Stol nomi bo'yicha qidirish...",
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
                    initialValue: filterLocationId,
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
                    hint: const Text("Barcha joylar"),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text("Barcha joylar"),
                      ),
                      ...locationProvider.locations.map(
                        (l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.name)),
                      ),
                    ],
                    onChanged: (val) => setState(() => filterLocationId = val),
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: tableProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTables.isEmpty
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
                    itemCount: filteredTables.length,
                    itemBuilder: (context, index) {
                      final table = filteredTables[index];
                      final location = locationProvider.locations.firstWhere(
                        (l) => l.id == table.locationId,
                        orElse: () => Location(name: 'Nomalum'),
                      );
                      return _buildTableCard(context, table, location);
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
            Icons.table_bar_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "Stollar topilmadi",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(
    BuildContext context,
    TableModel table,
    Location location,
  ) {
    String pricingLabel = "Normal";
    Color pricingColor = Colors.grey;
    if (table.pricingType == 1) {
      pricingLabel = "Soatli";
      pricingColor = Colors.orange;
    } else if (table.pricingType == 2) {
      pricingLabel = "Fiksal";
      pricingColor = Colors.purple;
    } else if (table.pricingType == 3) {
      pricingLabel = "Foizli";
      pricingColor = Colors.teal;
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
          onTap: () => _showTableDialog(context, table: table),
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
                        table.name,
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
                              _showTableDialog(context, table: table),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _confirmDelete(context, table),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                Text(
                  location.name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                const Spacer(),
                Row(
                  children: [
                    _buildBadge(pricingLabel, pricingColor),
                    const SizedBox(width: 4),
                    _buildBadge(
                      table.status == 0 ? "Bo'sh" : "Band",
                      table.status == 0 ? Colors.green : Colors.red,
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

  void _confirmDelete(BuildContext context, TableModel table) async {
    final tableProvider = context.read<TableProvider>();
    final success = await tableProvider.deleteTable(
      table.id!,
      connectivity: context.read<ConnectivityProvider>(),
    );

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.warningDeleteTable),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Stol muvaffaqiyatli o'chirildi"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showBulkEditDialog(BuildContext context) {
    final tableProvider = context.read<TableProvider>();
    final locationProvider = context.read<LocationProvider>();
    if (tableProvider.tables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stollar mavjud emas')),
      );
      return;
    }

    int selectedPricingType = 3; // 0=normal,1=soatli,2=fiksal,3=foizli
    int? filterLocationId;
    int? filterCurrentType;
    final valueController = TextEditingController();
    bool isLoading = false;

    // pricing type meta
    const typeItems = [
      {'value': 0, 'label': 'Normal', 'icon': Icons.table_restaurant_rounded, 'color': 0xFF64748B},
      {'value': 1, 'label': 'Soatli', 'icon': Icons.access_time_rounded, 'color': 0xFFE17055},
      {'value': 2, 'label': 'Fiksal', 'icon': Icons.attach_money_rounded, 'color': 0xFF8B5CF6},
      {'value': 3, 'label': 'Foizli', 'icon': Icons.percent_rounded, 'color': 0xFF0EA5E9},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;

          final allTables = tableProvider.tables;
          int affected = allTables.where((t) {
            final locOk = filterLocationId == null || t.locationId == filterLocationId;
            final typeOk = filterCurrentType == null || t.pricingType == filterCurrentType;
            return locOk && typeOk;
          }).length;

          final selMeta = typeItems.firstWhere((m) => m['value'] == selectedPricingType);
          final selColor = Color(selMeta['color'] as int);
          final bool needsValue = selectedPricingType != 0;

          // ── small chip helper ──
          Widget chip({required String label, required bool selected, required VoidCallback onTap, Color? activeColor}) {
            final color = activeColor ?? const Color(0xFF0EA5E9);
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? color : Colors.transparent, width: 1.5),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            );
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 500,
              constraints: const BoxConstraints(maxHeight: 680),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 32, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0EA5E9),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Ommaviy tahrirlash', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                              Text('Bir vaqtda ko\'p stolni yangilash', style: TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
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

                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Location filter ──
                          Text('Joylashuv bo\'yicha filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              chip(label: 'Barcha joylar', selected: filterLocationId == null, onTap: () => setS(() => filterLocationId = null)),
                              ...locationProvider.locations.map((l) =>
                                chip(label: l.name, selected: filterLocationId == l.id, onTap: () => setS(() => filterLocationId = l.id)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Current type filter ──
                          Text('Hozirgi narxlash turi bo\'yicha filter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              chip(label: 'Barchasi', selected: filterCurrentType == null, onTap: () => setS(() => filterCurrentType = null), activeColor: const Color(0xFF64748B)),
                              chip(label: 'Normal', selected: filterCurrentType == 0, onTap: () => setS(() => filterCurrentType = 0), activeColor: const Color(0xFF64748B)),
                              chip(label: 'Soatli', selected: filterCurrentType == 1, onTap: () => setS(() => filterCurrentType = 1), activeColor: const Color(0xFFE17055)),
                              chip(label: 'Fiksal', selected: filterCurrentType == 2, onTap: () => setS(() => filterCurrentType = 2), activeColor: const Color(0xFF8B5CF6)),
                              chip(label: 'Foizli', selected: filterCurrentType == 3, onTap: () => setS(() => filterCurrentType = 3), activeColor: const Color(0xFF0EA5E9)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── New pricing type ──
                          Text('Yangi narxlash turi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          const SizedBox(height: 10),
                          Row(
                            children: typeItems.map((meta) {
                              final val = meta['value'] as int;
                              final label = meta['label'] as String;
                              final iconData = meta['icon'] as IconData;
                              final color = Color(meta['color'] as int);
                              final isSelected = selectedPricingType == val;
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: () => setS(() => selectedPricingType = val),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 150),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? color.withValues(alpha: 0.1) : theme.colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: isSelected ? color : Colors.transparent, width: 1.5),
                                      ),
                                      child: Column(
                                        children: [
                                          Icon(iconData, size: 20, color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.35)),
                                          const SizedBox(height: 4),
                                          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? color : theme.colorScheme.onSurface.withValues(alpha: 0.45))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),

                          // ── Value input (hidden for Normal) ──
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 200),
                            crossFadeState: needsValue ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                            firstChild: TextField(
                              controller: valueController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                labelText: selectedPricingType == 1
                                    ? 'Soatbay narx (so\'m)'
                                    : selectedPricingType == 2
                                        ? 'Fiksal narx (so\'m)'
                                        : 'Xizmat foizi (%)',
                                suffixText: selectedPricingType == 3 ? '%' : 'so\'m',
                                prefixIcon: Icon(selMeta['icon'] as IconData, color: selColor, size: 20),
                                filled: true,
                                fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: selColor, width: 1.5)),
                              ),
                            ),
                            secondChild: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64748B).withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text('Normal turda qo\'shimcha narx yo\'q', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Affected banner ──
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0EA5E9).withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF0EA5E9)),
                                const SizedBox(width: 8),
                                Text('$affected ta stolga qo\'llanadi', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0EA5E9))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Apply button ──
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: isLoading ? null : () async {
                                double val = 0;
                                if (needsValue) {
                                  val = double.tryParse(valueController.text.trim()) ?? 0;
                                  if (val <= 0) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(content: Text('To\'g\'ri qiymat kiriting'), backgroundColor: Colors.red),
                                    );
                                    return;
                                  }
                                }
                                setS(() => isLoading = true);
                                final err = await tableProvider.bulkUpdatePricing(
                                  pricingType: selectedPricingType,
                                  value: val,
                                  onlyLocationId: filterLocationId,
                                  onlyCurrentPricingType: filterCurrentType,
                                );
                                if (!ctx.mounted) return;
                                setS(() => isLoading = false);
                                if (err != null) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                                } else {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$affected ta stol yangilandi'), backgroundColor: Colors.green),
                                  );
                                }
                              },
                              icon: isLoading
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.check_rounded, size: 18),
                              label: const Text('QO\'LLASH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  void _showBulkAddDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BulkAddDialog(
        locationProvider: context.read<LocationProvider>(),
        onConfirm: (prefix, start, end, locationId, pricingType,
            hourlyRate, fixedAmount, servicePercentage) async {
          final tableProvider = context.read<TableProvider>();
          final connectivity = context.read<ConnectivityProvider>();

          int done = 0;
          await tableProvider.addTablesBulk(
            prefix: prefix,
            start: start,
            end: end,
            locationId: locationId,
            pricingType: pricingType,
            hourlyRate: hourlyRate,
            fixedAmount: fixedAmount,
            servicePercentage: servicePercentage,
            connectivity: connectivity,
            onProgress: (d, _) => done = d,
          );

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('$done ta stol muvaffaqiyatli qo\'shildi!'),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
            ));
          }
        },
      ),
    );
  }

  void _showTableDialog(BuildContext context, {TableModel? table}) {
    final nameController = TextEditingController(text: table?.name ?? '');
    final hourlyRateController = TextEditingController(
      text: table?.hourlyRate.toString() ?? '0',
    );
    final fixedAmountController = TextEditingController(
      text: table?.fixedAmount.toString() ?? '0',
    );
    final servicePercentageController = TextEditingController(
      text: table?.servicePercentage.toString() ?? '0',
    );
    final locationProvider = context.read<LocationProvider>();

    int? selectedLocationId =
        table?.locationId ??
        (locationProvider.locations.isNotEmpty
            ? locationProvider.locations.first.id
            : null);
    int pricingType = table?.pricingType ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              table == null ? AppStrings.addTable : AppStrings.editTable,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: AppStrings.tableName,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: selectedLocationId,
                    dropdownColor: theme.colorScheme.surface,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: AppStrings.selectLocation,
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: locationProvider.locations
                        .map(
                          (l) => DropdownMenuItem(
                            value: l.id,
                            child: Text(l.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedLocationId = val),
                    validator: (val) => val == null ? "Joyni tanlang" : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: pricingType,
                    dropdownColor: theme.colorScheme.surface,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: "Narxlash turi",
                      labelStyle: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text("Normal (Xona narxisiz)"),
                      ),
                      const DropdownMenuItem(value: 1, child: Text("Soatli")),
                      const DropdownMenuItem(
                        value: 2,
                        child: Text("Fiksal (Fixed)"),
                      ),
                      const DropdownMenuItem(
                        value: 3,
                        child: Text("Xizmat foizi"),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => pricingType = val!),
                  ),
                  if (pricingType == 1) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: hourlyRateController,
                      decoration: InputDecoration(
                        labelText: "Soatbay narx",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (pricingType == 2) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: fixedAmountController,
                      decoration: InputDecoration(
                        labelText: "Fiksal narx",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  if (pricingType == 3) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: servicePercentageController,
                      decoration: InputDecoration(
                        labelText: "Xizmat foizi (%)",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (selectedLocationId == null ||
                      nameController.text.isEmpty) {
                    return;
                  }
                  final newTable = TableModel(
                    id: table?.id,
                    name: nameController.text,
                    locationId: selectedLocationId!,
                    status: table?.status ?? 0,
                    pricingType: pricingType,
                    hourlyRate: double.tryParse(hourlyRateController.text) ?? 0,
                    fixedAmount:
                        double.tryParse(fixedAmountController.text) ?? 0,
                    servicePercentage:
                        double.tryParse(servicePercentageController.text) ?? 0,
                  );
                  if (table == null) {
                    context.read<TableProvider>().addTable(
                      newTable,
                      connectivity: context.read<ConnectivityProvider>(),
                    );
                  } else {
                    context.read<TableProvider>().updateTable(
                      newTable,
                      connectivity: context.read<ConnectivityProvider>(),
                    );
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppStrings.save),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Bulk Add Dialog ──────────────────────────────────────────────────────────
typedef _BulkConfirmCallback = Future<void> Function(
  String prefix,
  int start,
  int end,
  int locationId,
  int pricingType,
  double hourlyRate,
  double fixedAmount,
  double servicePercentage,
);

class _BulkAddDialog extends StatefulWidget {
  final LocationProvider locationProvider;
  final _BulkConfirmCallback onConfirm;

  const _BulkAddDialog({
    required this.locationProvider,
    required this.onConfirm,
  });

  @override
  State<_BulkAddDialog> createState() => _BulkAddDialogState();
}

class _BulkAddDialogState extends State<_BulkAddDialog> {
  final _prefixCtrl = TextEditingController(text: 'Stol');
  int _start = 1;
  int _end = 10;
  int? _locationId;
  int _pricingType = 0;
  final _hourlyCtrl = TextEditingController(text: '0');
  final _fixedCtrl = TextEditingController(text: '0');
  final _serviceCtrl = TextEditingController(text: '0');

  bool _loading = false;
  int _progress = 0;

  static const _presetPrefixes = ['Stol', 'VIP', 'Xona', 'Kabina', ''];

  @override
  void initState() {
    super.initState();
    if (widget.locationProvider.locations.isNotEmpty) {
      _locationId = widget.locationProvider.locations.first.id;
    }
    _prefixCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _hourlyCtrl.dispose();
    _fixedCtrl.dispose();
    _serviceCtrl.dispose();
    super.dispose();
  }

  int get _count => (_end >= _start) ? (_end - _start + 1) : 0;

  List<String> get _previewNames {
    final prefix = _prefixCtrl.text.trim();
    return List.generate(
      _count,
      (i) => prefix.isEmpty ? '${_start + i}' : '$prefix ${_start + i}',
    );
  }

  Widget _numStepper(int value, int min, int max, ValueChanged<int> onChange) {
    final t = Theme.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _stepBtn(Icons.remove_rounded, value > min
          ? () => onChange(value - 1) : null, t),
      SizedBox(
        width: 52,
        child: Text(
          '$value',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      _stepBtn(Icons.add_rounded, value < max
          ? () => onChange(value + 1) : null, t),
    ]);
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap, ThemeData t) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: onTap == null
              ? t.colorScheme.outline.withValues(alpha: 0.08)
              : t.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? t.colorScheme.outline
              : t.colorScheme.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final names = _previewNames;
    final showNames = names.take(18).toList();
    final extra = names.length - showNames.length;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Gradient header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Text('Ommaviy stol qo\'shish',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(
                    _count > 0
                        ? '$_count ta stol qo\'shiladi'
                        : 'Diapazon noto\'g\'ri',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12),
                  ),
                ]),
              ),
              // Big count badge
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey(_count),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$_count',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20),
                  ),
                ),
              ),
            ]),
          ),

          // ── Body ────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                // Prefix presets
                Text('Stol nomi prefiksi',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                Row(children: [
                  ..._presetPrefixes.map((p) {
                    final selected = _prefixCtrl.text.trim() == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(
                            p.isEmpty ? 'Yo\'q' : p,
                            style: TextStyle(
                                fontSize: 12,
                                color: selected
                                    ? Colors.white
                                    : t.colorScheme.onSurface)),
                        selected: selected,
                        selectedColor: const Color(0xFF7C3AED),
                        onSelected: (_) {
                          _prefixCtrl.text = p;
                          _prefixCtrl.selection = TextSelection.collapsed(
                              offset: p.length);
                        },
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _prefixCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Boshqa...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // Number range
                Text('Raqam diapazoni',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: t.colorScheme.onSurface
                            .withValues(alpha: 0.5))),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: Column(children: [
                      Text('DAN',
                          style: TextStyle(
                              fontSize: 10,
                              color: t.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _numStepper(
                        _start, 1, 999,
                        (v) => setState(() {
                          _start = v;
                          if (_end < _start) _end = _start;
                        }),
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: t.colorScheme.outline, size: 20),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text('GACHA',
                          style: TextStyle(
                              fontSize: 10,
                              color: t.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _numStepper(
                        _end, _start, 999,
                        (v) => setState(() => _end = v),
                      ),
                    ]),
                  ),
                  // Quick count chips
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Tez',
                          style: TextStyle(
                              fontSize: 10,
                              color: t.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(children: [
                        for (final n in [5, 10, 20])
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _end = _start + n - 1),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: t.colorScheme.primary
                                      .withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('+$n',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: t.colorScheme.primary)),
                              ),
                            ),
                          ),
                      ]),
                    ],
                  ),
                ]),
                const SizedBox(height: 20),

                // Location + Pricing
                Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Joylashuv',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.colorScheme.onSurface
                                  .withValues(alpha: 0.5))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _locationId,
                        isDense: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: widget.locationProvider.locations
                            .map((l) => DropdownMenuItem(
                                value: l.id, child: Text(l.name)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _locationId = v),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Narxlash turi',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: t.colorScheme.onSurface
                                  .withValues(alpha: 0.5))),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: _pricingType,
                        isDense: true,
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Normal')),
                          DropdownMenuItem(value: 1, child: Text('Soatli')),
                          DropdownMenuItem(value: 2, child: Text('Fiksal')),
                          DropdownMenuItem(value: 3, child: Text('Foizli')),
                        ],
                        onChanged: (v) =>
                            setState(() => _pricingType = v!),
                      ),
                    ]),
                  ),
                ]),
                if (_pricingType == 1) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hourlyCtrl,
                    decoration: InputDecoration(
                      labelText: 'Soatbay narx',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_pricingType == 2) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fixedCtrl,
                    decoration: InputDecoration(
                      labelText: 'Fiksal narx',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (_pricingType == 3) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _serviceCtrl,
                    decoration: InputDecoration(
                      labelText: 'Xizmat foizi (%)',
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 20),

                // Preview chips
                Row(children: [
                  Icon(Icons.preview_rounded,
                      size: 14,
                      color:
                          t.colorScheme.onSurface.withValues(alpha: 0.4)),
                  const SizedBox(width: 6),
                  Text('Ko\'rinish',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: t.colorScheme.onSurface
                              .withValues(alpha: 0.5))),
                ]),
                const SizedBox(height: 8),
                if (_count == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: t.colorScheme.error.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Diapazon noto\'g\'ri: "dan" "gacha"dan katta bo\'lishi kerak',
                      style: TextStyle(
                          fontSize: 12, color: t.colorScheme.error),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF7C3AED)
                              .withValues(alpha: 0.15)),
                    ),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...showNames.map((name) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(name,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF7C3AED))),
                            )),
                        if (extra > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: t.colorScheme.outline
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '+$extra ta ko\'proq',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: t.colorScheme.outline),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Progress bar
                if (_loading) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: _count > 0 ? _progress / _count : 0,
                          backgroundColor:
                              const Color(0xFF7C3AED).withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation(
                              Color(0xFF7C3AED)),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('$_progress / $_count',
                        style: TextStyle(
                            fontSize: 12,
                            color: t.colorScheme.onSurface
                                .withValues(alpha: 0.5))),
                  ]),
                ],
                const SizedBox(height: 20),
              ]),
            ),
          ),

          // ── Actions ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Bekor qilish'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: (_loading || _count == 0 || _locationId == null)
                      ? null
                      : () async {
                          setState(() { _loading = true; _progress = 0; });
                          final nav = Navigator.of(context);
                          await widget.onConfirm(
                            _prefixCtrl.text.trim(),
                            _start,
                            _end,
                            _locationId!,
                            _pricingType,
                            double.tryParse(_hourlyCtrl.text) ?? 0,
                            double.tryParse(_fixedCtrl.text) ?? 0,
                            double.tryParse(_serviceCtrl.text) ?? 0,
                          );
                          if (!mounted) return;
                          nav.pop();
                        },
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(_loading
                      ? 'Yaratilmoqda...'
                      : '$_count ta stol yaratish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
