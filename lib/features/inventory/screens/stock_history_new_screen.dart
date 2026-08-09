import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../providers/inventory_provider.dart';

/// Kirim/Chiqim + Inventarizatsiya tarixi (§4.6).
///
/// `stock_movements` (xomashyo) va `product_movements` (tayyor mahsulot)
/// birlashtirilgan ro'yxat — `InventoryRepository.getHistory()` beradi.
/// Filtrlar: sana oralig'i, harakat turi, birlik turi (xomashyo/mahsulot).
class StockHistoryNewScreen extends StatefulWidget {
  /// Faqat bitta birlik tarixi ochilsa (detail ekranidan).
  final int? itemId;
  final String? source;
  final String? title;

  const StockHistoryNewScreen({
    super.key,
    this.itemId,
    this.source,
    this.title,
  });

  @override
  State<StockHistoryNewScreen> createState() => _StockHistoryNewScreenState();
}

class _StockHistoryNewScreenState extends State<StockHistoryNewScreen> {
  static final _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  /// Harakat turlari — kalit DB'dagi qiymat, qiymat ko'rsatiladigan matn.
  static const _typeLabels = <String, String>{
    'IN': 'Kirim',
    'OUT': 'Chiqim',
    'PRODUCE': 'Pishirish',
    'PURCHASE': 'Kirim (mahsulot)',
    'SALE': 'Sotuv',
    'WASTE': 'Buzilish',
    'ADJUST': 'Tuzatish',
    'RETURN': 'Qaytarish',
  };

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  DateTimeRange? _range;
  final _selectedTypes = <String>{};
  late String? _source;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await context.read<InventoryProvider>().getHistory(
        from: _range?.start,
        // Tanlangan kunning oxirigacha kirsin.
        to: _range == null
            ? null
            : DateTime(
                _range!.end.year,
                _range!.end.month,
                _range!.end.day,
                23,
                59,
                59,
              ),
        types: _selectedTypes.isEmpty ? null : _selectedTypes.toList(),
        itemId: widget.itemId,
        source: _source,
        limit: 500,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Yuklashda xatolik: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }

  void _toggleType(String type) {
    setState(() {
      if (!_selectedTypes.remove(type)) _selectedTypes.add(type);
    });
    _load();
  }

