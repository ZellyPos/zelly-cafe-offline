import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../models/inventory_models.dart';

class StockManagementScreen extends StatefulWidget {
  const StockManagementScreen({super.key});

  @override
  State<StockManagementScreen> createState() => _StockManagementScreenState();
}

class _StockManagementScreenState extends State<StockManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  Ingredient? _selectedIngredient;
  final _qtyController = TextEditingController();
  final _noteController = TextEditingController();
  MovementType _selectedType = MovementType.IN;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventoryProvider>().loadIngredients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Kirim / Chiqim')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Zaxira harakatini ro\'yxatdan o\'tkazish',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Xom-ashyo qoldig\'ini ko\'paytirish, kamaytirish yoki to\'g\'rilash.',
                style: TextStyle(color: theme.hintColor),
              ),
              const SizedBox(height: 32),

              // Ingredient Selection
              const _Label('Xom-ashyoni tanlang'),
              _IngredientSelector(
                selectedIngredient: _selectedIngredient,
                onTap: () => _showIngredientSelector(context, provider),
              ),
              if (_selectedIngredient == null &&
                  _formKey.currentState?.validate() == false)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, left: 12),
                  child: Text(
                    'Iltimos tanlang',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 24),

              // Movement Type
              const _Label('Harakat turi'),
              Row(
                children: [
                  _TypeButton(
                    title: 'Kirim',
                    type: MovementType.IN,
                    selected: _selectedType == MovementType.IN,
                    color: Colors.green,
                    onTap: () =>
                        setState(() => _selectedType = MovementType.IN),
                  ),
                  const SizedBox(width: 12),
                  _TypeButton(
                    title: 'Chiqim',
                    type: MovementType.OUT,
                    selected: _selectedType == MovementType.OUT,
                    color: Colors.red,
                    onTap: () =>
                        setState(() => _selectedType = MovementType.OUT),
                  ),
                  const SizedBox(width: 12),
                  _TypeButton(
                    title: 'To\'g\'rilash',
                    type: MovementType.ADJUST,
                    selected: _selectedType == MovementType.ADJUST,
                    color: Colors.blue,
                    onTap: () =>
                        setState(() => _selectedType = MovementType.ADJUST),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Quantity
              _Label(
                _selectedType == MovementType.ADJUST
                    ? 'Haqiqiy miqdor'
                    : 'Miqdor',
              ),
              TextField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  suffixText: _selectedIngredient?.baseUnit ?? '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),

              const SizedBox(height: 24),

              // Note
              const _Label('Izoh (ixtiyoriy)'),
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Harakat sababi yoki qo\'shimcha ma\'lumot...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),

              const SizedBox(height: 40),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: provider.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Saqlash',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_qtyController.text.isEmpty) return;

    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    if (qty <= 0 && _selectedType != MovementType.ADJUST) return;

    final provider = context.read<InventoryProvider>();

    try {
      if (_selectedType == MovementType.IN) {
        await provider.purchaseStock(
          ingredientId: _selectedIngredient!.id!,
          qty: qty,
          note: _noteController.text,
        );
      } else if (_selectedType == MovementType.OUT) {
        await provider.wasteStock(
          ingredientId: _selectedIngredient!.id!,
          qty: qty,
          reason: _noteController.text,
        );
      } else if (_selectedType == MovementType.ADJUST) {
        await provider.adjustStock(
          ingredientId: _selectedIngredient!.id!,
          realQty: qty,
          note: _noteController.text,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Muvaffaqiyatli saqlandi')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Xatolik yuz berdi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showIngredientSelector(
    BuildContext context,
    InventoryProvider provider,
  ) {
    final theme = Theme.of(context);
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            width: 500,
            height: MediaQuery.of(context).size.height * 0.7,
            color: theme.scaffoldBackgroundColor,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(color: Colors.black),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Xom-ashyoni tanlang',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Qidirish...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filtered = provider.ingredients
                          .where(
                            (i) => i.name.toLowerCase().contains(
                              searchQuery.toLowerCase(),
                            ),
                          )
                          .toList();

                      if (filtered.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Topilmadi',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = _selectedIngredient?.id == item.id;

                          return _IngredientSelectionTile(
                            item: item,
                            isSelected: isSelected,
                            onTap: () {
                              setState(() => _selectedIngredient = item);
                              Navigator.pop(context);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientSelector extends StatelessWidget {
  final Ingredient? selectedIngredient;
  final VoidCallback onTap;

  const _IngredientSelector({
    required this.selectedIngredient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectedIngredient != null
                ? Colors.black.withOpacity(0.3)
                : theme.dividerColor.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.egg_outlined,
              color: selectedIngredient != null ? Colors.black : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedIngredient?.name ?? 'Tanlash uchun bosing...',
                style: TextStyle(
                  fontSize: 16,
                  color: selectedIngredient != null
                      ? Colors.black
                      : Colors.grey,
                  fontWeight: selectedIngredient != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
            const Icon(Icons.unfold_more, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _IngredientSelectionTile extends StatelessWidget {
  final Ingredient item;
  final bool isSelected;
  final VoidCallback onTap;

  const _IngredientSelectionTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Colors.black : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 16,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            item.baseUnit,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  final String title;
  final MovementType type;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TypeButton({
    required this.title,
    required this.type,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? color : color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : color.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                type == MovementType.IN
                    ? Icons.add_circle_outline
                    : type == MovementType.OUT
                    ? Icons.remove_circle_outline
                    : Icons.tune,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
