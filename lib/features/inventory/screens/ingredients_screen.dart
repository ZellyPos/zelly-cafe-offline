import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../models/inventory_models.dart';

class IngredientsScreen extends StatefulWidget {
  const IngredientsScreen({super.key});

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Xom-ashyolar'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(context),
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                'Xom-ashyo qo\'shish',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.ingredients.isEmpty
          ? _buildEmptyState(theme)
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                childAspectRatio: 1.35,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: provider.ingredients.length,
              itemBuilder: (context, index) {
                final item = provider.ingredients[index];
                return _buildIngredientCard(context, item);
              },
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: theme.hintColor.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Xom-ashyolar mavjud emas',
            style: TextStyle(color: theme.hintColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(BuildContext context, Ingredient item) {
    final provider = context.read<InventoryProvider>();
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.baseUnit,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            FutureBuilder<IngredientStock?>(
              future: provider.getStock(item.id!),
              builder: (context, snapshot) {
                final onHand = snapshot.data?.onHand ?? 0.0;
                final isLow = onHand <= item.minStock;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLow
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isLow
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        size: 16,
                        color: isLow ? Colors.red : Colors.green.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Qoldiq: $onHand ${item.baseUnit}',
                        style: TextStyle(
                          color: isLow ? Colors.red : Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButton(
                  icon: Icons.edit_outlined,
                  color: Colors.blue,
                  onTap: () => _showAddEditDialog(context, ingredient: item),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onTap: () => _showDeleteConfirm(context, item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  void _showAddEditDialog(BuildContext context, {Ingredient? ingredient}) {
    final nameController = TextEditingController(text: ingredient?.name);
    final minStockController = TextEditingController(
      text: ingredient != null ? ingredient.minStock.toString() : '0',
    );
    String baseUnit = ingredient?.baseUnit ?? 'g';
    final isEdit = ingredient != null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            isEdit ? 'Xom-ashyoni tahrirlash' : 'Yangi xom-ashyo',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ma\'lumotlarni kiriting',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nomi',
                    hintText: 'Masalan: Go\'sht',
                    prefixIcon: const Icon(Icons.label_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: baseUnit,
                        decoration: InputDecoration(
                          labelText: 'O\'lchov birligi',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: ['g', 'ml', 'pcs']
                            .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => baseUnit = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: minStockController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Minimal qoldiq',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Bekor qilish',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty) {
                  final newIngredient = Ingredient(
                    id: ingredient?.id,
                    name: nameController.text,
                    baseUnit: baseUnit,
                    minStock: double.tryParse(minStockController.text) ?? 0.0,
                  );
                  if (isEdit) {
                    context.read<InventoryProvider>().updateIngredient(
                      newIngredient,
                    );
                  } else {
                    context.read<InventoryProvider>().addIngredient(
                      newIngredient,
                    );
                  }
                  Navigator.pop(context);
                  _showSuccessSnackBar(
                    context,
                    isEdit ? 'Saqlandi' : 'Qo\'shildi',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isEdit ? 'Saqlash' : 'Qo\'shish'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Ingredient item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('O\'chirishni tasdiqlang'),
        content: Text(
          '${item.name}ni o\'chirishni istaysizmi? Ushbu amal ortga qaytarilmaydi.',
          style: const TextStyle(fontSize: 16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Bekor qilish',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<InventoryProvider>().deleteIngredient(item.id!);
              Navigator.pop(context);
              _showSuccessSnackBar(context, 'O\'chirildi', isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.black,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
