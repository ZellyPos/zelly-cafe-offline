import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/printer_settings.dart';
import '../../core/theme.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrinterProvider>().loadSettings();
      context.read<CategoryProvider>().loadCategories();
      context.read<PrinterProvider>().scanPrinters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Printerlar boshqaruvi'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showPrinterDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Printer qo\'shish'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
      body: provider.isLoading && provider.printers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (provider.printers.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.print_disabled,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Hali hech qanday printer qo\'shilmagan',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: provider.printers.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final printer = provider.printers[index];
                        return _buildPrinterCard(context, printer);
                      },
                    ),
                  ),
                _buildInfoSection(),
              ],
            ),
    );
  }

  Widget _buildPrinterCard(BuildContext context, PrinterSettings printer) {
    final categories = context.read<CategoryProvider>().categories;
    final assignedCats = categories
        .where((c) => printer.categoryIds.contains(c.id))
        .map((c) => c.name)
        .join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              printer.type == PrinterType.network
                  ? Icons.lan_outlined
                  : Icons.usb_outlined,
              color: AppTheme.primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  printer.displayName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  printer.type == PrinterType.network
                      ? 'IP: ${printer.ipAddress}:${printer.port}'
                      : 'USB: ${printer.printerName}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                ),
                if (printer.categoryIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Kategoriyalar: $assignedCats',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _testPrinter(context, printer),
            icon: const Icon(Icons.print_outlined),
            color: Colors.blue,
            tooltip: 'Test print',
          ),
          IconButton(
            onPressed: () => _showPrinterDialog(context, printer),
            icon: const Icon(Icons.edit_outlined),
            color: Colors.grey[700],
          ),
          IconButton(
            onPressed: () => _deletePrinter(context, printer),
            icon: const Icon(Icons.delete_outline),
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Printerlarni kategoriyalar bo‘yicha ajatsangiz, buyurtmalar avtomatik ravishda tegishli departamentlarga (oshxona, bar va h.k.) yuboriladi.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrinterDialog(
    BuildContext context, [
    PrinterSettings? printer,
  ]) async {
    final isEdit = printer != null;
    final ipController = TextEditingController(text: printer?.ipAddress ?? '');
    final portController = TextEditingController(
      text: printer?.port.toString() ?? '9100',
    );
    final nameController = TextEditingController(
      text: printer?.displayName ?? 'Yangi printer',
    );
    PrinterType selectedType = printer?.type ?? PrinterType.network;
    String? selectedPrinterName = printer?.printerName;
    List<int> selectedCategoryIds = List.from(printer?.categoryIds ?? []);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final categories = context.read<CategoryProvider>().categories;
          final provider = context.watch<PrinterProvider>();

          return AlertDialog(
            title: Text(isEdit ? 'Printerni tahrirlash' : 'Yangi printer'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Printer nomi',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildTypeChoice(
                          'IP Network',
                          PrinterType.network,
                          selectedType,
                          (val) => setDialogState(() => selectedType = val),
                        ),
                        const SizedBox(width: 12),
                        _buildTypeChoice(
                          'USB Windows',
                          PrinterType.windows,
                          selectedType,
                          (val) => setDialogState(() => selectedType = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (selectedType == PrinterType.network) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ipController,
                              decoration: const InputDecoration(
                                labelText: 'IP manzil',
                                hintText: '192.168.1.100',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: TextField(
                              controller: portController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const Text(
                        'Printer tanlang:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      provider.windowsPrinters.isEmpty
                          ? const Text('Printerlar topilmadi')
                          : Wrap(
                              spacing: 8,
                              children: provider.windowsPrinters.map((name) {
                                final isSel = selectedPrinterName == name;
                                return ChoiceChip(
                                  label: Text(name),
                                  selected: isSel,
                                  onSelected: (val) => setDialogState(
                                    () => selectedPrinterName = name,
                                  ),
                                );
                              }).toList(),
                            ),
                      TextButton.icon(
                        onPressed: () => provider.scanPrinters(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Qayta qidirish'),
                      ),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Kategoriyalarni biriktirish:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((cat) {
                        final isSel = selectedCategoryIds.contains(cat.id);
                        return FilterChip(
                          label: Text(cat.name),
                          selected: isSel,
                          onSelected: (val) {
                            setDialogState(() {
                              if (val) {
                                selectedCategoryIds.add(cat.id!);
                              } else {
                                selectedCategoryIds.remove(cat.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Bekor qilish'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newPrinter = (printer ?? PrinterSettings()).copyWith(
                    displayName: nameController.text,
                    type: selectedType,
                    ipAddress: ipController.text,
                    port: int.tryParse(portController.text) ?? 9100,
                    printerName: selectedPrinterName,
                    categoryIds: selectedCategoryIds,
                  );
                  await context.read<PrinterProvider>().savePrinter(newPrinter);
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Saqlash'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTypeChoice(
    String label,
    PrinterType type,
    PrinterType selected,
    Function(PrinterType) onSelect,
  ) {
    final isSel = type == selected;
    return Expanded(
      child: InkWell(
        onTap: () => onSelect(type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel
                ? AppTheme.primaryColor.withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? AppTheme.primaryColor : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                color: isSel ? AppTheme.primaryColor : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _testPrinter(BuildContext context, PrinterSettings printer) async {
    final result = await context.read<PrinterProvider>().testPrint(printer);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result ? 'Test chek chiqarildi!' : 'Xatolik yuz berdi.',
          ),
          backgroundColor: result ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _deletePrinter(BuildContext context, PrinterSettings printer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Printerni o\'chirish'),
        content: Text(
          'Rostdan ham "${printer.displayName}" printerni o\'chirib tashlamoqchimisiz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Yo\'q'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ha, o\'chirish',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<PrinterProvider>().deletePrinter(printer.id!);
    }
  }
}
