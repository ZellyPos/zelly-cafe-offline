import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/services/inventory_service.dart';
import '../../../core/utils/qty_formatter.dart';
import '../../../models/product.dart';
import '../../../providers/inventory_provider.dart';

/// Pishirish modali (§4.2).
///
/// Tayyorlanadigan (`prepared`) mahsulotlar ro'yxati — bir nechtasini tanlab,
/// har biriga son kiritiladi. Saqlashda [InventoryProvider.produce] chaqiriladi:
/// retsept bo'yicha xomashyo chegiriladi va tayyor son oshadi (bitta
/// tranzaksiyada). Xomashyo yetmasa yetishmovchilik ro'yxati ko'rsatiladi.
///
/// Muvaffaqiyatli saqlansa `true` qaytaradi.
class ProduceDialog extends StatefulWidget {
  /// Modal ochilganda darhol tanlangan bo'ladigan mahsulot (kartadagi
  /// "Pishirish" tugmasidan kelganda).
  final Product? initialProduct;

  const ProduceDialog({super.key, this.initialProduct});

  static Future<bool?> show(BuildContext context, {Product? initialProduct}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true, // tashqi bosishda yopiladi (§4.2)
      builder: (_) => ProduceDialog(initialProduct: initialProduct),
    );
  }

  @override
  State<ProduceDialog> createState() => _ProduceDialogState();
}

