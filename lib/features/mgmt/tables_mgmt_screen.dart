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
                    initialValue: filterLocationId,
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
            color: theme.colorScheme.onSurface.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            "Stollar topilmadi",
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
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
