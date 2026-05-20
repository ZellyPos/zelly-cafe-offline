import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils/price_formatter.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/product.dart';

class NewDeliveryScreen extends StatefulWidget {
  const NewDeliveryScreen({super.key});

  @override
  State<NewDeliveryScreen> createState() => _NewDeliveryScreenState();
}

class _NewDeliveryScreenState extends State<NewDeliveryScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _feeCtrl = TextEditingController(text: '0');
  final _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String? _selectedCategory;
  bool _isSaving = false;

  // Phone lookup
  List<Map<String, dynamic>> _phoneSuggestions = [];
  bool _showSuggestions = false;
  Timer? _phoneDebounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeliveryProvider>()
        ..loadCouriers()
        ..loadZones();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _noteCtrl.dispose();
    _feeCtrl.dispose();
    _searchCtrl.dispose();
    _phoneDebounce?.cancel();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    final dp = context.read<DeliveryProvider>();
    dp.customerPhone = value;
    _phoneDebounce?.cancel();
    if (value.length < 3) {
      setState(() { _phoneSuggestions = []; _showSuggestions = false; });
      return;
    }
    _phoneDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await dp.lookupByPhone(value);
      if (mounted) {
        setState(() {
          _phoneSuggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  void _applySuggestion(Map<String, dynamic> suggestion) {
    final name = suggestion['name'] as String? ?? '';
    final phone = suggestion['phone'] as String? ?? '';
    final address = suggestion['address'] as String? ?? '';
    _nameCtrl.text = name;
    _phoneCtrl.text = phone;
    if (address.isNotEmpty) _addressCtrl.text = address;
    final dp = context.read<DeliveryProvider>();
    dp.customerName = name;
    dp.customerPhone = phone;
    if (address.isNotEmpty) dp.deliveryAddress = address;
    setState(() { _showSuggestions = false; _phoneSuggestions = []; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.grey.shade700),
        title: const Text(
          'Yangi yetkazib berish',
          style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.bold,
              fontSize: 18),
        ),
      ),
      body: Row(
        children: [
          Expanded(flex: 6, child: _buildProductPanel()),
          Container(width: 400, color: Colors.white, child: _buildRightPanel()),
        ],
      ),
    );
  }

  // ── Product panel ─────────────────────────────────────────────────────────

  Widget _buildProductPanel() {
    final allProducts = List<Product>.from(context.watch<ProductProvider>().products)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final categories = allProducts
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final filtered = allProducts
        .where((p) =>
            (_selectedCategory == null || p.category == _selectedCategory) &&
            (_searchQuery.isEmpty ||
                p.name.toLowerCase().contains(_searchQuery)) &&
            p.isActive)
        .toList();

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Mahsulot qidirish...',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Color(0xFF94A3B8)),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              if (categories.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                          label: 'Barchasi',
                          selected: _selectedCategory == null,
                          onTap: () =>
                              setState(() => _selectedCategory = null)),
                      ...categories.map((c) => _CategoryChip(
                            label: c,
                            selected: _selectedCategory == c,
                            onTap: () =>
                                setState(() => _selectedCategory = c),
                          )),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Consumer<DeliveryProvider>(
            builder: (_, dp, _) => GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final product = filtered[i];
                final qty = dp.cartItems[product.id]?.quantity ?? 0;
                return _ProductCard(
                    product: product,
                    qty: qty,
                    onTap: () => dp.addItem(product));
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── Right panel ───────────────────────────────────────────────────────────

  Widget _buildRightPanel() {
    return Consumer<DeliveryProvider>(
      builder: (_, dp, _) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Mijoz ma\'lumotlari'),
                  const SizedBox(height: 8),

                  // Phone with autocomplete
                  _buildPhoneField(dp),
                  if (_showSuggestions) _buildSuggestionBox(),
                  const SizedBox(height: 10),

                  _inputField(
                    controller: _nameCtrl,
                    label: 'Ism *',
                    icon: Icons.person_rounded,
                    onChanged: (v) => dp.customerName = v,
                  ),
                  const SizedBox(height: 10),
                  _inputField(
                    controller: _addressCtrl,
                    label: 'Manzil *',
                    icon: Icons.location_on_rounded,
                    maxLines: 2,
                    onChanged: (v) => dp.deliveryAddress = v,
                  ),
                  const SizedBox(height: 10),
                  _inputField(
                    controller: _noteCtrl,
                    label: 'Izoh',
                    icon: Icons.notes_rounded,
                    onChanged: (v) => dp.deliveryNote = v,
                  ),
                  const SizedBox(height: 12),

                  // Zone selector
                  if (dp.activeZones.isNotEmpty) ...[
                    _sectionTitle('Yetkazish zonasi'),
                    const SizedBox(height: 8),
                    _buildZoneSelector(dp),
                    const SizedBox(height: 10),
                  ],

                  // Manual delivery fee (shown when no zone selected)
                  if (dp.selectedZoneId == null) ...[
                    _sectionTitle('Yetkazish narxi'),
                    const SizedBox(height: 6),
                    _inputField(
                      controller: _feeCtrl,
                      label: "Narx (so'm)",
                      icon: Icons.delivery_dining_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          dp.setDeliveryFee(double.tryParse(v) ?? 0),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Courier selector
                  if (dp.activeCouriers.isNotEmpty) ...[
                    _sectionTitle('Kuryer (ixtiyoriy)'),
                    const SizedBox(height: 8),
                    _buildCourierChips(dp),
                    const SizedBox(height: 12),
                  ],

                  // Cart items
                  if (dp.cartItems.isNotEmpty) ...[
                    _sectionTitle('Buyurtma'),
                    const SizedBox(height: 8),
                    ...dp.cartItems.values.map((item) => _CartRow(item: item)),
                  ],
                ],
              ),
            ),
          ),
          _buildBottomBar(dp),
        ],
      ),
    );
  }

  Widget _buildPhoneField(DeliveryProvider dp) {
    return TextField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      onChanged: _onPhoneChanged,
      decoration: InputDecoration(
        labelText: 'Telefon',
        prefixIcon: const Icon(Icons.phone_rounded,
            size: 18, color: Color(0xFF94A3B8)),
        suffixIcon: _showSuggestions
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () => setState(() {
                  _showSuggestions = false;
                  _phoneSuggestions = [];
                }),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildSuggestionBox() {
    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: _phoneSuggestions.map((s) {
          final name = s['name'] as String? ?? '';
          final phone = s['phone'] as String? ?? '';
          final address = s['address'] as String? ?? '';
          return InkWell(
            onTap: () => _applySuggestion(s),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded,
                      size: 16, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        if (phone.isNotEmpty)
                          Text(phone,
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11)),
                        if (address.isNotEmpty)
                          Text(address,
                              style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.north_west_rounded,
                      size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildZoneSelector(DeliveryProvider dp) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _ZoneChip(
          label: 'Zona yo\'q',
          color: const Color(0xFF64748B),
          selected: dp.selectedZoneId == null,
          onTap: () {
            dp.setSelectedZone(null);
            _feeCtrl.text = '0';
          },
        ),
        ...dp.activeZones.map((z) {
          final color = _hexToColor(z.color);
          return _ZoneChip(
            label: '${z.name}  ${z.fee > 0 ? PriceFormatter.format(z.fee) : 'bepul'}',
            color: color,
            selected: dp.selectedZoneId == z.id,
            onTap: () {
              dp.setSelectedZone(z.id);
              _feeCtrl.text = z.fee.toStringAsFixed(0);
            },
          );
        }),
      ],
    );
  }

  Widget _buildCourierChips(DeliveryProvider dp) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        ChoiceChip(
          label: const Text('Belgilanmagan'),
          selected: dp.selectedCourierId == null,
          onSelected: (_) => dp.setSelectedCourier(null),
        ),
        ...dp.activeCouriers.map(
          (c) => ChoiceChip(
            label: Text(c.name),
            selected: dp.selectedCourierId == c.id,
            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            onSelected: (_) => dp.setSelectedCourier(c.id),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(DeliveryProvider dp) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dp.deliveryFee > 0) ...[
            _totalRow('Mahsulotlar:', dp.cartTotal),
            const SizedBox(height: 4),
            _totalRow('Yetkazish:', dp.deliveryFee),
            const Divider(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jami:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E293B))),
              Text(
                PriceFormatter.format(dp.grandTotal),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving || dp.cartIsEmpty ? null : () => _submit(dp),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: const Text('Buyurtma qabul qilish',
                  style: TextStyle(fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Row _totalRow(String label, double amount) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF64748B), fontSize: 13)),
          Text(PriceFormatter.format(amount),
              style: const TextStyle(
                  color: Color(0xFF1E293B), fontSize: 13)),
        ],
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF64748B),
            letterSpacing: 0.5),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon:
            Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: AppTheme.primaryColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Future<void> _submit(DeliveryProvider dp) async {
    dp.customerName = _nameCtrl.text;
    dp.customerPhone = _phoneCtrl.text;
    dp.deliveryAddress = _addressCtrl.text;
    dp.deliveryNote = _noteCtrl.text;
    if (dp.selectedZoneId == null) {
      dp.deliveryFee = double.tryParse(_feeCtrl.text) ?? 0;
    }

    final connectivity = context.read<ConnectivityProvider>();
    final rawId = connectivity.currentUser?['id'];
    final waiterId =
        rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');

    setState(() => _isSaving = true);
    final err = await dp.createOrder(waiterId: waiterId);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Buyurtma qabul qilindi'),
          backgroundColor: Color(0xFF22C55E)));
      Navigator.of(context).pop();
    }
  }
}