class _ProduceDialogState extends State<ProduceDialog>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _controllers = <int, TextEditingController>{};

  /// Kategoriya TabBar'i (§22). Modal tor bo'lgani uchun ixcham: faqat
  /// matn, rasm va rang yo'q — asosiy vazifa mahsulot tanlab son kiritish.
  TabController? _categoryController;

  /// Har mahsulotning son maydoni uchun focus — tanlanganda darhol shu
  /// maydonga focus tushadi (§4).
  final _focusNodes = <int, FocusNode>{};

  List<Product> _all = [];
  final _selected = <int>{};
  bool _loading = true;
  bool _saving = false;
  String _query = '';

  /// Tanlangan kategoriya (§22).
  String _category = _kAllCategories;

  /// Modaldagi mahsulotlardan olingan kategoriyalar, birinchisi "Hammasi".
  List<String> get _categories {
    final set = <String>{};
    for (final p in _all) {
      final c = p.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return [_kAllCategories, ...list];
  }

  /// Kategoriya kontrollerini ro'yxatga moslaydi (uzunlik o'zgarmas
  /// bo'lgani uchun qayta yaratiladi).
  void _syncCategoryController() {
    final cats = _categories;
    if (_categoryController?.length == cats.length) return;

    var index = cats.indexOf(_category);
    if (index < 0) {
      index = 0;
      _category = _kAllCategories;
    }

    _categoryController?.dispose();
    _categoryController = TabController(
      length: cats.length,
      initialIndex: index,
      vsync: this,
    )..addListener(() {
      final c = _categoryController!;
      if (c.indexIsChanging) return;
      final selected = cats[c.index];
      if (selected == _category) return;
      setState(() => _category = selected);
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryController?.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await context.read<InventoryProvider>().getPreparedProducts();
    if (!mounted) return;
    setState(() {
      _all = rows.map((m) => Product.fromMap(m)).toList();
      _loading = false;
      final initialId = widget.initialProduct?.id;
      final at = _all.indexWhere((p) => p.id == initialId);
      if (initialId != null && at >= 0) {
        _selected.add(initialId);
        // Tanlangan mahsulot scrollsiz ko'rinib tursin — ro'yxat boshiga
        // ko'chiriladi (tartib bir marta o'zgaradi, toggle'da sakramaydi).
        _all.insert(0, _all.removeAt(at));
      }
    });
    // Kartadagi "Pishirish" dan kelganda ham son maydoni darhol tayyor (§4).
    final preselected = widget.initialProduct?.id;
    if (preselected != null && _selected.contains(preselected)) {
      _focusQty(preselected);
    }
  }

  List<Product> get _filtered {
    final q = _query.toLowerCase();
    return _all.where((p) {
      if (_category != _kAllCategories && p.category.trim() != _category) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.category.toLowerCase().contains(q);
    }).toList();
  }

  TextEditingController _controllerFor(int productId) {
    return _controllers.putIfAbsent(
      productId,
      () => TextEditingController(text: '1'),
    );
  }

  FocusNode _focusFor(int productId) =>
      _focusNodes.putIfAbsent(productId, () => FocusNode());

  /// Son maydoniga focus beradi va matnni belgilaydi — kassir darhol
  /// sonni yozib ketishi mumkin, "1" ni o'chirish kerak emas (§4).
  void _focusQty(int productId) {
    final controller = _controllerFor(productId);
    final node = _focusFor(productId);
    // Maydon aynan shu setState natijasida quriladi — keyingi kadrda focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_selected.contains(productId)) return;
      node.requestFocus();
      controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: controller.text.length,
      );
    });
  }

  void _toggle(Product p) {
    final id = p.id;
    if (id == null) return;
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
        _controllerFor(id);
      }
    });
    if (_selected.contains(id)) _focusQty(id);
  }

  /// Tanlangan qatorlardan `(productId, count)` ro'yxatini yig'adi.
  /// Son bo'sh yoki <= 0 bo'lsa o'sha qator tashlab ketiladi.
  List<({int productId, double count})> _collect() {
    final items = <({int productId, double count})>[];
    for (final id in _selected) {
      final raw = _controllers[id]?.text.trim().replaceAll(',', '.') ?? '';
      final count = double.tryParse(raw) ?? 0;
      if (count > 0) items.add((productId: id, count: count));
    }
    return items;
  }

  Future<void> _save() async {
    final items = _collect();
    if (items.isEmpty) {
      _snack('Kamida bitta mahsulotga son kiriting', isError: true);
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<InventoryProvider>().produce(items);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      _snack('${items.length} ta mahsulot pishirildi');
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showShortages(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Xatolik: $e', isError: true);
    }
  }

  void _snack(String text, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Xomashyo yetishmasa — qaysi biri, qancha kerak, qancha bor.
  void _showShortages(InsufficientStockException e) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
          size: 40,
        ),
        title: const Text('Xomashyo yetarli emas'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quyidagi xomashyolar yetishmaydi. Pishirish bekor qilindi — '
                'omborda hech narsa o\'zgarmadi.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Column(
                    children: e.shortages.map((s) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              'kerak ${QtyFormatter.format(s.need)} · bor ${QtyFormatter.format(s.onHand)} '
                              '${s.unit}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _filtered;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(theme),
            _search(theme),
            if (!_loading) _categoryTabs(theme),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : items.isEmpty
                  ? _empty(theme)
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (_, i) => _row(theme, items[i]),
                    ),
            ),
            const Divider(height: 1),
            _footer(theme),
          ],
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 12, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pishirish',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Retsept bo\'yicha xomashyo chegiriladi',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Yopish',
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  /// Kategoriya TabBar'i (§22) — ixcham, faqat matn.
  Widget _categoryTabs(ThemeData theme) {
    _syncCategoryController();
    final cats = _categories;
    if (cats.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: TabBar(
        controller: _categoryController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        indicatorWeight: 2,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelColor: theme.colorScheme.onSurface.withValues(
          alpha: 0.5,
        ),
        tabs: [
          for (final c in cats) Tab(height: 32, text: c),
        ],
      ),
    );
  }

  Widget _search(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Mahsulot qidirish...',
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
    );
  }

  Widget _empty(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.no_food_outlined,
            size: 48,
            color: theme.hintColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            _query.isEmpty
                ? 'Tayyorlanadigan mahsulot yo\'q'
                : 'Hech narsa topilmadi',
            style: TextStyle(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _row(ThemeData theme, Product p) {
    final id = p.id;
    if (id == null) return const SizedBox.shrink();
    final isSelected = _selected.contains(id);

    return InkWell(
      onTap: _saving ? null : () => _toggle(p),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : null,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: Checkbox(
                value: isSelected,
                onChanged: _saving ? null : (_) => _toggle(p),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Omborda: ${QtyFormatter.format(p.quantity ?? 0)} ${p.unit ?? 'dona'}',
                    style: TextStyle(fontSize: 12, color: theme.hintColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: isSelected
                  ? TextField(
                      controller: _controllerFor(id),
                      focusNode: _focusFor(id),
                      enabled: !_saving,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'son',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(ThemeData theme) {
    final count = _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
      child: Row(
        children: [
          Text(
            count == 0
                ? 'Hech narsa tanlanmadi'
                : '$count ta mahsulot tanlandi',
            style: TextStyle(color: theme.hintColor, fontSize: 13),
          ),
          const Spacer(),
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Bekor qilish'),
          ),
          const SizedBox(width: 8),
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
            label: const Text('Saqlash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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

/// Kategoriya filtri o'chirilgan holat (§22) — barcha mahsulotlar.
const String _kAllCategories = 'Hammasi';
