import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/receipt_settings_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../models/receipt_settings.dart';

class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabCtrl;

  // Mijoz cheki controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addrCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _feedCtrl;

  // Oshxona cheki controllers
  late TextEditingController _kitchenHeaderCtrl;
  late TextEditingController _kitchenFeedCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    final s = context.read<ReceiptSettingsProvider>().settings;
    _nameCtrl = TextEditingController(text: s.restaurantName);
    _phoneCtrl = TextEditingController(text: s.phoneNumber);
    _addrCtrl = TextEditingController(text: s.address);
    _footerCtrl = TextEditingController(text: s.footerMessage);
    _feedCtrl = TextEditingController(text: s.feedLines.toString());
    _kitchenHeaderCtrl = TextEditingController(text: s.kitchenHeaderText);
    _kitchenFeedCtrl = TextEditingController(text: s.kitchenFeedLines.toString());
  }

  @override
  void dispose() {
    _tabCtrl?.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addrCtrl.dispose();
    _footerCtrl.dispose();
    _feedCtrl.dispose();
    _kitchenHeaderCtrl.dispose();
    _kitchenFeedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptSettingsProvider>();
    final settings = provider.settings;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sol panel — sozlamalar
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
                        child: _buildHeader(),
                      ),
                      _buildTabBar(theme),
                      Expanded(
                        child: TabBarView(
                          controller: _tabCtrl,
                          children: [
                            _buildCustomerTab(settings, provider),
                            _buildKitchenTab(settings, provider),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // O'ng panel — preview
                if (_tabCtrl != null)
                  AnimatedBuilder(
                    animation: _tabCtrl!,
                    builder: (context2, snap) => _tabCtrl!.index == 0
                        ? _buildCustomerPreview(settings)
                        : _buildKitchenPreview(settings),
                  )
                else
                  _buildCustomerPreview(settings),
              ],
            ),
          ),
          _buildStickyBar(provider),
        ],
      ),
    );
  }

  // ─────────────────────────── Header ──────────────────────────────

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chek sozlamalari',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Mijoz cheki va oshxona cheki dizaynini sozlang',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
      child: TabBar(
        controller: _tabCtrl,
        labelStyle:
            const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontSize: 14),
        indicatorSize: TabBarIndicatorSize.label,
        tabs: const [
          Tab(
            icon: Icon(Icons.receipt_long_rounded),
            text: 'Mijoz cheki',
          ),
          Tab(
            icon: Icon(Icons.kitchen_rounded),
            text: 'Oshxona cheki',
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Mijoz cheki tab ─────────────────────────

  Widget _buildCustomerTab(
      ReceiptSettings settings, ReceiptSettingsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Bu qurilma printer',
            hint: "Har bir qurilma o'ziga alohida receipt printer tanlashi mumkin",
            child: _buildDevicePrinterSelector(context),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Buyurtma sozlamalari',
            hint: 'Cartga tushgan mahsulotlarni qanday saqlash',
            child: _buildCard([
              _buildToggleRow(
                'Avtomatik tasdiqlash',
                "Mahsulot qo'shilganda darhol saqlanadi, tasdiqlash tugmasi ko'rinmaydi",
                context.watch<AppSettingsProvider>().autoConfirmOrder,
                (v) => context.read<AppSettingsProvider>().setAutoConfirmOrder(v),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: "Restoran ma'lumotlari",
            hint: "Chekda ko'rinadigan asosiy ma'lumotlar",
            child: _buildCard([
              _buildInfoInput(
                label: 'Restoran nomi',
                controller: _nameCtrl,
                enabled: settings.showRestaurantName,
                onToggle: (v) => provider.updateSettings(
                    settings.copyWith(showRestaurantName: v)),
              ),
              const Divider(height: 1),
              _buildInfoInput(
                label: 'Telefon raqam',
                controller: _phoneCtrl,
                enabled: settings.showPhoneNumber,
                onToggle: (v) => provider.updateSettings(
                    settings.copyWith(showPhoneNumber: v)),
              ),
              const Divider(height: 1),
              _buildInfoInput(
                label: 'Manzil',
                controller: _addrCtrl,
                enabled: settings.showAddress,
                onToggle: (v) => provider.updateSettings(
                    settings.copyWith(showAddress: v)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: "Chek ko'rinishi",
            hint: "Formatlash va qog'oz sozlamalari",
            child: _buildCard([
              _buildSettingRow(
                "Chekka bo'sh joy (Margin)",
                'Chetdan tashlab ketiladigan masofa',
                _buildMarginSelector(settings, provider),
              ),
              const Divider(height: 1),
              _buildSettingRow(
                "Bo'sh qatorlar (Feed)",
                "Chek oxiridagi bo'shliqlar soni",
                _buildFeedInput(_feedCtrl, (n) => provider.updateSettings(
                    settings.copyWith(feedLines: n))),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                "Qog'ozni kesish (Auto-cut)",
                "Chop etishdan so'ng avtomatik kesish",
                settings.cutPaper,
                (v) => provider.updateSettings(settings.copyWith(cutPaper: v)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: "Taomlar ko'rinishi",
            hint: "Mahsulotlar ro'yxati stili",
            child: _buildCard([
              _buildSettingRow(
                'Layout turi',
                "Jadvallarni ko'rsatish usuli",
                _buildLayoutSelector(settings, provider),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                "Qaytimni ko'rsatmaslik",
                'Chekda qaytim qismini yashirish',
                !settings.showChange,
                (v) => provider.updateSettings(
                    settings.copyWith(showChange: !v)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Pastki xabar (Footer)',
            hint: "Mijozlar uchun rahmatnoma yoki ma'lumot",
            child: _buildCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Footer ko\'rsatish',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Switch(
                          value: settings.showFooter,
                          onChanged: (v) => provider.updateSettings(
                              settings.copyWith(showFooter: v)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _footerCtrl,
                      maxLines: 2,
                      enabled: settings.showFooter,
                      decoration: InputDecoration(
                        hintText: 'Masalan: Rahmat! Yana keling 😊',
                        filled: true,
                        fillColor: settings.showFooter
                            ? Colors.white
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────── Oshxona cheki tab ───────────────────────

  Widget _buildKitchenTab(
      ReceiptSettings settings, ReceiptSettingsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSection(
            title: 'Sarlavha',
            hint: "Chek tepasida ko'rinadigan matn",
            child: _buildCard([
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sarlavha matni',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _kitchenHeaderCtrl,
                      decoration: InputDecoration(
                        hintText: 'OSHXONA CHEKI',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFFE2E8F0))),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onChanged: (v) => provider.updateSettings(
                          settings.copyWith(kitchenHeaderText: v)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Saboy buyurtmasi bo'lsa avtomatik 'SABOY' yoziladi",
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.45)),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: "Ko'rsatiladigan ma'lumotlar",
            hint: "Oshxona chekiga nima chiqishini belgilang",
            child: _buildCard([
              _buildToggleRow(
                'Buyurtma raqami',
                "№ va kod ko'rsatish",
                settings.kitchenShowOrderNumber,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenShowOrderNumber: v)),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                'Sana va vaqt',
                "Buyurtma berilgan vaqtni ko'rsatish",
                settings.kitchenShowTime,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenShowTime: v)),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                'Stol nomi (katta)',
                "Stol nomini katta harfda ko'rsatish",
                settings.kitchenShowTable,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenShowTable: v)),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                'Ofitsiant ismi',
                "Kim buyurtma berganini ko'rsatish",
                settings.kitchenShowWaiter,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenShowWaiter: v)),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                'Izoh (Note)',
                "Buyurtmaga yozilgan izohni chiqarish",
                settings.kitchenShowNote,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenShowNote: v)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Mahsulotlar ko\'rinishi',
            hint: "Mahsulot nomini qanday o'lchamda chiqarish",
            child: _buildCard([
              _buildToggleRow(
                'Katta shrift (2x o\'lcham)',
                "Mahsulot nomi va miqdori aniqroq ko'rinadi",
                settings.kitchenFontLarge,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenFontLarge: v)),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                "Kategoriyaga bo'lish",
                "Mahsulotlarni kategoriya bo'yicha guruhlash",
                settings.kitchenGroupByCategory,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenGroupByCategory: v)),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                'Summani ko\'rsatish',
                'Chek oxirida jami summani chiqarish',
                settings.kitchenShowTotal,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenShowTotal: v)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: "Qog'oz sozlamalari",
            hint: "Feed va kesish",
            child: _buildCard([
              _buildSettingRow(
                "Bo'sh qatorlar (Feed)",
                "Chek oxiridagi bo'shliqlar soni",
                _buildFeedInput(_kitchenFeedCtrl, (n) => provider.updateSettings(
                    settings.copyWith(kitchenFeedLines: n))),
              ),
              const Divider(height: 1),
              _buildToggleRow(
                "Qog'ozni kesish (Auto-cut)",
                "Chop etishdan so'ng avtomatik kesish",
                settings.kitchenCutPaper,
                (v) => provider.updateSettings(
                    settings.copyWith(kitchenCutPaper: v)),
              ),
            ]),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────── Preview panels ──────────────────────────

  Widget _buildCustomerPreview(ReceiptSettings settings) {
    final theme = Theme.of(context);
    return Container(
      width: 380,
      height: double.infinity,
      color: theme.brightness == Brightness.light
          ? const Color(0xFFF1F5F9)
          : theme.colorScheme.onSurface.withOpacity(0.05),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(
            'MIJOZ CHEKI',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: _ReceiptPreviewWidget(
                settings: settings,
                isKitchen: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenPreview(ReceiptSettings settings) {
    final theme = Theme.of(context);
    return Container(
      width: 380,
      height: double.infinity,
      color: theme.brightness == Brightness.light
          ? const Color(0xFFF1F5F9)
          : theme.colorScheme.onSurface.withOpacity(0.05),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Text(
            'OSHXONA CHEKI',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              letterSpacing: 1,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: _ReceiptPreviewWidget(
                settings: settings,
                isKitchen: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Sticky bar ──────────────────────────────

  Widget _buildStickyBar(ReceiptSettingsProvider provider) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
              color: theme.colorScheme.onSurface.withOpacity(0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () => _testPrint(provider),
            icon: const Icon(Icons.print_rounded),
            label: const Text('Test chek'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _saveSettings(provider),
            icon: const Icon(Icons.save_rounded),
            label: const Text('Saqlash'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── Shared widgets ──────────────────────────

  Widget _buildSection({
    required String title,
    required String hint,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface)),
        Text(hint,
            style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.6))),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? const Color(0xFFE2E8F0)
              : theme.colorScheme.onSurface.withOpacity(0.1),
        ),
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
                borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6))),
                TextField(
                  controller: controller,
                  enabled: enabled,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(
      String title, String subtitle, Widget control) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6))),
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
        title, subtitle, Switch(value: value, onChanged: onChanged));
  }

  Widget _buildMarginSelector(
      ReceiptSettings settings, ReceiptSettingsProvider provider) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? const Color(0xFFF1F5F9)
            : theme.colorScheme.onSurface.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: settings.horizontalMargin,
        underline: const SizedBox(),
        items: [1, 2, 3]
            .map((m) =>
                DropdownMenuItem(value: m, child: Text('$m joy')))
            .toList(),
        onChanged: (v) => provider.updateSettings(
            settings.copyWith(horizontalMargin: v)),
      ),
    );
  }

  Widget _buildLayoutSelector(
      ReceiptSettings settings, ReceiptSettingsProvider provider) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'table', label: Text('Jadval')),
        ButtonSegment(value: 'classic', label: Text('Klassik')),
      ],
      selected: {settings.layoutType},
      onSelectionChanged: (val) => provider.updateSettings(
          settings.copyWith(layoutType: val.first)),
    );
  }

  Widget _buildFeedInput(
      TextEditingController ctrl, Function(int) onChanged) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 60,
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) onChanged(n);
        },
        decoration: InputDecoration(
          filled: true,
          fillColor: theme.brightness == Brightness.light
              ? const Color(0xFFF1F5F9)
              : theme.colorScheme.onSurface.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDevicePrinterSelector(BuildContext context) {
    final printerProvider = context.watch<PrinterProvider>();
    final printers = printerProvider.printers;
    final selectedId = printerProvider.selectedReceiptPrinterId;
    final theme = Theme.of(context);

    if (printers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Text(
          "Hech qanday printer sozlanmagan. Avval printer qo'shing.",
          style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: printers.map((printer) {
          final isSelected = printer.id == selectedId ||
              (selectedId == null && printer == printers.first);
          return InkWell(
            onTap: () => context
                .read<PrinterProvider>()
                .setSelectedReceiptPrinter(printer.id),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          printer.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          printer.type.name == 'network'
                              ? '${printer.ipAddress}:${printer.port}'
                              : printer.printerName ?? printer.type.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                        if (printer.categoryIds.isNotEmpty)
                          Text(
                            'Oshxona printeri (kategoriyalari bor)',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.orange.shade700),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────── Actions ─────────────────────────────────

  void _saveSettings(ReceiptSettingsProvider provider) async {
    final settings = provider.settings.copyWith(
      restaurantName: _nameCtrl.text,
      phoneNumber: _phoneCtrl.text,
      address: _addrCtrl.text,
      footerMessage: _footerCtrl.text,
      feedLines: int.tryParse(_feedCtrl.text) ?? 4,
      kitchenHeaderText: _kitchenHeaderCtrl.text,
      kitchenFeedLines: int.tryParse(_kitchenFeedCtrl.text) ?? 3,
    );
    await provider.updateSettings(settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Sozlamalar saqlandi ✅'),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _testPrint(ReceiptSettingsProvider provider) async {
    _saveSettings(provider);
    try {
      final success =
          await context.read<PrinterProvider>().testPrint();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success
              ? 'Test chek yuborildi ✅'
              : "Printer bilan aloqa o'rnatilmadi ❌"),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Printer xatoligi',
                style: TextStyle(color: Colors.red)),
            content: Text('Test chekini chiqarishda xatolik:\n\n$e'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }
}

// ─────────────────────── Preview Widget ──────────────────────────────

class _ReceiptPreviewWidget extends StatelessWidget {
  final ReceiptSettings settings;
  final bool isKitchen;

  const _ReceiptPreviewWidget({
    required this.settings,
    required this.isKitchen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        horizontal: isKitchen ? 12 : settings.horizontalMargin * 8.0,
        vertical: 20,
      ),
      child: isKitchen
          ? _KitchenPreviewContent(settings: settings)
          : _CustomerPreviewContent(settings: settings),
    );
  }
}

class _CustomerPreviewContent extends StatelessWidget {
  final ReceiptSettings settings;
  const _CustomerPreviewContent({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (settings.showRestaurantName)
          Text(settings.restaurantName,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: settings.headerBold
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 16)),
        if (settings.showPhoneNumber)
          Text('Tel: ${settings.phoneNumber}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11)),
        const _PreviewDivider(),
        if (settings.showOrderNumber)
          _PreviewRow('Buyurtma №:', '42'),
        if (settings.showDate)
          _PreviewRow('Sana:', '07.05.2026 14:30'),
        if (settings.showTable)
          _PreviewRow('Stol:', 'A-3'),
        if (settings.showWaiter)
          _PreviewRow('Ofitsiant:', 'Jasur'),
        const _PreviewDivider(),
        if (settings.layoutType == 'table') ...[
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nomi', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text('Soni', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text('Summa', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Osh (milli)', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
              Text('2', style: TextStyle(fontSize: 11)),
              Text('120 000', style: TextStyle(fontSize: 11)),
            ],
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text('Non', style: TextStyle(fontSize: 11))),
              Text('4', style: TextStyle(fontSize: 11)),
              Text('20 000', style: TextStyle(fontSize: 11)),
            ],
          ),
        ] else ...[
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Osh (milli)', style: TextStyle(fontSize: 11)),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('  2 x 60 000', style: TextStyle(fontSize: 11)),
              Text('120 000', style: TextStyle(fontSize: 11)),
            ],
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Non', style: TextStyle(fontSize: 11)),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('  4 x 5 000', style: TextStyle(fontSize: 11)),
              Text('20 000', style: TextStyle(fontSize: 11)),
            ],
          ),
        ],
        const _PreviewDivider(),
        _PreviewRow('Taomlar:', '140 000'),
        const _PreviewDivider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('JAMI:',
                style: TextStyle(
                    fontWeight: settings.totalBold
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14)),
            Text('140 000 so\'m',
                style: TextStyle(
                    fontWeight: settings.totalBold
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14)),
          ],
        ),
        if (settings.showChange) ...[
          const SizedBox(height: 6),
          _PreviewRow("To'landi:", '150 000'),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('QAYTIM:',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
              Text('10 000',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
        if (settings.showPaymentType)
          _PreviewRow("To'lov:", 'Naqd'),
        if (settings.showFooter && settings.footerMessage.isNotEmpty) ...[
          const _PreviewDivider(),
          Text(settings.footerMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10)),
        ],
        const SizedBox(height: 8),
        ...List.generate(settings.feedLines,
            (_) => const SizedBox(height: 8)),
        if (settings.cutPaper)
          const Text('- - - - - [ KESISH ] - - - - -',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }
}

class _KitchenPreviewContent extends StatelessWidget {
  final ReceiptSettings settings;
  const _KitchenPreviewContent({required this.settings});

  @override
  Widget build(BuildContext context) {
    final headerText = settings.kitchenHeaderText.isNotEmpty
        ? settings.kitchenHeaderText
        : 'OSHXONA CHEKI';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(headerText,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 6),
        if (settings.kitchenShowOrderNumber) ...[
          const Text('Buyurtma №: 42',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const Text('Kod: #A1B2C3D4',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ],
        if (settings.kitchenShowTime)
          const Text('Sana: 07.05.2026 14:30',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        if (settings.kitchenShowTable)
          const Text('STOL: A-3',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        if (settings.kitchenShowWaiter)
          const Text('Ofitsiant: Jasur',
              style: TextStyle(fontSize: 12)),
        if (settings.kitchenShowNote)
          const Text('Izoh: Kam achitkli',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12)),
        const _PreviewDivider(),
        if (settings.kitchenGroupByCategory)
          const Text('[ ASOSIY ]',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        _KitchenItemRow('2 dona x Osh (milli)', settings.kitchenFontLarge),
        _KitchenItemRow('4 dona x Non', settings.kitchenFontLarge),
        _KitchenItemRow('1 dona x Shashlik', settings.kitchenFontLarge),
        const _PreviewDivider(),
        if (settings.kitchenShowTotal) ...[
          const Text('Taomlar:  140 000',
              style: TextStyle(fontSize: 12)),
          const _PreviewDivider(),
          const Text('JAMI: 140 000 so\'m',
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
        ],
        ...List.generate(settings.kitchenFeedLines,
            (_) => const SizedBox(height: 8)),
        if (settings.kitchenCutPaper)
          const Text('- - - - - [ KESISH ] - - - - -',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 8, color: Colors.grey)),
      ],
    );
  }
}

class _KitchenItemRow extends StatelessWidget {
  final String text;
  final bool large;
  const _KitchenItemRow(this.text, this.large);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: large ? 15 : 12)),
    );
  }
}

class _PreviewDivider extends StatelessWidget {
  const _PreviewDivider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Text('--------------------------------',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10)),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