// ── Zone chip ─────────────────────────────────────────────────────────────────

class _ZoneChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ZoneChip(
      {required this.label,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.transparent, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? Colors.white : const Color(0xFF64748B)),
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Product product;
  final double qty;
  final VoidCallback onTap;
  const _ProductCard(
      {required this.product, required this.qty, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasQty = qty > 0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasQty
                  ? AppTheme.primaryColor
                  : const Color(0xFFE2E8F0),
              width: hasQty ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6)
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.restaurant_menu_rounded,
                        color: AppTheme.primaryColor, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(product.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(PriceFormatter.format(product.price),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (hasQty)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                      color: AppTheme.primaryColor, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      qty.toStringAsFixed(
                          qty == qty.floorToDouble() ? 0 : 1),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Cart row ──────────────────────────────────────────────────────────────────

class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final dp = context.read<DeliveryProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(item.product.name,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          _QtyBtn(
              icon: Icons.remove_rounded,
              onTap: () =>
                  dp.updateQty(item.product.id!, item.quantity - 1)),
          SizedBox(
            width: 30,
            child: Text(
              item.quantity.toStringAsFixed(
                  item.quantity == item.quantity.floorToDouble() ? 0 : 1),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          _QtyBtn(
              icon: Icons.add_rounded,
              onTap: () => dp.addItem(item.product)),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(PriceFormatter.format(item.total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6)),
          child:
              Icon(icon, size: 14, color: const Color(0xFF475569)),
        ),
      );
}

// ── Category chip ─────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryColor
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected
                      ? Colors.white
                      : const Color(0xFF64748B))),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Color _hexToColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
