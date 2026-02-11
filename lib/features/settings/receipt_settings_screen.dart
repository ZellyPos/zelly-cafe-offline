import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/receipt_settings_provider.dart';
import '../../providers/printer_provider.dart';
import '../../models/receipt_settings.dart';
import '../../core/theme.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _feedCtrl;

  @override
  void initState() {
    super.initState();
    final s = context.read<ReceiptSettingsProvider>().settings;
    _nameCtrl = TextEditingController(text: s.restaurantName);
    _phoneCtrl = TextEditingController(text: s.phoneNumber);
    _addrCtrl = TextEditingController(text: s.address);
    _footerCtrl = TextEditingController(text: s.footerMessage);
    _feedCtrl = TextEditingController(text: s.feedLines.toString());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _footerCtrl.dispose();
    _feedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptSettingsProvider>();
    final settings = provider.settings;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Settings List
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 32),

                        _buildSection(
                          title: 'Restoran ma’lumotlari',
                          hint: 'Chekda ko\'rinadigan asosiy ma\'lumotlar',
                          child: _buildCard([
                            _buildInfoInput(
                              label: 'Restoran nomi',
                              controller: _nameCtrl,
                              enabled: settings.showRestaurantName,
                              onToggle: (v) => provider.updateSettings(
                                settings.copyWith(showRestaurantName: v),
                              ),
                            ),
                            const Divider(height: 1),
                            _buildInfoInput(
                              label: 'Telefon raqam',
                              controller: _phoneCtrl,
                              enabled: settings.showPhoneNumber,
                              onToggle: (v) => provider.updateSettings(
                                settings.copyWith(showPhoneNumber: v),
                              ),
                            ),
                            const Divider(height: 1),
                            _buildInfoInput(
                              label: 'Manzil',
                              controller: _addrCtrl,
                              enabled: settings.showAddress,
                              onToggle: (v) => provider.updateSettings(
                                settings.copyWith(showAddress: v),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        _buildSection(
                          title: 'Chek ko‘rinishi',
                          hint: 'Formatlash va qog\'oz sozlamalari',
                          child: _buildCard([
                            _buildSettingRow(
                              'Chekka bo‘sh joy (Margin)',
                              'Chetdan tashlab ketiladigan masofa',
                              _buildMarginSelector(settings, provider),
                            ),
                            const Divider(height: 1),
                            _buildSettingRow(
                              'Bo\'sh qatorlar (Feed)',
                              'Chek oxiridagi bo\'shliqlar soni',
                              _buildFeedInput(provider, settings),
                            ),
                            const Divider(height: 1),
                            _buildToggleRow(
                              'Qog\'ozni kesish (Auto-cut)',
                              'Chop etishdan so\'ng avtomatik kesish',
                              settings.cutPaper,
                              (v) => provider.updateSettings(
                                settings.copyWith(cutPaper: v),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        _buildSection(
                          title: 'Taomlar ko‘rinishi',
                          hint: 'Mahsulotlar ro\'yxati stili',
                          child: _buildCard([
                            _buildSettingRow(
                              'Layout turi',
                              'Jadvallarni ko\'rsatish usuli',
                              _buildLayoutSelector(settings, provider),
                            ),
                            const Divider(height: 1),
                            _buildToggleRow(
                              'Qaytimni ko‘rsatmaslik',
                              'Chekda qaytim qismini yashirish',
                              !settings.showChange,
                              (v) => provider.updateSettings(
                                settings.copyWith(showChange: !v),
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 24),

                        _buildSection(
                          title: 'Pastki xabar (Footer)',
                          hint: 'Mijozlar uchun rahmatnoma yoki ma\'lumot',
                          child: _buildCard([
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Footer ko\'rsatish',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const Spacer(),
                                      Switch(
                                        value: settings.showFooter,
                                        onChanged: (v) =>
                                            provider.updateSettings(
                                              settings.copyWith(showFooter: v),
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _footerCtrl,
                                    maxLines: 2,
                                    enabled: settings.showFooter,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Masalan: Rahmat! Yana keling 😊',
                                      filled: true,
                                      fillColor: settings.showFooter
                                          ? Colors.white
                                          : const Color(0xFFF1F5F9),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),

                // Live Preview
                _buildPreviewSection(settings),
              ],
            ),
          ),
          _buildStickyBar(provider),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chek sozlamalari',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mijozlarga beriladigan chek dizaynini va tarkibini tahrirlang',
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

  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoInput({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    required Function(bool) onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Checkbox(
            value: enabled,
            onChanged: (v) => onToggle(v ?? false),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String title, String subtitle, Widget control) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
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
          control,
        ],
      ),
    );
  }

  Widget _buildToggleRow(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return _buildSettingRow(
      title,
      subtitle,
      Switch(value: value, onChanged: onChanged),
    );
  }

  Widget _buildMarginSelector(
    ReceiptSettings settings,
    ReceiptSettingsProvider provider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: settings.horizontalMargin,
        underline: const SizedBox(),
        items: [1, 2, 3]
            .map((m) => DropdownMenuItem(value: m, child: Text('$m joy')))
            .toList(),
        onChanged: (v) =>
            provider.updateSettings(settings.copyWith(horizontalMargin: v)),
      ),
    );
  }

  Widget _buildLayoutSelector(
    ReceiptSettings settings,
    ReceiptSettingsProvider provider,
  ) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'table', label: Text('Jadval')),
        ButtonSegment(value: 'classic', label: Text('Klassik')),
      ],
      selected: {settings.layoutType},
      onSelectionChanged: (val) =>
          provider.updateSettings(settings.copyWith(layoutType: val.first)),
    );
  }

  Widget _buildFeedInput(
    ReceiptSettingsProvider provider,
    ReceiptSettings settings,
  ) {
    return SizedBox(
      width: 60,
      child: TextField(
        controller: _feedCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null)
            provider.updateSettings(settings.copyWith(feedLines: n));
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildPreviewSection(ReceiptSettings settings) {
    return Container(
      width: 380,
      height: double.infinity,
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Text(
            'KORINISH (PREVIEW)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: settings.horizontalMargin * 8.0,
                vertical: 20,
              ),
              child: Column(
                children: [
                  if (settings.showRestaurantName)
                    Text(
                      settings.restaurantName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  if (settings.showPhoneNumber)
                    Text(
                      'Tel: ${settings.phoneNumber}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  const Text(
                    '--------------------------------',
                    style: TextStyle(color: Color(0xFFE2E8F0)),
                  ),
                  const SizedBox(height: 4),
                  if (settings.layoutType == 'table') ...[
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nomi',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Soni',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Summa',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Osh (milli)', style: TextStyle(fontSize: 11)),
                        Text('2', style: TextStyle(fontSize: 11)),
                        Text('120 000', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ] else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Osh (milli)',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('  2 x 60 000', style: TextStyle(fontSize: 11)),
                        Text('120 000', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                  const Spacer(),
                  const Divider(),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'JAMI:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '120 000 USZ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (settings.showChange) ...[
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('To\'lov:', style: TextStyle(fontSize: 11)),
                        Text('150 000', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'QAYTIM:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '30 000',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (settings.showFooter)
                    Text(
                      settings.footerMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ...List.generate(
                    settings.feedLines,
                    (index) => const SizedBox(height: 10),
                  ),
                  if (settings.cutPaper)
                    const Text(
                      '- - - - - - - - [ KESISH ] - - - - - - - -',
                      style: TextStyle(fontSize: 8, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBar(ReceiptSettingsProvider provider) {
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
            onPressed: () => _testPrint(provider),
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
            onPressed: () => _saveSettings(provider),
            icon: const Icon(Icons.save),
            label: const Text('Saqlash'),
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

  void _saveSettings(ReceiptSettingsProvider provider) async {
    final settings = provider.settings.copyWith(
      restaurantName: _nameCtrl.text,
      phoneNumber: _phoneCtrl.text,
      address: _addrCtrl.text,
      footerMessage: _footerCtrl.text,
      feedLines: int.tryParse(_feedCtrl.text) ?? 4,
    );

    await provider.updateSettings(settings);
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

  void _testPrint(ReceiptSettingsProvider provider) async {
    // Save first to ensure printer service has latest
    _saveSettings(provider);

    final printerProv = context.read<PrinterProvider>();
    try {
      final success = await printerProv.testPrint();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test chek yuborildi ✅'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Printer bilan aloqa o\'rnatilmadi ❌'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Printer xatoligi',
              style: TextStyle(color: Colors.red),
            ),
            content: Text('Test chekini chiqarishda xatolik yuz berdi:\n\n$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }
}
