import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/qty_formatter.dart';
import '../../../models/inventory_models.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../repositories/inventory_repository.dart';
import '../widgets/inventory_image.dart';

/// Inventarizatsiya (§4.7).
///
/// Xomashyo **yoki** tayyor mahsulot tanlanadi; har birligi uchun tizimdagi
/// qoldiq ko'rsatiladi va **real son** kiritiladi. Farq avtomatik hisoblanadi.
///
/// Saqlashda qoldiq **realga tenglashtiriladi** (nolga emas — Qaror 3), farq
/// esa `ADJUST` harakati sifatida yoziladi.
///
/// ⚠️ Faqat **real son kiritilgan** qatorlar hisobga olinadi. Bo'sh qoldirilgan
/// qator "sanalmagan" deb qaraladi va tegilmaydi.
class StocktakingScreen extends StatefulWidget {
  const StocktakingScreen({super.key});

  @override
  State<StocktakingScreen> createState() => _StocktakingScreenState();
}

class _StocktakingScreenState extends State<StocktakingScreen> {
  final _searchController = TextEditingController();
  final _controllers = <int, TextEditingController>{};

  StockItemKind _kind = StockItemKind.ingredient;
  List<_CountItem> _items = [];
  bool _loading = true;
  bool _saving = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<InventoryProvider>();
    try {
      final List<_CountItem> items;
      if (_kind == StockItemKind.ingredient) {
        final rows = await provider.getIngredientsWithStock();
        items = rows.map((m) {
          final ing = Ingredient.fromMap(m);
          return _CountItem(
            id: ing.id!,
            name: ing.name,
            unit: ing.baseUnit,
            system: (m['on_hand'] as num?)?.toDouble() ?? 0,
            imagePath: ing.imagePath,
          );
        }).toList();
      } else {
        final prepared = await provider.getPreparedProducts();
        final resale = await provider.getResaleProducts();
        items = [...prepared, ...resale].map((m) {
          final p = Product.fromMap(m);
          return _CountItem(
            id: p.id!,
            name: p.name,
            unit: p.unit ?? 'dona',
            system: p.quantity ?? 0,
            imagePath: p.imagePath,
          );
        }).toList();
      }
      items.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Yuklashda xatolik: $e', isError: true);
    }
  }

  void _setKind(StockItemKind kind) {
    if (_kind == kind) return;
    // Tur o'zgarsa kiritilgan sonlar boshqa ro'yxatga tegishli bo'lib qoladi.
    _disposeControllers();
    setState(() => _kind = kind);
    _load();
  }

  List<_CountItem> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  TextEditingController _controllerFor(int id) =>
      _controllers.putIfAbsent(id, () => TextEditingController());

  /// Real son kiritilgan qatorlar: id → real qiymat.
  Map<int, double> get _counted {
    final result = <int, double>{};
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim().replaceAll(',', '.');
      if (text.isEmpty) continue;
      final value = double.tryParse(text);
      if (value != null && value >= 0) result[entry.key] = value;
    }
    return result;
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

  Future<void> _save() async {
    final counted = _counted;
    if (counted.isEmpty) {
      _snack('Hech bo\'lmasa bitta real son kiriting', isError: true);
      return;
    }

    // Farqi bor qatorlar sonini ko'rsatib tasdiqlaymiz — inventarizatsiya
    // qoldiqni qaytarib bo'lmaydigan tarzda o'zgartiradi.
    final byId = {for (final i in _items) i.id: i};
    final changed = counted.entries
        .where((e) => ((byId[e.key]?.system ?? 0) - e.value).abs() > 1e-9)
        .length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Inventarizatsiyani yakunlash'),
        content: Text(
          '${counted.length} ta birlik sanaldi, shundan $changed tasida farq '
          'bor.\n\nQoldiq real songa tenglashtiriladi va farq tarixga ADJUST '
          'sifatida yoziladi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tasdiqlash'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final provider = context.read<InventoryProvider>();
      if (_kind == StockItemKind.ingredient) {
        await provider.reconcileIngredients(counted);
      } else {
        await provider.reconcileProducts(counted);
      }
      if (!mounted) return;
      _disposeControllers();
      setState(() => _saving = false);
      await _load();
      if (!mounted) return;
      _snack('Inventarizatsiya saqlandi (${counted.length} ta birlik)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Saqlashda xatolik: $e', isError: true);
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Inventarizatsiya'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          _toolbar(theme),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: _headerRow(theme),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? Center(
                    child: Text(
                      'Hech narsa topilmadi',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: theme.dividerColor.withValues(alpha: 0.1),
                    ),
                    itemBuilder: (_, i) => _row(theme, items[i]),
                  ),
          ),
          _footer(theme),
        ],
      ),
    );
  }

  Widget _toolbar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          _kindButton(
            theme,
            label: 'Xomashyolar',
            icon: Icons.egg_outlined,
            kind: StockItemKind.ingredient,
          ),
          const SizedBox(width: 10),
          _kindButton(
            theme,
            label: 'Mahsulotlar',
            icon: Icons.fastfood_outlined,
            kind: StockItemKind.product,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Qidirish...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                isDense: true,
                filled: true,
                fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kindButton(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required StockItemKind kind,
  }) {
    final selected = _kind == kind;
    return ElevatedButton.icon(
      onPressed: _saving ? null : () => _setKind(kind),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected
            ? Colors.black
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        foregroundColor: selected ? Colors.white : theme.hintColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _headerRow(ThemeData theme) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: theme.hintColor,
    );
    return Row(
      children: [
        Expanded(flex: 4, child: Text('Nomi', style: style)),
        Expanded(flex: 2, child: Text('Tizimda', style: style)),
        Expanded(flex: 2, child: Text('Real son', style: style)),
        Expanded(flex: 2, child: Text('Farq', style: style)),
      ],
    );
  }

  Widget _row(ThemeData theme, _CountItem item) {
    final controller = _controllerFor(item.id);
    final text = controller.text.trim().replaceAll(',', '.');
    final real = text.isEmpty ? null : double.tryParse(text);
    final diff = real == null ? null : real - item.system;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                InventoryImage(
                  imagePath: item.imagePath,
                  placeholderIcon: _kind == StockItemKind.ingredient
                      ? Icons.egg_outlined
                      : Icons.fastfood_outlined,
                  size: 36,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${QtyFormatter.format(item.system)} ${item.unit}',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: TextField(
                controller: controller,
                enabled: !_saving,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  hintText: 'sanalmagan',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: theme.hintColor.withValues(alpha: 0.6),
                  ),
                  isDense: true,
                  suffixText: item.unit,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: diff == null
                ? Text('—', style: TextStyle(color: theme.hintColor))
                : Text(
                    diff == 0
                        ? 'to\'g\'ri'
                        : '${diff > 0 ? '+' : '−'}${QtyFormatter.format(diff.abs())} '
                              '${item.unit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: diff == 0
                          ? Colors.green.shade700
                          : (diff > 0
                                ? Colors.blue.shade700
                                : Colors.red.shade700),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    final counted = _counted;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${counted.length} / ${_items.length} birlik sanaldi',
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Text(
            'Sanalmagan qatorlarga tegilmaydi',
            style: TextStyle(
              color: theme.hintColor,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: (_saving || counted.isEmpty) ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: const Text('Yakunlash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

}

/// Sanaladigan bitta birlik.
class _CountItem {
  final int id;
  final String name;
  final String unit;
  final double system;
  final String? imagePath;

  _CountItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.system,
    this.imagePath,
  });
}
