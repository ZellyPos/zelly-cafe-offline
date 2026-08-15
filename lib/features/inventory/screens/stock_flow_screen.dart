import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/errors/insufficient_stock.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../models/inventory_models.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../../../repositories/inventory_repository.dart';
import '../widgets/inventory_image.dart';
import 'stock_history_new_screen.dart';
import 'stocktaking_screen.dart';

/// Kirim / Chiqim sahifasi (§4.5).
///
/// - **Kirim**: xomashyolar **+ resale mahsulotlar** (tayyorlanadigan mahsulot
///   kirim qilinmaydi — u pishiriladi).
/// - **Chiqim**: xomashyolar **+ barcha mahsulotlar** (buzilish/waste — Qaror 6).
///
/// Bir nechta qator tanlanadi, har qatorda miqdor + (kirimda) tannarx va
/// "kimdan olindi" yoki (chiqimda) izoh kiritiladi. Saqlash **bitta
/// tranzaksiyada** bajariladi.
class StockFlowScreen extends StatefulWidget {
  const StockFlowScreen({super.key});

  @override
  State<StockFlowScreen> createState() => _StockFlowScreenState();
}

class _StockFlowScreenState extends State<StockFlowScreen> {
  final _searchController = TextEditingController();

  StockDirection _direction = StockDirection.inbound;
  List<_FlowItem> _ingredients = [];
  List<_FlowItem> _preparedProducts = [];
  List<_FlowItem> _resaleProducts = [];

