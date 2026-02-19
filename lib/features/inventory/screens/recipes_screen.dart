import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../models/inventory_models.dart';
import '../../../models/product.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<InventoryProvider>().loadIngredients();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final theme = Theme.of(context);

    // Filter only tracked products if needed, but for now show all
    final products = productProvider.products;

    return Scaffold(
      appBar: AppBar(title: const Text('Retseptlar')),
      body: products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(24),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                childAspectRatio: 1.1,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return InkWell(
                  onTap: () => _openRecipeEditor(context, product),
                  borderRadius: BorderRadius.circular(16),
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: theme.dividerColor.withOpacity(0.1),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.black.withOpacity(0.05),
                            child: const Icon(
                              Icons.restaurant_menu,
                              color: Colors.black,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            product.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: product.trackType == 2
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              product.trackType == 2
                                  ? 'Retseptli'
                                  : (product.trackType == 1
                                        ? 'Retail'
                                        : 'Nazoratsiz'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: product.trackType == 2
                                    ? Colors.green.shade700
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openRecipeEditor(BuildContext context, Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RecipeEditorScreen(product: product)),
    );
  }
}

class RecipeEditorScreen extends StatefulWidget {
  final Product product;
  const RecipeEditorScreen({super.key, required this.product});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  Recipe? _recipe;
  bool _loading = true;
  final List<RecipeItem> _items = [];
  final _yieldController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<InventoryProvider>();
    final recipe = await provider.getRecipe(widget.product.id!);
    if (mounted) {
      setState(() {
        _recipe = recipe;
        if (recipe != null) {
          _items.addAll(recipe.items);
          _yieldController.text = recipe.yieldQty.toString();
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryProvider = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${widget.product.name} retsepti'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _saveRecipe,
              icon: const Icon(Icons.save_outlined, color: Colors.green),
              label: const Text(
                'Saqlash',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(theme),
                Expanded(
                  child: _items.isEmpty
                      ? _buildEmptyState(theme)
                      : GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 300,
                                childAspectRatio: 1.6,
                                crossAxisSpacing: 20,
                                mainAxisSpacing: 20,
                              ),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final ingredient = inventoryProvider.ingredients
                                .firstWhere(
                                  (i) => i.id == item.ingredientId,
                                  orElse: () =>
                                      Ingredient(name: '', baseUnit: ''),
                                );
                            return _buildRecipeItemCard(
                              theme,
                              item,
                              ingredient,
                              index,
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddIngredientDialog,
        icon: const Icon(Icons.add),
        label: const Text('Ingredient qo\'shish'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Retsept miqdori (Porsiya)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Ingredientlar qancha mahsulot uchun?',
                  style: TextStyle(fontSize: 11, color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 110,
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _yieldController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: InputBorder.none,
                hintText: '1.0',
                suffixText: 'dona',
                suffixStyle: TextStyle(
                  fontSize: 12,
                  color: theme.hintColor,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeItemCard(
    ThemeData theme,
    RecipeItem item,
    Ingredient ingredient,
    int index,
  ) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: const Icon(
                    Icons.egg_outlined,
                    color: Colors.blue,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.ingredientName ?? ingredient.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              'Sarf: ${item.qty} ${ingredient.baseUnit}',
              style: TextStyle(
                color: theme.hintColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => setState(() => _items.removeAt(index)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: theme.dividerColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Hali ingredientlar qo\'shilmagan',
            style: TextStyle(
              fontSize: 18,
              color: theme.hintColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text('Retsept tuzish uchun pastdagi tugmani bosing'),
        ],
      ),
    );
  }

  void _showAddIngredientDialog() {
    final ingredients = context.read<InventoryProvider>().ingredients;
    Ingredient? selected;
    final qtyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingredient qo\'shish',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Xom-ashyoni tanlang',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Ingredient>(
                  isExpanded: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.egg_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  hint: const Text('Tanlang...'),
                  items: ingredients
                      .map(
                        (i) => DropdownMenuItem(value: i, child: Text(i.name)),
                      )
                      .toList(),
                  onChanged: (v) => setModalState(() => selected = v),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sarflanish miqdori',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.scale_outlined),
                    hintText: '0.00',
                    suffixText: selected?.baseUnit ?? '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Bekor qilish'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (selected != null && qtyController.text.isNotEmpty) {
                          setState(() {
                            _items.add(
                              RecipeItem(
                                recipeId: _recipe?.id ?? 0,
                                ingredientId: selected!.id!,
                                qty: double.tryParse(qtyController.text) ?? 0,
                                ingredientName: selected!.name,
                              ),
                            );
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Qo\'shish'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveRecipe() async {
    final provider = context.read<InventoryProvider>();
    final recipe = Recipe(
      id: _recipe?.id,
      productId: widget.product.id!,
      yieldQty: double.tryParse(_yieldController.text) ?? 1.0,
      items: _items,
    );

    await provider.saveRecipe(recipe);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Retsept saqlandi')));
      Navigator.pop(context);
    }
  }
}
