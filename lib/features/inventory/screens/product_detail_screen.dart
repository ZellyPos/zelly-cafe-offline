import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../models/inventory_models.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';
import '../widgets/food_cost_badge.dart';
import '../widgets/inventory_image.dart';
import '../widgets/produce_dialog.dart';
import '../widgets/resale_stock_in_dialog.dart';

/// Mahsulot detali (§4.3).
///
/// Mahsulot ma'lumotlari **faqat ko'rish** uchun (tahrir "Mahsulotlar"
/// bo'limida). Bu yerda **retsept** boshqariladi: xomashyo qo'shish, o'chirish
/// va sarf miqdorini tahrirlash.
///
/// `resale` mahsulotda retsept bo'lmaydi — o'rniga tannarx va "Kirim" amali
/// ko'rsatiladi.
///
/// Ombor o'zgarsa (pishirish/kirim/retsept) `true` bilan qaytadi.
class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Product _product;

  /// Tahrirlanayotgan retsept qatorlari (saqlanmaguncha faqat xotirada).
  List<_RecipeLine> _lines = [];

  /// Barcha xomashyolar — id bo'yicha (qoldiq va min. miqdor uchun).
  Map<int, _IngredientInfo> _ingredients = {};

  double _yieldQty = 1;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  bool _changedStock = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<InventoryProvider>();
    try {
      final ingRows = await provider.getIngredientsWithStock();
      final ingredients = <int, _IngredientInfo>{};
      for (final row in ingRows) {
        final ing = Ingredient.fromMap(row);
        if (ing.id != null) {
          ingredients[ing.id!] = _IngredientInfo(
            ingredient: ing,
            onHand: (row['on_hand'] as num?)?.toDouble() ?? 0,
          );
        }
      }

      List<_RecipeLine> lines = [];
      double yieldQty = 1;
      final productId = _product.id;
      if (productId != null && _product.isPrepared) {
        final recipe = await provider.getRecipe(productId);
        if (recipe != null) {
          yieldQty = recipe.yieldQty;
          lines = recipe.items
              .map(
                (it) => _RecipeLine(ingredientId: it.ingredientId, qty: it.qty),
              )
              .toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _ingredients = ingredients;
        _lines = lines;
        _yieldQty = yieldQty;
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Yuklashda xatolik: $e', isError: true);
    }
  }

  /// Mahsulot sonini bazadan qayta o'qiydi (pishirish/kirimdan keyin).
  Future<void> _reloadProduct() async {
    final id = _product.id;
    if (id == null) return;
    final provider = context.read<InventoryProvider>();
    final rows = _product.isPrepared
        ? await provider.getPreparedProducts()
        : await provider.getResaleProducts();
    final row = rows.where((m) => m['id'] == id).firstOrNull;
    if (row != null && mounted) {
      setState(() => _product = Product.fromMap(row));
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

  // ─── Food-cost (§3) ───────────────────────────────────────────────────────

  /// Bir dona mahsulotning retsept tannarxi — **joriy tahrirdan** hisoblanadi,
  /// shuning uchun miqdorni o'zgartirganda darhol yangilanadi (saqlashni
  /// kutmaydi): `Σ(qty × avg_cost) / yield_qty`.
  double? get _recipeCost {
    if (_lines.isEmpty || _yieldQty <= 0) return null;
    var total = 0.0;
    for (final line in _lines) {
      final avg = _ingredients[line.ingredientId]?.ingredient.avgCost ?? 0;
      total += line.currentQty * avg;
    }
    return total <= 0 ? null : total / _yieldQty;
  }

  /// Tannarxi kiritilmagan xomashyolar — hisob to'liq emasligini bildiradi.
  List<String> get _missingCostNames => _lines
      .map((l) => _ingredients[l.ingredientId]?.ingredient)
      .nonNulls
      .where((i) => i.avgCost <= 0)
      .map((i) => i.name)
      .toList();

  // ─── Retsept tahriri ──────────────────────────────────────────────────────

  /// Retseptda hali ishlatilmagan xomashyolar.
  List<_IngredientInfo> get _available {
    final used = _lines.map((l) => l.ingredientId).toSet();
    return _ingredients.values
        .where((i) => !used.contains(i.ingredient.id))
        .toList()
      ..sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
  }

  Future<void> _addIngredient() async {
    final available = _available;
    if (available.isEmpty) {
      _snack('Qo\'shiladigan xomashyo qolmadi', isError: true);
      return;
    }
    final picked = await showDialog<_IngredientInfo>(
      context: context,
      builder: (ctx) => _IngredientPickerDialog(items: available),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lines.add(_RecipeLine(ingredientId: picked.ingredient.id!, qty: 0));
      _dirty = true;
    });
  }

  void _removeLine(_RecipeLine line) {
    setState(() {
      line.dispose();
      _lines.remove(line);
      _dirty = true;
    });
  }

  Future<void> _saveRecipe() async {
    final productId = _product.id;
    if (productId == null) return;

    // Miqdori 0 bo'lgan qator retseptda ma'nosiz — saqlashga yo'l qo'ymaymiz.
    for (final line in _lines) {
      if (line.currentQty <= 0) {
        final name = _ingredients[line.ingredientId]?.ingredient.name ?? '?';
        _snack('"$name" uchun musbat miqdor kiriting', isError: true);
        return;
      }
    }
    if (_yieldQty <= 0) {
      _snack('Chiqish miqdori musbat bo\'lishi kerak', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().saveRecipe(
        Recipe(
          productId: productId,
          yieldQty: _yieldQty,
          items: _lines
              .map(
                (l) => RecipeItem(
                  recipeId: 0, // repozitoriy yangi recipe_id bilan almashtiradi
                  ingredientId: l.ingredientId,
                  qty: l.currentQty,
                ),
              )
              .toList(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dirty = false;
      });
      _snack('Retsept saqlandi');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Saqlashda xatolik: $e', isError: true);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!_dirty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Saqlanmagan o\'zgarish'),
        content: const Text(
          'Retseptdagi o\'zgarishlar saqlanmadi. Chiqilsinmi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Qolaman'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Chiqaman'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  /// Saqlanmagan o'zgarish bo'lsa so'raydi, so'ng ekrandan chiqadi.
  Future<void> _tryPop() async {
    final canLeave = await _confirmLeave();
    if (!canLeave) return;
    if (!mounted) return;
    Navigator.of(context).pop(_changedStock);
  }

  // ─── Amallar ──────────────────────────────────────────────────────────────

  Future<void> _produce() async {
    final saved = await ProduceDialog.show(context, initialProduct: _product);
    if (saved == true) {
      _changedStock = true;
      await _reloadProduct();
      await _load();
    }
  }

  Future<void> _stockIn() async {
    final saved = await ResaleStockInDialog.show(context, _product);
    if (saved == true) {
      _changedStock = true;
      await _reloadProduct();
    }
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _tryPop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_product.name),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _tryPop,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _product.isPrepared
                  ? ElevatedButton.icon(
                      onPressed: _produce,
                      icon: const Icon(
                        Icons.local_fire_department_rounded,
                        size: 18,
                      ),
                      label: const Text('Pishirish'),
                      style: _actionStyle,
                    )
                  : ElevatedButton.icon(
                      onPressed: _stockIn,
                      icon: const Icon(
                        Icons.add_shopping_cart_rounded,
                        size: 18,
                      ),
                      label: const Text('Kirim'),
                      style: _actionStyle,
                    ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _infoCard(theme),
                  const SizedBox(height: 20),
                  if (_product.isPrepared)
                    _recipeCard(theme)
                  else
                    _resaleCard(theme),
                ],
              ),
      ),
    );
  }

  ButtonStyle get _actionStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.black,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );

  Widget _infoCard(ThemeData theme) {
    final qty = _product.quantity ?? 0;
    return _card(
      theme,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InventoryImage(
            imagePath: _product.imagePath,
            placeholderIcon: Icons.fastfood_outlined,
            size: 96,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _product.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _stat('Kategoriya', _product.category),
                    _stat(
                      'Narx',
                      PriceFormatter.formatWithCurrency(_product.price),
                    ),
                    _stat(
                      'Qoldiq',
                      '${QtyFormatter.format(qty)} ${_product.unit ?? 'dona'}',
                      color: qty > 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    _stat(
                      'Turi',
                      _product.isPrepared ? 'Tayyorlanadi' : 'Sotib olinadi',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
      ],
    );
  }

  // ─── Retsept bloki ────────────────────────────────────────────────────────

  Widget _recipeCard(ThemeData theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Retsept',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _saving ? null : _addIngredient,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Xomashyo qo\'shish'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (_saving || !_dirty) ? null : _saveRecipe,
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
                style: _actionStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _yieldRow(theme),
          const SizedBox(height: 16),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 44,
                      color: theme.hintColor.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Retsept bo\'sh — xomashyo qo\'shing',
                      style: TextStyle(color: theme.hintColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Retseptsiz pishirishda xomashyo chegirilmaydi',
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _recipeHeader(theme),
            const Divider(height: 16),
            ..._lines.map((l) => _recipeRow(theme, l)),
            const Divider(height: 24),
            _foodCostRow(theme),
          ],
        ],
      ),
    );
  }

  /// "1 retseptdan nechta chiqadi" — sarf shu songa bo'linadi (§C).
  Widget _yieldRow(ThemeData theme) {
    return Row(
      children: [
        Text(
          'Bir retseptdan chiqadi:',
          style: TextStyle(fontSize: 13, color: theme.hintColor),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: TextFormField(
            initialValue: QtyFormatter.format(_yieldQty),
            enabled: !_saving,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (v) {
              final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
              setState(() {
                _yieldQty = parsed ?? 0;
                _dirty = true;
              });
            },
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_product.unit ?? 'dona'} — quyidagi sarf shu songa mo\'ljallangan',
          style: TextStyle(fontSize: 12, color: theme.hintColor),
        ),
      ],
    );
  }

  /// Retsept tannarxi va food-cost foizi (§3).
  Widget _foodCostRow(ThemeData theme) {
    final cost = _recipeCost;
    final missing = _missingCostNames;
    final percent = FoodCostBadge.percentOf(cost, _product.price);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calculate_outlined, size: 18, color: theme.hintColor),
            const SizedBox(width: 8),
            Text(
              'Bir dona tannarxi: ',
              style: TextStyle(color: theme.hintColor, fontSize: 13),
            ),
            Text(
              cost == null
                  ? 'hisoblab bo\'lmadi'
                  : PriceFormatter.formatWithCurrency(cost),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 20),
            if (percent != null) ...[
              Text(
                'Food-cost: ',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
              FoodCostBadge(cost: cost, price: _product.price),
              const SizedBox(width: 10),
              Text(
                percent <= 35
                    ? 'maqbul'
                    : (percent <= 45 ? 'yuqoriroq' : 'juda yuqori'),
                style: TextStyle(
                  fontSize: 12,
                  color: FoodCostBadge.colorFor(percent),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tannarxi kiritilmagan: ${missing.join(', ')} — hisob '
                    'to\'liq emas. Tannarx "Kirim" qilinganda avtomatik '
                    'to\'ldiriladi.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _recipeHeader(ThemeData theme) {
    final style = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: theme.hintColor,
    );
    return Row(
      children: [
        Expanded(flex: 3, child: Text('Xomashyo', style: style)),
        Expanded(flex: 2, child: Text('Sarf miqdori', style: style)),
        Expanded(flex: 2, child: Text('Omborda', style: style)),
        Expanded(flex: 2, child: Text('Min. miqdor', style: style)),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _recipeRow(ThemeData theme, _RecipeLine line) {
    final info = _ingredients[line.ingredientId];
    final unit = info?.ingredient.baseUnit ?? '';
    final isLow = info?.isLow ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                InventoryImage(
                  imagePath: info?.ingredient.imagePath,
                  placeholderIcon: Icons.egg_outlined,
                  size: 34,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    info?.ingredient.name ?? 'O\'chirilgan xomashyo',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: TextFormField(
                controller: line.controller,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                onChanged: (_) {
                  if (!_dirty) setState(() => _dirty = true);
                },
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: unit,
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
            child: Text(
              info == null ? '—' : '${QtyFormatter.format(info.onHand)} $unit',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isLow ? Colors.red.shade700 : null,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              info == null ? '—' : '${QtyFormatter.format(info.ingredient.minStock)} $unit',
              style: TextStyle(fontSize: 13, color: theme.hintColor),
            ),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              tooltip: 'O\'chirish',
              onPressed: _saving ? null : () => _removeLine(line),
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.red.shade400,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Resale bloki ─────────────────────────────────────────────────────────

  Widget _resaleCard(ThemeData theme) {
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sotib olinadigan mahsulot',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Bu mahsulot tayyorlanmaydi — retsepti yo\'q. Qoldiq "Kirim" '
            'orqali to\'ldiriladi.',
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _stat(
                'O\'rtacha tannarx',
                _product.avgCost > 0
                    ? PriceFormatter.formatWithCurrency(_product.avgCost)
                    : '—',
              ),
              const SizedBox(width: 32),
              _stat(
                'Ustama',
                _product.avgCost > 0
                    ? PriceFormatter.formatWithCurrency(
                        _product.price - _product.avgCost,
                      )
                    : '—',
              ),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Food-cost',
                    style: TextStyle(fontSize: 11, color: theme.hintColor),
                  ),
                  const SizedBox(height: 4),
                  FoodCostBadge(cost: _product.avgCost, price: _product.price),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

}

/// Retseptning bitta qatori — o'zining matn kontrolleri bilan.
class _RecipeLine {
  final int ingredientId;
  final TextEditingController controller;

  _RecipeLine({required this.ingredientId, required double qty})
    : controller = TextEditingController(
        text: qty > 0
            ? (qty == qty.roundToDouble()
                  ? qty.toStringAsFixed(0)
                  : qty.toStringAsFixed(2))
            : '',
      );

  double get currentQty =>
      double.tryParse(controller.text.trim().replaceAll(',', '.')) ?? 0;

  void dispose() => controller.dispose();
}

/// Xomashyo + qoldiq (retsept qatorlarida ko'rsatish uchun).
class _IngredientInfo {
  final Ingredient ingredient;
  final double onHand;

  _IngredientInfo({required this.ingredient, required this.onHand});

  bool get isLow => ingredient.minStock > 0 && onHand <= ingredient.minStock;
}

/// Retseptga xomashyo tanlash dialogi.
class _IngredientPickerDialog extends StatefulWidget {
  final List<_IngredientInfo> items;

  const _IngredientPickerDialog({required this.items});

  @override
  State<_IngredientPickerDialog> createState() =>
      _IngredientPickerDialogState();
}

class _IngredientPickerDialogState extends State<_IngredientPickerDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _query.toLowerCase();
    final items = q.isEmpty
        ? widget.items
        : widget.items
              .where((i) => i.ingredient.name.toLowerCase().contains(q))
              .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Xomashyo tanlash',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Qidirish...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.04,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text(
                        'Hech narsa topilmadi',
                        style: TextStyle(color: theme.hintColor),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final info = items[i];
                        return ListTile(
                          leading: InventoryImage(
                            imagePath: info.ingredient.imagePath,
                            placeholderIcon: Icons.egg_outlined,
                            size: 40,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text(info.ingredient.name),
                          subtitle: Text(
                            'Omborda: ${info.onHand} '
                            '${info.ingredient.baseUnit}',
                          ),
                          onTap: () => Navigator.of(context).pop(info),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
