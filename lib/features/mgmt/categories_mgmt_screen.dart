import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/category.dart';
import '../../core/app_strings.dart';
import '../../core/theme.dart';
import '../../providers/connectivity_provider.dart';

class CategoriesMgmtScreen extends StatefulWidget {
  const CategoriesMgmtScreen({super.key});

  @override
  State<CategoriesMgmtScreen> createState() => _CategoriesMgmtScreenState();
}

class _CategoriesMgmtScreenState extends State<CategoriesMgmtScreen> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final productProvider = context.watch<ProductProvider>();

    final filteredCategories = categoryProvider.categories
        .where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          AppStrings.categoryMgmt,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: IconButton(
                onPressed: () => _showReorderDialog(context),
                icon: const Icon(Icons.reorder, color: AppTheme.primaryColor),
                tooltip: AppStrings.changeOrder,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(context),
                icon: const Icon(Icons.add),
                label: Text(AppStrings.addCategory),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: AppStrings.searchCategoryHint,
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          // Grid
          Expanded(
            child: categoryProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredCategories.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent:
                          MediaQuery.of(context).size.width <= 1100 ? 200 : 240,
                      childAspectRatio: 1.6,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final productCount = productProvider.products
                          .where((p) => p.category == category.name)
                          .length;
                      return _buildCategoryCard(
                        context,
                        category,
                        productCount,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty
                ? "Kategoriyalar mavjud emas"
                : "Hech narsa topilmadi",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context,
    Category category,
    int productCount,
  ) {
    Color cardColor = Colors.white;
    if (category.color != null) {
      try {
        cardColor = Color(int.parse(category.color!.replaceFirst('#', '0xFF')));
      } catch (e) {
        cardColor = Colors.white;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showCategoryDialog(context, category: category),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width <= 1100
                              ? 15
                              : 16,
                          fontWeight: FontWeight.bold,
                          color: cardColor.computeLuminance() > 0.5
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.edit_outlined,
                            color: cardColor.computeLuminance() > 0.5
                                ? Colors.blue
                                : Colors.white70,
                            size: 20,
                          ),
                          onPressed: () =>
                              _showCategoryDialog(context, category: category),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: cardColor.computeLuminance() > 0.5
                                ? Colors.red
                                : Colors.white70,
                            size: 20,
                          ),
                          onPressed: () =>
                              _confirmDelete(context, category, productCount),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cardColor.computeLuminance() > 0.5
                        ? Colors.orange.shade50
                        : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: cardColor.computeLuminance() > 0.5
                            ? Colors.orange.shade700
                            : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "$productCount ta mahsulot",
                        style: TextStyle(
                          color: cardColor.computeLuminance() > 0.5
                              ? Colors.orange.shade700
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    Category category,
    int productCount,
  ) async {
    if (productCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.categoryHasProducts),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.confirmDeleteTitle),
        content: Text(AppStrings.confirmDeleteCategory),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              AppStrings.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final categoryProvider = context.read<CategoryProvider>();
      await categoryProvider.deleteCategory(
        category.id!,
        connectivity: context.read<ConnectivityProvider>(),
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.categoryDeletedSuccess),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCategoryDialog(BuildContext context, {Category? category}) {
    final nameController = TextEditingController(text: category?.name ?? '');
    String? selectedCardColor = category?.color;

    final List<String> availableColors = [
      '#FFFFFF', // White
      '#F87171', // Red
      '#FB923C', // Orange
      '#FACC15', // Yellow
      '#4ADE80', // Green
      '#2DD4BF', // Teal
      '#60A5FA', // Blue
      '#818CF8', // Indigo
      '#A78BFA', // Violet
      '#F472B6', // Pink
      '#DC2626', // Deep Red (Steak / Go'sht)
      '#EA580C', // Burnt Orange (Grill)
      '#D97706', // Amber (Fast food)
      '#B45309', // Brown (Coffee / Shashlik)
      '#92400E', // Dark Brown (Desert)
      '#84CC16', // Lime (Salat)
      '#16A34A', // Fresh Green (Vegan)
      '#0EA5E9', // Fresh Blue (Ichimlik)
      '#06B6D4', // Aqua (Suv / Fresh)
      '#E11D48', // Raspberry (Desert)
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              category == null
                  ? AppStrings.addCategory
                  : AppStrings.editCategory,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppStrings.categoryName,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.categoryColor,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: availableColors.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = selectedCardColor == null;
                          return InkWell(
                            onTap: () =>
                                setDialogState(() => selectedCardColor = null),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Icon(
                                Icons.format_color_reset_outlined,
                                size: 20,
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : Colors.grey,
                              ),
                            ),
                          );
                        }

                        final colorHex = availableColors[index - 1];
                        final color = Color(
                          int.parse(colorHex.replaceFirst('#', '0xFF')),
                        );
                        final isSelected = selectedCardColor == colorHex;

                        return InkWell(
                          onTap: () => setDialogState(
                            () => selectedCardColor = colorHex,
                          ),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black87
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black87
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  AppStrings.cancel,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty) return;
                  final newCategory = Category(
                    id: category?.id,
                    name: nameController.text,
                    color: selectedCardColor,
                  );
                  if (category == null) {
                    context.read<CategoryProvider>().addCategory(
                      newCategory,
                      connectivity: context.read<ConnectivityProvider>(),
                    );
                  } else {
                    context.read<CategoryProvider>().updateCategory(
                      newCategory,
                      connectivity: context.read<ConnectivityProvider>(),
                    );
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(AppStrings.save),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReorderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<CategoryProvider>(
          builder: (context, provider, _) {
            final categories = provider.categories;
            return AlertDialog(
              title: Text(AppStrings.reorderCategories),
              content: SizedBox(
                width: 400,
                height: 500,
                child: ReorderableListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return ListTile(
                      key: ValueKey(cat.id),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(cat.name),
                      tileColor: cat.color != null
                          ? Color(
                              int.parse(cat.color!.replaceFirst('#', '0xFF')),
                            ).withOpacity(0.1)
                          : null,
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderCategories(
                      oldIndex,
                      newIndex,
                      connectivity: context.read<ConnectivityProvider>(),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppStrings.close),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
