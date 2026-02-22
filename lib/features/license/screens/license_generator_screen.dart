import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/security/rsa_signer.dart';
import '../../../models/license_model.dart';

class LicenseGeneratorScreen extends StatefulWidget {
  const LicenseGeneratorScreen({super.key});

  @override
  State<LicenseGeneratorScreen> createState() => _LicenseGeneratorScreenState();
}

class _LicenseGeneratorScreenState extends State<LicenseGeneratorScreen> {
  final _formKey = GlobalKey<FormState>();

  final _hwidController = TextEditingController();
  final _companyController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  String _plan = 'PREMIUM';
  bool _aiAnalytics = true;
  bool _inventoryMgmt = true;
  bool _multiPrinter = true;

  bool _isGenerating = false;
  String? _statusMessage;
  Color _statusColor = Colors.green;

  @override
  void dispose() {
    _hwidController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _generateLicense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isGenerating = true;
      _statusMessage = null;
    });

    try {
      // 1. Load Private Key
      // Try project root first (dev environment)
      File keyFile = File('private_key.pem');
      if (!await keyFile.exists()) {
        _showStatus(
          'private_key.pem topilmadi! Iltimos, faylni tanlang.',
          Colors.orange,
        );
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pem'],
        );
        if (result != null && result.files.single.path != null) {
          keyFile = File(result.files.single.path!);
        } else {
          setState(() => _isGenerating = false);
          return;
        }
      }

      final privateKey = await keyFile.readAsString();

      // 2. Create Payload
      final payload = LicensePayload(
        product: 'Zelly POS',
        company: _companyController.text,
        deviceId: _hwidController.text,
        issuedAt: DateTime.now(),
        expiry: _expiryDate,
        plan: _plan,
        features: {
          'ai_analytics': _aiAnalytics,
          'inventory_mgmt': _inventoryMgmt,
          'multi_printer': _multiPrinter,
        },
      );

      final canonicalJson = payload.toCanonicalJson();
      final signature = RsaSigner.sign(canonicalJson, privateKey);

      final licenseFile = {'payload': payload.toMap(), 'signature': signature};

      final jsonContent = const JsonEncoder.withIndent(
        '    ',
      ).convert(licenseFile);

      // 3. Save File
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Litsenziyani saqlash',
        fileName: 'license.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.json')) outputFile += '.json';
        await File(outputFile).writeAsString(jsonContent);
        _showStatus(
          'Litsenziya muvaffaqiyatli yaratildi: $outputFile',
          Colors.green,
        );
      } else {
        _showStatus('Saqlash bekor qilindi.', Colors.blue);
      }
    } catch (e) {
      _showStatus('Xatolik: $e', Colors.red);
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _showStatus(String msg, Color color) {
    setState(() {
      _statusMessage = msg;
      _statusColor = color;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Litsenziya Generatori'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: _hwidController,
                    label: 'Qurilma ID (HWID)',
                    hint: 'HWID ni kiriting yoki nusxalanganini qo\'ying',
                    icon: Icons.computer,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'HWID shart' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _companyController,
                    label: 'Kompaniya / Foydalanuvchi nomi',
                    hint: 'Masalan: Zelly Cafe',
                    icon: Icons.business,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Nomi shart' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildDatePicker(),
                  const SizedBox(height: 32),
                  const Text(
                    'Sozlamalar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildToggles(),
                  const SizedBox(height: 32),
                  if (_statusMessage != null) _buildStatusBox(),
                  const SizedBox(height: 40),
                  _buildGenerateButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Yangi litsenziya yaratish',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Mijoz uchun xavfsiz litsenziya faylini shakllantirish',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amal qilish muddati',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    DateFormat('dd.MM.yyyy').format(_expiryDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildToggles() {
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        _buildToggleItem(
          'AI Analytics',
          _aiAnalytics,
          (v) => setState(() => _aiAnalytics = v!),
        ),
        _buildToggleItem(
          'Inventory Mgmt',
          _inventoryMgmt,
          (v) => setState(() => _inventoryMgmt = v!),
        ),
        _buildToggleItem(
          'Multi Printer',
          _multiPrinter,
          (v) => setState(() => _multiPrinter = v!),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            initialValue: _plan,
            decoration: InputDecoration(
              labelText: 'Tarif (Plan)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              'STANDARD',
              'PREMIUM',
              'ULTIMATE',
            ].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _plan = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleItem(String label, bool value, Function(bool?) onChanged) {
    return SizedBox(
      width: 200,
      child: CheckboxListTile(
        title: Text(label),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildStatusBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Text(
        _statusMessage!,
        style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateLicense,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isGenerating
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                'LITSENZIYA GENERATSIYA QILISH',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
