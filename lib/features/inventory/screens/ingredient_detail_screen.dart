import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../models/inventory_models.dart';
import '../../../providers/inventory_provider.dart';
import '../widgets/inventory_image.dart';

/// Xomashyo detali (§4.4) — rasm, nom, birlik, min. miqdor, o'rtacha tannarx
/// tahrirlanadi.
///
/// **Ombordagi miqdor** to'g'ridan-to'g'ri yozilmaydi: o'zgartirilsa farq
/// `ADJUST` harakati sifatida yoziladi (inventarizatsiya bilan bir xil yo'l),
/// shunda tarix uzilmaydi.
///
/// O'zgarish saqlansa `true` bilan qaytadi.
class IngredientDetailScreen extends StatefulWidget {
  final Ingredient ingredient;
  final double onHand;

  const IngredientDetailScreen({
    super.key,
    required this.ingredient,
    required this.onHand,
  });

  @override
  State<IngredientDetailScreen> createState() => _IngredientDetailScreenState();
}

class _IngredientDetailScreenState extends State<IngredientDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _minStockController;
  late final TextEditingController _avgCostController;
  late final TextEditingController _onHandController;

  String? _imagePath;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ing = widget.ingredient;
    _nameController = TextEditingController(text: ing.name);
    _unitController = TextEditingController(text: ing.baseUnit);
    _minStockController = TextEditingController(text: _fmt(ing.minStock));
    _avgCostController = TextEditingController(
      text: ing.avgCost > 0 ? _fmt(ing.avgCost) : '',
    );
    _onHandController = TextEditingController(text: _fmt(widget.onHand));
    _imagePath = ing.imagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _minStockController.dispose();
    _avgCostController.dispose();
    _onHandController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path != null && mounted) setState(() => _imagePath = path);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final id = widget.ingredient.id;
    if (id == null) return;

    final newOnHand = _parse(_onHandController.text) ?? widget.onHand;
    final onHandChanged = (newOnHand - widget.onHand).abs() > 1e-9;

    setState(() => _saving = true);
    final provider = context.read<InventoryProvider>();
    try {
      await provider.updateIngredient(
        widget.ingredient.copyWith(
          name: _nameController.text.trim(),
          baseUnit: _unitController.text.trim(),
          minStock: _parse(_minStockController.text) ?? 0,
          avgCost: _parse(_avgCostController.text) ?? 0,
          imagePath: _imagePath,
        ),
      );

      // Qoldiq o'zgargan bo'lsa — ADJUST orqali (tarix saqlanadi).
      if (onHandChanged) {
        await provider.reconcileIngredients({id: newOnHand});
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Saqlashda xatolik: $e', isError: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('O\'chirilsinmi?'),
        content: Text(
          '"${widget.ingredient.name}" o\'chiriladi. Uni ishlatadigan '
          'retseptlardan ham chiqib ketadi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().deleteIngredient(
        widget.ingredient.id!,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('O\'chirishda xatolik: $e', isError: true);
    }
  }

  void _snack(String text, {bool isError = false}) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static double? _parse(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImage = _imagePath != null && _imagePath!.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.ingredient.name),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'O\'chirish',
            onPressed: _saving ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            color: Colors.red.shade400,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('Saqlash'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          InkWell(
                            onTap: _saving ? null : _pickImage,
                            borderRadius: BorderRadius.circular(16),
                            child: InventoryImage(
                              // Yangi tanlangan fayl darhol ko'rinishi uchun
                              // to'g'ridan-to'g'ri yo'l uzatiladi.
                              imagePath: _imagePath,
                              placeholderIcon:
                                  Icons.add_photo_alternate_outlined,
                              size: 120,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _saving ? null : _pickImage,
                            icon: const Icon(Icons.image_outlined, size: 16),
                            label: Text(
                              hasImage ? 'Almashtirish' : 'Rasm tanlash',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (hasImage)
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _imagePath = null),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade400,
                              ),
                              child: const Text(
                                'Rasmni olib tashlash',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 28),
                      Expanded(
                        child: Column(
                          children: [
                            _field(
                              controller: _nameController,
                              label: 'Nomi',
                              icon: Icons.label_outline_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nom kiriting'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: _unitController,
                                    label: 'O\'lchov birligi (g, ml, dona)',
                                    icon: Icons.straighten_rounded,
                                    validator: (v) =>
                                        (v == null || v.trim().isEmpty)
                                        ? 'Birlik kiriting'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _field(
                                    controller: _minStockController,
                                    label: 'Min. miqdor',
                                    icon: Icons.warning_amber_rounded,
                                    numeric: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    controller: _onHandController,
                                    label: 'Ombordagi miqdor',
                                    icon: Icons.inventory_2_outlined,
                                    numeric: true,
                                    helper:
                                        'O\'zgartirilsa farq ADJUST sifatida '
                                        'yoziladi',
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _field(
                                    controller: _avgCostController,
                                    label: 'O\'rtacha tannarx (1 birlik)',
                                    icon: Icons.payments_outlined,
                                    numeric: true,
                                    helper:
                                        'Kirim qilinganda avtomatik '
                                        'yangilanadi',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  _summary(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Joriy qoldiqning umumiy qiymati — tannarx kiritilgan bo'lsa foydali.
  Widget _summary(ThemeData theme) {
    final avg = _parse(_avgCostController.text) ?? 0;
    final onHand = _parse(_onHandController.text) ?? 0;
    return Row(
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 18,
          color: theme.hintColor,
        ),
        const SizedBox(width: 8),
        Text(
          'Qoldiq qiymati: ',
          style: TextStyle(color: theme.hintColor, fontSize: 13),
        ),
        Text(
          avg > 0
              ? PriceFormatter.formatWithCurrency(avg * onHand)
              : 'tannarx kiritilmagan',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool numeric = false,
    String? helper,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: !_saving,
      validator: validator,
      onChanged: numeric ? (_) => setState(() {}) : null,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        helperMaxLines: 2,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