  // ─── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.title ?? 'Ombor tarixi'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
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
          _filters(theme),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 56,
                          color: theme.hintColor.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Harakatlar topilmadi',
                          style: TextStyle(color: theme.hintColor),
                        ),
                      ],
                    ),
                  )
                : _table(theme),
          ),
        ],
      ),
    );
  }

  Widget _filters(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  _range == null
                      ? 'Sana: hammasi'
                      : '${DateFormat('dd.MM.yy').format(_range!.start)} — '
                            '${DateFormat('dd.MM.yy').format(_range!.end)}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_range != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Sana filtrini tozalash',
                  onPressed: () {
                    setState(() => _range = null);
                    _load();
                  },
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
              const SizedBox(width: 20),
              // Birlik turi — faqat umumiy tarixda mantiqli
              if (widget.itemId == null) ...[
                _sourceChip('Hammasi', null),
                const SizedBox(width: 8),
                _sourceChip('Xomashyo', 'ingredient'),
                const SizedBox(width: 8),
                _sourceChip('Mahsulot', 'product'),
              ],
              const Spacer(),
              Text(
                '${_rows.length} ta yozuv',
                style: TextStyle(color: theme.hintColor, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _typeLabels.entries.map((e) {
              final selected = _selectedTypes.contains(e.key);
              return FilterChip(
                label: Text(e.value),
                selected: selected,
                onSelected: (_) => _toggleType(e.key),
                showCheckmark: false,
                avatar: Icon(
                  _typeIcon(e.key),
                  size: 16,
                  color: _typeColor(e.key),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _source == value,
      showCheckmark: false,
      onSelected: (_) {
        setState(() => _source = value);
        _load();
      },
    );
  }

  Widget _table(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: _headerRow(theme),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
            itemBuilder: (_, i) => _dataRow(theme, _rows[i]),
          ),
        ),
      ],
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
        Expanded(flex: 3, child: Text('Sana', style: style)),
        Expanded(flex: 4, child: Text('Nomi', style: style)),
        Expanded(flex: 3, child: Text('Turi', style: style)),
        Expanded(flex: 2, child: Text('Miqdor', style: style)),
        Expanded(flex: 3, child: Text('Narx', style: style)),
        Expanded(flex: 3, child: Text('Kim', style: style)),
        Expanded(flex: 4, child: Text('Izoh', style: style)),
      ],
    );
  }

  Widget _dataRow(ThemeData theme, Map<String, dynamic> row) {
    final type = row['type'] as String? ?? '';
    final qty = (row['qty'] as num?)?.toDouble() ?? 0;
    final cost = (row['cost_price'] as num?)?.toDouble() ?? 0;
    final unit = row['unit'] as String? ?? '';
    final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
    final note = _noteText(row);
    final isIncrease = _isIncrease(type, qty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              createdAt == null ? '—' : _dateFormat.format(createdAt),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Icon(
                  row['source'] == 'ingredient'
                      ? Icons.egg_outlined
                      : Icons.fastfood_outlined,
                  size: 15,
                  color: theme.hintColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row['item_name'] as String? ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(flex: 3, child: _typeBadge(type)),
          Expanded(
            flex: 2,
            child: Text(
              // ADJUST manfiy ham bo'lishi mumkin — ishorasi bilan.
              '${isIncrease ? '+' : '−'}${_fmt(qty.abs())} $unit',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isIncrease ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              cost > 0 ? PriceFormatter.formatWithCurrency(cost) : '—',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              row['user_name'] as String? ?? '—',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              note,
              style: TextStyle(fontSize: 12, color: theme.hintColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type) {
    final color = _typeColor(type);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_typeIcon(type), size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              _typeLabels[type] ?? type,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Izoh ustuni: supplier (kirimda), note yoki reason — qaysi biri bo'lsa.
  String _noteText(Map<String, dynamic> row) {
    final supplier = row['supplier'] as String?;
    final note = row['note'] as String?;
    final reason = row['reason'] as String?;
    final parts = <String>[
      if (supplier != null && supplier.isNotEmpty) 'kimdan: $supplier',
      if (note != null && note.isNotEmpty) note,
      if (reason != null && reason.isNotEmpty && reason != 'purchase') reason,
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  /// Qoldiq oshdimi yoki kamaydimi.
  static bool _isIncrease(String type, double qty) {
    switch (type) {
      case 'IN':
      case 'PURCHASE':
      case 'PRODUCE':
      case 'RETURN':
        return true;
      case 'OUT':
      case 'SALE':
      case 'WASTE':
        return false;
      case 'ADJUST':
        // Inventarizatsiya farqi ishorali yoziladi.
        return qty >= 0;
      default:
        return qty >= 0;
    }
  }

  static Color _typeColor(String type) {
    switch (type) {
      case 'IN':
      case 'PURCHASE':
        return Colors.green.shade700;
      case 'PRODUCE':
        return Colors.orange.shade800;
      case 'SALE':
        return Colors.blue.shade700;
      case 'OUT':
      case 'WASTE':
        return Colors.red.shade700;
      case 'ADJUST':
        return Colors.purple.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'IN':
      case 'PURCHASE':
        return Icons.south_west_rounded;
      case 'PRODUCE':
        return Icons.local_fire_department_rounded;
      case 'SALE':
        return Icons.shopping_cart_rounded;
      case 'OUT':
      case 'WASTE':
        return Icons.north_east_rounded;
      case 'ADJUST':
        return Icons.tune_rounded;
      case 'RETURN':
        return Icons.undo_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
