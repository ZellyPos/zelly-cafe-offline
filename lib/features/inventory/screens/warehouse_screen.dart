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
import 'ingredient_detail_screen.dart';
import 'product_detail_screen.dart';

/// Ombor bosh sahifasi (§4.1) — ikki tab: **Mahsulotlar** va **Xomashyolar**.
///
/// - Mahsulotlar: `prepared` da "Pishirish", `resale` da "Kirim" amali.
/// - Xomashyolar: qoldiq va min. miqdor; pishirish tugmasi yo'q.
///
/// Har ikkala tabda qidiruv va karta/jadval ko'rinish almashtirgichi bor.
class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();

  /// Joriy tab (0 — mahsulotlar, 1 — xomashyolar). Swipe bilan ham
  /// o'zgargani uchun alohida saqlanadi: toolbar va amal tugmasi shunga
  /// qarab quriladi.
  int _tabIndex = 0;

  /// Karta/jadval ko'rinishi — ekran yopilib qayta ochilsa saqlanadi, lekin
  /// dastur qayta ishga tushganda default holatga qaytadi (§2). Shu sabab
  /// diskka yozilmaydi: `static` maydon faqat joriy sessiyada yashaydi.
  static bool _gridViewPref = true;

  List<Product> _products = [];
  List<_IngredientRow> _ingredients = [];

  /// Retsept tannarxi (food-cost uchun): productId → 1 dona tannarxi.
  Map<int, double> _recipeCosts = {};
  bool _loading = true;
  String _query = '';

  /// Mahsulot qoldiq filtri (§3).
  _StockFilter _stockFilter = _StockFilter.all;

  bool get _gridView => _gridViewPref;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        // Swipe'da `indexIsChanging` false bo'ladi — shuning uchun indeksning
        // o'zini kuzatamiz. Tab almashganda qidiruv va filtr tozalanadi:
        // ikkala ro'yxat turlicha, eski so'rov chalkashtiradi.
        if (_tabController.index == _tabIndex) return;
        _searchController.clear();
        setState(() {
          _tabIndex = _tabController.index;
          _query = '';
          _stockFilter = _StockFilter.all;
        });
      });
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = context.read<InventoryProvider>();
    try {
      final prepared = await provider.getPreparedProducts();
      final resale = await provider.getResaleProducts();
      final ingredients = await provider.getIngredientsWithStock();
      // Barcha retsept tannarxlari bitta so'rovda (N+1 bo'lmasin).
      final recipeCosts = await provider.getRecipeCosts();
      if (!mounted) return;
      setState(() {
        _products = [
          ...prepared.map((m) => Product.fromMap(m)),
          ...resale.map((m) => Product.fromMap(m)),
        ]..sort((a, b) => a.name.compareTo(b.name));
        _ingredients = ingredients.map(_IngredientRow.fromMap).toList();
        _recipeCosts = recipeCosts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Yuklashda xatolik: $e', isError: true);
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

  // ─── Filtrlangan ro'yxatlar ───────────────────────────────────────────────

  List<Product> get _filteredProducts {
    final q = _query.toLowerCase();
    return _products.where((p) {
      final inStock = (p.quantity ?? 0) > 0;
      switch (_stockFilter) {
        case _StockFilter.all:
          break;
        case _StockFilter.inStock:
          if (!inStock) return false;
        case _StockFilter.outOfStock:
          if (inStock) return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList();
  }

  List<_IngredientRow> get _filteredIngredients {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _ingredients;
    return _ingredients
        .where((i) => i.ingredient.name.toLowerCase().contains(q))
        .toList();
  }

  // ─── Amallar ──────────────────────────────────────────────────────────────

  Future<void> _openProduce([Product? product]) async {
    final saved = await ProduceDialog.show(context, initialProduct: product);
    if (saved == true) await _load();
  }

  Future<void> _openResaleIn(Product product) async {
    final saved = await ResaleStockInDialog.show(context, product);
    if (saved == true) {
      await _load();
      if (mounted) _snack('${product.name} — kirim saqlandi');
    }
  }

  Future<void> _openProductDetail(Product product) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
    if (changed == true) await _load();
  }

  /// Mahsulotning 1 dona tannarxi: `prepared` uchun retsept tannarxi,
  /// `resale` uchun kirimdan hisoblangan o'rtacha tannarx.
  double? _costOf(Product p) {
    if (p.isResale) return p.avgCost > 0 ? p.avgCost : null;
    return p.id == null ? null : _recipeCosts[p.id];
  }

  /// Yangi xomashyo yaratish. Boshlang'ich miqdor kiritilsa u **kirim
  /// harakati** sifatida yoziladi (§6) — shunda tarix uzilmaydi. Rasm va
  /// tannarx keyin detail ekranida to'ldiriladi.
  Future<void> _addIngredient() async {
    final result = await showDialog<_NewIngredientResult>(
      context: context,
      builder: (_) => const _NewIngredientDialog(),
    );
    if (result == null || !mounted) return;
    final created = result.ingredient;
    try {
      final provider = context.read<InventoryProvider>();
      final id = await provider.addIngredient(created);
      if (result.initialQty > 0) {
        await provider.stockIn(ingredientId: id, qty: result.initialQty);
      }
      await _load();
      if (mounted) _snack('${created.name} qo\'shildi');
    } catch (e) {
      if (mounted) _snack('Xatolik: $e', isError: true);
    }
  }

  Future<void> _openIngredientDetail(_IngredientRow row) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => IngredientDetailScreen(
          ingredient: row.ingredient,
          onHand: row.onHand,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Ombor'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _gridView ? 'Jadval ko\'rinishi' : 'Karta ko\'rinishi',
            onPressed: () => setState(() => _gridViewPref = !_gridViewPref),
            icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Yangilash',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _tabSwitcher(theme),
          _toolbar(theme),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    // Sensorli ekranda swipe bilan ham o'tadi.
                    controller: _tabController,
                    children: [_productsTab(theme), _ingredientsTab(theme)],
                  ),
          ),
        ],
      ),
    );
  }

  /// Mahsulotlar / Xomashyolar almashtirgichi — TabBar emas, bosiladigan
  /// segment knopkalari. Swipe TabBarView orqali baribir ishlaydi.
  ///
  /// Amal tugmasi (§1, §6) shu qatorning **o'ng tomonida**: mahsulotlar
  /// tabida "Pishirish", xomashyolar tabida "Xomashyo qo'shish".
  Widget _tabSwitcher(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _switcherButton(
                  theme,
                  0,
                  Icons.fastfood_outlined,
                  'Mahsulotlar',
                ),
                const SizedBox(width: 4),
                _switcherButton(theme, 1, Icons.egg_outlined, 'Xomashyolar'),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _tabAction(),
        ],
      ),
    );
  }

  /// Tabga bog'liq asosiy amal tugmasi.
  Widget _tabAction() {
    final isProductsTab = _tabIndex == 0;
    return ElevatedButton.icon(
      onPressed: _loading
          ? null
          : isProductsTab
          ? () => _openProduce()
          : _addIngredient,
      icon: Icon(
        isProductsTab ? Icons.local_fire_department_rounded : Icons.add_rounded,
        size: 20,
      ),
      label: Text(
        isProductsTab ? 'Pishirish' : 'Xomashyo qo\'shish',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isProductsTab
            ? Colors.orange.shade700
            : Colors.teal.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _switcherButton(
    ThemeData theme,
    int index,
    IconData icon,
    String label,
  ) {
    final selected = _tabIndex == index;
    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 1 : 0,
      child: InkWell(
        onTap: selected ? null : () => _tabController.animateTo(index),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbar(ThemeData theme) {
    final isProductsTab = _tabIndex == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: isProductsTab
                    ? 'Mahsulot qidirish...'
                    : 'Xomashyo qidirish...',
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
          if (isProductsTab) ...[
            const SizedBox(width: 16),
            _stockChip('Hammasi', _StockFilter.all),
            const SizedBox(width: 8),
            _stockChip('Mavjud', _StockFilter.inStock),
            const SizedBox(width: 8),
            _stockChip('Mavjud emas', _StockFilter.outOfStock),
          ],
        ],
      ),
    );
  }

  /// Qoldiq bo'yicha filtr (§3).
  Widget _stockChip(String label, _StockFilter value) {
    return ChoiceChip(
      label: Text(label),
      selected: _stockFilter == value,
      onSelected: (_) => setState(() => _stockFilter = value),
      showCheckmark: false,
    );
  }

  // ─── Mahsulotlar tabi ─────────────────────────────────────────────────────

  Widget _productsTab(ThemeData theme) {
    final items = _filteredProducts;
    if (items.isEmpty) {
      return _empty(
        theme,
        Icons.fastfood_outlined,
        _query.isEmpty && _stockFilter == _StockFilter.all
            ? 'Mahsulotlar mavjud emas'
            : 'Hech narsa topilmadi',
      );
    }

    if (!_gridView) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _productListTile(theme, items[i]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 0.92,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _productCard(theme, items[i]),
    );
  }

  Widget _productCard(ThemeData theme, Product p) {
    final qty = p.quantity ?? 0;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.12)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProductDetail(p),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InventoryImage(
                    imagePath: p.imagePath,
                    placeholderIcon: Icons.fastfood_outlined,
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _typeBadge(p)),
                  FoodCostBadge(
                    cost: _costOf(p),
                    price: p.price,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                p.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                p.category,
                style: TextStyle(fontSize: 12, color: theme.hintColor),
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PriceFormatter.formatWithCurrency(p.price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Qoldiq: ${QtyFormatter.format(qty)} ${p.unit ?? 'dona'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _stockColor(qty),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _productAction(p),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productListTile(ThemeData theme, Product p) {
    final qty = p.quantity ?? 0;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openProductDetail(p),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              InventoryImage(
                imagePath: p.imagePath,
                placeholderIcon: Icons.fastfood_outlined,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      p.category,
                      style: TextStyle(fontSize: 12, color: theme.hintColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Expanded(child: _typeBadge(p)),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      PriceFormatter.formatWithCurrency(p.price),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    FoodCostBadge(
                      cost: _costOf(p),
                      price: p.price,
                      compact: true,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  '${QtyFormatter.format(qty)} ${p.unit ?? 'dona'}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _stockColor(qty),
                  ),
                ),
              ),
              _productAction(p),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(Product p) {
    final isPrepared = p.isPrepared;
    final color = isPrepared ? Colors.orange : Colors.blue;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          isPrepared ? 'Tayyorlanadi' : 'Sotib olinadi',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.shade800,
          ),
        ),
      ),
    );
  }

  Widget _productAction(Product p) {
    if (p.isPrepared) {
      return IconButton(
        tooltip: 'Pishirish',
        onPressed: () => _openProduce(p),
        icon: const Icon(Icons.local_fire_department_rounded),
        color: Colors.orange.shade800,
        style: IconButton.styleFrom(
          backgroundColor: Colors.orange.withValues(alpha: 0.1),
        ),
      );
    }
    return IconButton(
      tooltip: 'Kirim',
      onPressed: () => _openResaleIn(p),
      icon: const Icon(Icons.add_shopping_cart_rounded),
      color: Colors.blue.shade700,
      style: IconButton.styleFrom(
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
      ),
    );
  }

  // ─── Xomashyolar tabi ─────────────────────────────────────────────────────

  Widget _ingredientsTab(ThemeData theme) {
    final items = _filteredIngredients;
    if (items.isEmpty) {
      return _empty(
        theme,
        Icons.egg_outlined,
        _query.isEmpty ? 'Xomashyolar mavjud emas' : 'Hech narsa topilmadi',
      );
    }

    if (!_gridView) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _ingredientListTile(theme, items[i]),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        childAspectRatio: 1.15,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _ingredientCard(theme, items[i]),
    );
  }

  Widget _ingredientCard(ThemeData theme, _IngredientRow row) {
    final ing = row.ingredient;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: row.isLow
              ? Colors.red.withValues(alpha: 0.4)
              : theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openIngredientDetail(row),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InventoryImage(
                    imagePath: ing.imagePath,
                    placeholderIcon: Icons.egg_outlined,
                    size: 52,
                  ),
                  const SizedBox(width: 12),
                  if (row.isLow) _lowBadge(),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ing.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                '${QtyFormatter.format(row.onHand)} ${ing.baseUnit}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: row.isLow ? Colors.red.shade700 : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Min: ${QtyFormatter.format(ing.minStock)} ${ing.baseUnit}'
                '${ing.avgCost > 0 ? ' · ${PriceFormatter.format(ing.avgCost)}/${ing.baseUnit}' : ''}',
                style: TextStyle(fontSize: 11, color: theme.hintColor),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ingredientListTile(ThemeData theme, _IngredientRow row) {
    final ing = row.ingredient;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _openIngredientDetail(row),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: row.isLow
                  ? Colors.red.withValues(alpha: 0.4)
                  : theme.dividerColor.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            children: [
              InventoryImage(
                imagePath: ing.imagePath,
                placeholderIcon: Icons.egg_outlined,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Text(
                  ing.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Text(
                  '${QtyFormatter.format(row.onHand)} ${ing.baseUnit}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: row.isLow ? Colors.red.shade700 : null,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Min: ${QtyFormatter.format(ing.minStock)}',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ),
              Expanded(
                child: Text(
                  ing.avgCost > 0
                      ? '${PriceFormatter.format(ing.avgCost)}/${ing.baseUnit}'
                      : '—',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              SizedBox(width: 40, child: row.isLow ? _lowBadge() : null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lowBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Kam',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _empty(ThemeData theme, IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.hintColor.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: theme.hintColor, fontSize: 16)),
        ],
      ),
    );
  }

  /// Mahsulot qoldig'i rangi (§5): bor bo'lsa yashil, tugagan (yoki manfiy)
  /// bo'lsa qizil. Karta va jadval ko'rinishida bir xil.
  static Color _stockColor(double qty) =>
      qty > 0 ? Colors.green.shade700 : Colors.red.shade700;

}

/// Mahsulotlar tabidagi qoldiq filtri (§3).
enum _StockFilter { all, inStock, outOfStock }

/// Xomashyo + uning qoldig'i (`getIngredientsWithStock` natijasi).
class _IngredientRow {
  final Ingredient ingredient;
  final double onHand;

  _IngredientRow({required this.ingredient, required this.onHand});

  factory _IngredientRow.fromMap(Map<String, dynamic> map) {
    return _IngredientRow(
      ingredient: Ingredient.fromMap(map),
      onHand: (map['on_hand'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Qoldiq minimal darajadan past (min > 0 bo'lganda).
  bool get isLow => ingredient.minStock > 0 && onHand <= ingredient.minStock;
}

/// Yangi xomashyo dialogining natijasi: xomashyoning o'zi va **boshlang'ich
/// qoldiq** (§6). Qoldiq 0 dan katta bo'lsa kirim harakati sifatida yoziladi.
class _NewIngredientResult {
  final Ingredient ingredient;
  final double initialQty;

  _NewIngredientResult(this.ingredient, this.initialQty);
}

/// Yangi xomashyo qo'shish dialogi — nom, birlik (knopkalar bilan), miqdor,
/// min. miqdor (§6).
class _NewIngredientDialog extends StatefulWidget {
  const _NewIngredientDialog();

  @override
  State<_NewIngredientDialog> createState() => _NewIngredientDialogState();
}

class _NewIngredientDialogState extends State<_NewIngredientDialog> {
  /// Tayyor birliklar — select emas, knopka ko'rinishida tanlanadi (§6).
  /// Ro'yxatda yo'q birlik uchun "Boshqa" tanlanadi va matn kiritiladi.
  static const _units = ['g', 'kg', 'ml', 'l', 'dona'];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '0');
  final _minController = TextEditingController(text: '0');
  final _customUnitController = TextEditingController();

  String _unit = 'g';
  bool _customUnit = false;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _minController.dispose();
    _customUnitController.dispose();
    super.dispose();
  }

  String get _effectiveUnit =>
      _customUnit ? _customUnitController.text.trim() : _unit;

  static double _parse(String raw) =>
      double.tryParse(raw.trim().replaceAll(',', '.')) ?? 0;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_effectiveUnit.isEmpty) return;
    Navigator.of(context).pop(
      _NewIngredientResult(
        Ingredient(
          name: _nameController.text.trim(),
          baseUnit: _effectiveUnit,
          minStock: _parse(_minController.text),
        ),
        _parse(_qtyController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Yangi xomashyo'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nomi',
                  prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom kiriting' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 20),
              Text(
                'O\'lchov birligi',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in _units) _unitButton(u, u),
                  _unitButton('Boshqa', null),
                ],
              ),
              if (_customUnit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customUnitController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Birlik nomi',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Birlik kiriting'
                      : null,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Miqdori',
                        suffixText: _effectiveUnit.isEmpty
                            ? null
                            : _effectiveUnit,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Min. miqdor',
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Miqdor kiritilsa boshlang\'ich kirim sifatida yoziladi. '
                'Rasm va tannarx keyin xomashyo sahifasida to\'ldiriladi.',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Bekor qilish'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Qo\'shish'),
        ),
      ],
    );
  }

  /// Birlik knopkasi. [value] `null` bo'lsa — "Boshqa" (qo'lda kiritish).
  Widget _unitButton(String label, String? value) {
    final selected = value == null ? _customUnit : (!_customUnit && _unit == value);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(() {
        _customUnit = value == null;
        if (value != null) _unit = value;
      }),
    );
  }
}
