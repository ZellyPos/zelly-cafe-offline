import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/printer_provider.dart';
import '../../models/printer_settings.dart';
import '../../core/theme.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  PrinterType _selectedType = PrinterType.network;
  String? _selectedPrinterName;
  String _lastStatus = 'Noma\'lum';
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PrinterProvider>();
      provider.loadSettings().then((_) {
        setState(() {
          _selectedType = provider.settings.type;
          _ipController.text = provider.settings.ipAddress ?? '';
          _portController.text = provider.settings.port.toString();
          _selectedPrinterName = provider.settings.printerName;
        });
      });
      provider.scanPrinters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PrinterProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),

                  _buildSection(
                    title: '1. Printer rejimi',
                    hint: 'Ulanish usulini tanlang',
                    child: Row(
                      children: [
                        _buildTypeCard(
                          'IP printer (tavsiya)',
                          'Router bo‘lsa eng barqaror usul',
                          Icons.lan_outlined,
                          PrinterType.network,
                        ),
                        const SizedBox(width: 20),
                        _buildTypeCard(
                          'USB printer',
                          'Router bo‘lmasa ishlaydi (RAW)',
                          Icons.usb_outlined,
                          PrinterType.windows,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (_selectedType == PrinterType.network)
                    _buildSection(
                      title: '2. Network sozlamalari',
                      hint: 'Printerning lokal IP manzilini kiriting',
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: _buildTextField(
                                label: 'IP manzil',
                                controller: _ipController,
                                hintText: '192.168.1.100',
                                icon: Icons.settings_ethernet,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              flex: 1,
                              child: _buildTextField(
                                label: 'Port',
                                controller: _portController,
                                hintText: '9100',
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_selectedType == PrinterType.windows)
                    _buildSection(
                      title: '2. USB (Windows) printer',
                      hint: 'Tizimga o\'rnatilgan printerni tanlang',
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            if (provider.isLoading)
                              const Center(child: LinearProgressIndicator())
                            else if (provider.windowsPrinters.isEmpty)
                              const Text(
                                'Printerlar topilmadi. USB ulanishini tekshiring.',
                              )
                            else
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: provider.windowsPrinters.map((name) {
                                  final isSelected =
                                      _selectedPrinterName == name;
                                  return InkWell(
                                    onTap: () => setState(
                                      () => _selectedPrinterName = name,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : const Color(0xFFE2E8F0),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.print_outlined,
                                            size: 18,
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? Colors.white
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => provider.scanPrinters(),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Qayta qidirish'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),

                  _buildSection(
                    title: '3. Holat va Diagnostika',
                    hint: 'Hozirgi sozlamalar qisqacha ma\'lumoti',
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          _buildStatusItem(
                            'Rejim',
                            _selectedType == PrinterType.network
                                ? 'IP Network'
                                : 'USB Windows',
                            Icons.tune,
                          ),
                          const VerticalDivider(width: 40),
                          _buildStatusItem(
                            'Manzil / Nomi',
                            _selectedType == PrinterType.network
                                ? '${_ipController.text}:${_portController.text}'
                                : (_selectedPrinterName ?? 'Tanlanmagan'),
                            Icons.link,
                          ),
                          const VerticalDivider(width: 40),
                          _buildStatusItem(
                            'Oxirgi test',
                            _lastStatus,
                            _isSuccess
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: _isSuccess
                                ? Colors.green
                                : (_lastStatus == 'Noma\'lum'
                                      ? Colors.grey
                                      : Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // Space for sticky bar
                ],
              ),
            ),
          ),
          _buildStickyBar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Printer sozlamalari',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cheklar chiqishi uchun printer ulanishini to‘g‘rilang',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required String hint,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          hint,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildTypeCard(
    String title,
    String subtitle,
    IconData icon,
    PrinterType type,
  ) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primaryColor
                  : const Color(0xFFE2E8F0),
              width: 2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFF64748B),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppTheme.primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    IconData? icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color ?? const Color(0xFF1E293B)),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStickyBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _testPrint,
            icon: const Icon(Icons.print),
            label: const Text('Test chek chiqarish'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('Sozlamalarni saqlash'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _saveSettings() async {
    final settings = PrinterSettings(
      type: _selectedType,
      printerName: _selectedPrinterName,
      ipAddress: _ipController.text,
      port: int.tryParse(_portController.text) ?? 9100,
    );

    await context.read<PrinterProvider>().saveSettings(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sozlamalar saqlandi ✅'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _testPrint() async {
    final settings = PrinterSettings(
      type: _selectedType,
      printerName: _selectedPrinterName,
      ipAddress: _ipController.text,
      port: int.tryParse(_portController.text) ?? 9100,
    );

    final success = await context.read<PrinterProvider>().testPrint(settings);
    setState(() {
      _isSuccess = success;
      _lastStatus = success ? 'Muvaffaqiyatli ✅' : 'Xatolik ❌';
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Chek chiqarildi!' : 'Xatolik yuz berdi.'),
          backgroundColor: success ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