  /// Tanlangan qatorlar — kalit `_FlowItem.key`.
  final _lines = <String, _FlowLine>{};

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
    for (final line in _lines.values) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<InventoryProvider>();
    try {
      final ingRows = await provider.getIngredientsWithStock();
      final prepared = await provider.getPreparedProducts();
      final resale = await provider.getResaleProducts();
      if (!mounted) return;
      setState(() {
        _ingredients = ingRows.map(_FlowItem.fromIngredient).toList();
        _preparedProducts = prepared
            .map((m) => _FlowItem.fromProduct(Product.fromMap(m)))
            .toList();
        _resaleProducts = resale
            .map((m) => _FlowItem.fromProduct(Product.fromMap(m)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Yuklashda xatolik: $e', isError: true);
    }
  }

  bool get _isInbound => _direction == StockDirection.inbound;

  /// Joriy yo'nalishga mos ro'yxat.
  ///
  /// Kirimda `prepared` mahsulot ko'rsatilmaydi — uning qoldig'i faqat
  /// pishirish orqali oshadi.
  List<_FlowItem> get _visibleItems {
    final all = <_FlowItem>[
      ..._ingredients,
      ..._resaleProducts,
      if (!_isInbound) ..._preparedProducts,
    ];
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? all
        : all.where((i) => i.name.toLowerCase().contains(q)).toList();
    filtered.sort((a, b) {
      // Xomashyolar avval, keyin mahsulotlar; ichida alifbo bo'yicha.
      if (a.kind != b.kind) {
        return a.kind == StockItemKind.ingredient ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return filtered;
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

  // ─── Tanlash / saqlash ────────────────────────────────────────────────────

  void _toggle(_FlowItem item) {
    setState(() {
      final existing = _lines.remove(item.key);
      if (existing != null) {
        existing.dispose();
      } else {
        _lines[item.key] = _FlowLine(cost: item.avgCost);
      }
    });
  }

  void _setDirection(StockDirection direction) {
    if (_direction == direction) return;
    setState(() {
      // Yo'nalish o'zgarganda ro'yxat tarkibi ham o'zgaradi — tanlovni
      // saqlab qolish chalkashlik tug'diradi.
      for (final line in _lines.values) {
        line.dispose();
      }
      _lines.clear();
      _direction = direction;
    });
  }

  Future<void> _save() async {
    final items = {for (final i in _visibleItems) i.key: i};
    final batch = <StockBatchLine>[];
    final invalid = <String>[];
    final shortages =
        <({String name, double need, double onHand, String unit})>[];

    for (final entry in _lines.entries) {
      final item = items[entry.key];
      if (item == null) continue;
      final qty = entry.value.qty;
      if (qty == null || qty <= 0) {
        invalid.add(item.name);
        continue;
      }
      // Chiqimda qoldiq manfiyga tushmasin (§14). Soni yuritilmaydigan
      // mahsulotga (`quantity IS NULL`) cheklov qo'llanmaydi.
      if (!_isInbound && item.tracked && qty > item.onHand + 1e-9) {
        shortages.add((
          name: item.name,
          need: qty,
          onHand: item.onHand,
          unit: item.unit,
        ));
        continue;
      }
      batch.add(
        StockBatchLine(
          kind: item.kind,
          itemId: item.id,
          direction: _direction,
          qty: qty,
          cost: _isInbound ? (entry.value.cost ?? 0) : 0,
          supplier: _isInbound ? entry.value.supplierText : null,
          note: _isInbound ? null : entry.value.noteText,
        ),
      );
    }

    if (invalid.isNotEmpty) {
      _snack('Miqdor kiritilmagan: ${invalid.join(', ')}', isError: true);
      return;
    }
    if (shortages.isNotEmpty) {
      _showShortages(InsufficientStockException(shortages));
      return;
    }
    if (batch.isEmpty) {
      _snack('Hech narsa tanlanmadi', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().applyStockBatch(batch);
      if (!mounted) return;
      for (final line in _lines.values) {
        line.dispose();
      }
      _lines.clear();
      setState(() => _saving = false);
      await _load();
      if (!mounted) return;
      _snack(
        _isInbound
            ? '${batch.length} ta qator kirim qilindi'
            : '${batch.length} ta qator chiqim qilindi',
      );
    } on InsufficientStockException catch (e) {
      // Ekran ochilgandan keyin boshqa joyda qoldiq kamaygan bo'lishi mumkin —
      // tranzaksiya bekor bo'ldi, hech narsa yozilmadi.
      if (!mounted) return;
      setState(() => _saving = false);
      await _load();
      if (!mounted) return;
      _showShortages(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Saqlashda xatolik: $e', isError: true);
    }
  }

  /// Chiqimda qoldiq yetmagan qatorlarni ko'rsatadi. Tanlov saqlanib qoladi —
  /// miqdorni tuzatib qayta urinish mumkin.
  void _showShortages(InsufficientStockException e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
        title: const Text('Qoldiq yetarli emas'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quyidagilarda chiqim miqdori qoldiqdan ko\'p:'),
              const SizedBox(height: 12),
              for (final s in e.shortages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${s.name} — chiqim ${QtyFormatter.withUnit(s.need, s.unit)}, '
                    'omborda ${QtyFormatter.withUnit(s.onHand, s.unit)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                'Hech narsa yozilmadi. Miqdorni kamaytiring yoki avval kirim '
                'qiling.',
                style: TextStyle(fontSize: 12, color: Theme.of(ctx).hintColor),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tushunarli'),
          ),
        ],
      ),
    );
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _visibleItems;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Sarlavha yo'q: "Kirim / Chiqim" so'zi tugmalarning o'zida turibdi
      // (§14) — ustidagi takroriy yozuv olib tashlandi.
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        toolbarHeight: 48,
      ),
      body: Column(
        children: [
          _toolbar(theme),
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
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _itemRow(theme, items[i]),
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
          // Kirim / Chiqim — knopka ko'rinishida (spec §4.5: select emas)
          _directionButton(
            theme,
            label: 'Kirim',
            icon: Icons.south_west_rounded,
            direction: StockDirection.inbound,
            color: Colors.green,
          ),
          const SizedBox(width: 10),
          _directionButton(
            theme,
            label: 'Chiqim',
            icon: Icons.north_east_rounded,
            direction: StockDirection.outbound,
            color: Colors.red,
          ),
          const SizedBox(width: 16),
          // Tarix va Inventarizatsiya — kirim/chiqim tugmalari yonida (§14).
          _secondaryButton(
            theme,
            label: 'Tarix',
            icon: Icons.history_rounded,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockHistoryNewScreen()),
            ),
          ),
          const SizedBox(width: 10),
          _secondaryButton(
            theme,
            label: 'Inventarizatsiya',
            icon: Icons.fact_check_outlined,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StocktakingScreen()),
              );
              // Inventarizatsiyadan keyin qoldiqlar o'zgargan bo'lishi mumkin.
              await _load();
            },
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Xomashyo yoki mahsulot qidirish...',
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

  Widget _directionButton(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required StockDirection direction,
    required MaterialColor color,
  }) {
    final selected = _direction == direction;
    return ElevatedButton.icon(
      onPressed: _saving ? null : () => _setDirection(direction),
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: selected
            ? color.shade600
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        foregroundColor: selected ? Colors.white : theme.hintColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Yordamchi tugma (Tarix, Inventarizatsiya) — yo'nalish tugmalari bilan
  /// bir qatorda tursin, lekin ulardan ajralib ko'rinsin.
  Widget _secondaryButton(
    ThemeData theme, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _saving ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _itemRow(ThemeData theme, _FlowItem item) {
    final line = _lines[item.key];
    final selected = line != null;

    return Container(
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: _saving ? null : () => _toggle(item),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: selected,
                      onChanged: _saving ? null : (_) => _toggle(item),
                    ),
                  ),
                  InventoryImage(
                    imagePath: item.imagePath,
                    placeholderIcon: item.kind == StockItemKind.ingredient
                        ? Icons.egg_outlined
                        : Icons.fastfood_outlined,
                    size: 38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.kind == StockItemKind.ingredient
                              ? 'Xomashyo'
                              : 'Mahsulot',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.tracked
                          ? 'Qoldiq: '
                                '${QtyFormatter.withUnit(item.onHand, item.unit)}'
                          : 'Qoldiq yuritilmaydi',
                      style: TextStyle(
                        fontSize: 13,
                        color: item.tracked ? null : theme.hintColor,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          if (selected)
            Padding(
              padding: const EdgeInsets.fromLTRB(64, 0, 24, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _input(
                      controller: line.qtyController,
                      label: 'Miqdor (${item.unit})',
                      numeric: true,
                      autofocus: true,
                      // Chiqimda ko'pi bilan qancha chiqarish mumkinligi
                      // darhol ko'rinsin — saqlashgacha kutilmaydi (§14).
                      helperText: _isInbound || !item.tracked
                          ? null
                          : 'Ko\'pi bilan ${QtyFormatter.format(item.onHand)}',
                      errorText: _overdraftText(item, line),
                      onChanged: _isInbound ? null : () => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isInbound) ...[
                    Expanded(
                      child: _input(
                        controller: line.costController,
                        label: 'Tannarx (1 ${item.unit})',
                        numeric: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _input(
                        controller: line.supplierController,
                        label: 'Kimdan olindi',
                      ),
                    ),
                  ] else
                    Expanded(
                      flex: 3,
                      child: _input(
                        controller: line.noteController,
                        label: 'Izoh (sabab)',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Chiqim miqdori qoldiqdan oshib ketgan bo'lsa xato matni, aks holda
  /// `null`.
  String? _overdraftText(_FlowItem item, _FlowLine line) {
    if (_isInbound || !item.tracked) return null;
    final qty = line.qty;
    if (qty == null || qty <= item.onHand + 1e-9) return null;
    return 'Omborda ${QtyFormatter.format(item.onHand)} ${item.unit} bor';
  }

  Widget _input({
    required TextEditingController controller,
    required String label,
    bool numeric = false,
    bool autofocus = false,
    String? helperText,
    String? errorText,
    VoidCallback? onChanged,
  }) {
    return TextField(
      controller: controller,
      enabled: !_saving,
      autofocus: autofocus,
      onChanged: onChanged == null ? null : (_) => onChanged(),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        errorText: errorText,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    final count = _lines.length;
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
            count == 0 ? 'Hech narsa tanlanmadi' : '$count ta qator tanlandi',
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: (_saving || count == 0) ? null : _save,
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
            label: Text(_isInbound ? 'Kirim qilish' : 'Chiqim qilish'),
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

/// Ro'yxatdagi bitta birlik — xomashyo yoki mahsulot, bir xil ko'rinishda.
class _FlowItem {
  final StockItemKind kind;
  final int id;
  final String name;
  final String unit;
  final double onHand;
  final double avgCost;
  final String? imagePath;

  /// Soni yuritiladimi. Mahsulotda `quantity IS NULL` bo'lsa — yuritilmaydi,
  /// unga chiqim cheklovi qo'llanmaydi. Xomashyoda har doim `true`.
  final bool tracked;

  _FlowItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.unit,
    required this.onHand,
    required this.avgCost,
    this.imagePath,
    this.tracked = true,
  });

  /// Xomashyo va mahsulot id'lari to'qnashmasligi uchun turi bilan birga.
  String get key => '${kind.name}:$id';

  factory _FlowItem.fromIngredient(Map<String, dynamic> map) {
    final ing = Ingredient.fromMap(map);
    return _FlowItem(
      kind: StockItemKind.ingredient,
      id: ing.id!,
      name: ing.name,
      unit: ing.baseUnit,
      onHand: (map['on_hand'] as num?)?.toDouble() ?? 0,
      avgCost: ing.avgCost,
      imagePath: ing.imagePath,
    );
  }

  factory _FlowItem.fromProduct(Product p) {
    return _FlowItem(
      kind: StockItemKind.product,
      id: p.id!,
      name: p.name,
      unit: p.unit ?? 'dona',
      onHand: p.quantity ?? 0,
      avgCost: p.avgCost,
      imagePath: p.imagePath,
      tracked: p.quantity != null,
    );
  }
}

/// Tanlangan qatorning kiritish maydonlari.
class _FlowLine {
  final TextEditingController qtyController = TextEditingController();
  final TextEditingController costController;
  final TextEditingController supplierController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  _FlowLine({double cost = 0})
    : costController = TextEditingController(
        text: cost > 0 ? cost.toStringAsFixed(0) : '',
      );

  double? get qty => _parse(qtyController.text);
  double? get cost => _parse(costController.text);

  String? get supplierText {
    final v = supplierController.text.trim();
    return v.isEmpty ? null : v;
  }

  String? get noteText {
    final v = noteController.text.trim();
    return v.isEmpty ? null : v;
  }

  static double? _parse(String v) =>
      double.tryParse(v.trim().replaceAll(',', '.'));

  void dispose() {
    qtyController.dispose();
    costController.dispose();
    supplierController.dispose();
    noteController.dispose();
  }
}
