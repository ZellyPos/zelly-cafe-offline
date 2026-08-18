import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.categoryMgmt,
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: IconButton(
                onPressed: () => _showReorderDialog(context),
                icon: Icon(Icons.reorder, color: theme.colorScheme.primary),
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
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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
            color: theme.colorScheme.surface,
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              style: TextStyle(color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: AppStrings.searchCategoryHint,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.light
                    ? const Color(0xFFF1F5F9)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.05),
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
                      childAspectRatio: 1.2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final productCount = productProvider.products
                          .where((p) => p.category == category.name)
                          .length;
                      return _buildCategoryCard(context, category, productCount);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          Text(
            searchQuery.isEmpty
                ? 'Kategoriyalar mavjud emas'
                : 'Hech narsa topilmadi',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 18,
            ),
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
    final theme = Theme.of(context);

    Color cardColor = theme.colorScheme.surface;
    if (category.color != null && category.color != '#FFFFFF') {
      try {
        cardColor = Color(int.parse(category.color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    } else if (theme.brightness == Brightness.dark) {
      cardColor = theme.colorScheme.surface;
    }

    final hasImage =
        category.imagePath != null && File(category.imagePath!).existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCategoryDialog(context, category: category),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.brightness == Brightness.light
                    ? const Color(0xFFE2E8F0)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.1),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Full-bleed background image
                if (hasImage)
                  Image.file(
                    File(category.imagePath!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                // Gradient overlay for readability
                if (hasImage)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                // Content layer
                Padding(
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
                                fontSize: MediaQuery.of(context).size.width <=
                                        1100
                                    ? 15
                                    : 16,
                                fontWeight: FontWeight.bold,
                                color: hasImage
                                    ? Colors.white
                                    : (cardColor.computeLuminance() > 0.5
                                          ? theme.colorScheme.onSurface
                                          : Colors.white),
                                shadows: hasImage
                                    ? [
                                        const Shadow(
                                          blurRadius: 4,
                                          color: Colors.black54,
                                        ),
                                      ]
                                    : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              _actionIcon(
                                icon: Icons.edit_outlined,
                                color: hasImage
                                    ? Colors.white70
                                    : (cardColor.computeLuminance() > 0.5
                                          ? Colors.blue
                                          : Colors.white70),
                                onTap: () => _showCategoryDialog(
                                  context,
                                  category: category,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _actionIcon(
                                icon: Icons.delete_outline,
                                color: hasImage
                                    ? Colors.red.shade300
                                    : (cardColor.computeLuminance() > 0.5
                                          ? Colors.red
                                          : Colors.white70),
                                onTap: () => _confirmDelete(
                                  context,
                                  category,
                                  productCount,
                                ),
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
                          color: hasImage
                              ? Colors.black.withValues(alpha: 0.35)
                              : (cardColor.computeLuminance() > 0.5
                                    ? Colors.orange.shade50
                                    : Colors.white.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 14,
                              color: hasImage
                                  ? Colors.orange.shade200
                                  : (cardColor.computeLuminance() > 0.5
                                        ? Colors.orange.shade700
                                        : Colors.white),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$productCount ta mahsulot',
                              style: TextStyle(
                                color: hasImage
                                    ? Colors.orange.shade200
                                    : (cardColor.computeLuminance() > 0.5
                                          ? Colors.orange.shade700
                                          : Colors.white),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
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
      if (!context.mounted) return;
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
    String? selectedImagePath = category?.imagePath;

    final List<String> availableColors = [
      '#FFFFFF',
      '#F87171',
      '#FB923C',
      '#FACC15',
      '#4ADE80',
      '#2DD4BF',
      '#60A5FA',
      '#818CF8',
      '#A78BFA',
      '#F472B6',
      '#DC2626',
      '#EA580C',
      '#D97706',
      '#B45309',
      '#92400E',
      '#84CC16',
      '#16A34A',
      '#0EA5E9',
      '#06B6D4',
      '#E11D48',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);

          Future<void> pickImage() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              allowMultiple: false,
            );
            if (result != null && result.files.single.path != null) {
              setDialogState(
                () => selectedImagePath = result.files.single.path,
              );
            }
          }

          final hasImage = selectedImagePath != null &&
              File(selectedImagePath!).existsSync();

          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              category == null
                  ? AppStrings.addCategory
                  : AppStrings.editCategory,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name field
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        labelText: AppStrings.categoryName,
                        labelStyle: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Image picker
                    Text(
                      'Rasm',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: pickImage,
                          child: Container(
                            width: 100,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.light
                                  ? const Color(0xFFF1F5F9)
                                  : theme.colorScheme.onSurface.withValues(alpha: 
                                      0.05,
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 
                                  0.3,
                                ),
                                width: 1.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: hasImage
                                ? Image.file(
                                    File(selectedImagePath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        _noImagePlaceholder(theme),
                                  )
                                : _noImagePlaceholder(theme),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                onPressed: pickImage,
                                icon: const Icon(
                                  Icons.image_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  hasImage
                                      ? 'Rasmni almashtirish'
                                      : 'Rasm tanlash',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: theme.colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              if (hasImage) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () => setDialogState(
                                    () => selectedImagePath = null,
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    "Rasmni o'chirish",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Color picker
                    Text(
                      AppStrings.categoryColor,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
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
                              onTap: () => setDialogState(
                                () => selectedCardColor = null,
                              ),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  Icons.format_color_reset_outlined,
                                  size: 20,
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
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
                    imagePath: selectedImagePath,
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
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
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

  Widget _noImagePlaceholder(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 28,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 4),
        Text(
          "Rasm yo'q",
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  void _showReorderDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<CategoryProvider>(
          builder: (context, provider, _) {
            final theme = Theme.of(context);
            final categories = provider.categories;
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              title: Text(
                AppStrings.reorderCategories,
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
              content: SizedBox(
                width: 400,
                height: 500,
                child: ReorderableListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final hasImage = cat.imagePath != null &&
                        File(cat.imagePath!).existsSync();
                    return ListTile(
                      key: ValueKey(cat.id),
                      leading: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(cat.imagePath!),
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.drag_handle,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            )
                          : Icon(
                              Icons.drag_handle,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      title: Text(
                        cat.name,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                      ),
                      tileColor: cat.color != null
                          ? Color(
                              int.parse(cat.color!.replaceFirst('#', '0xFF')),
                            ).withValues(alpha: 0.1)
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
                  child: Text(
                    AppStrings.close,
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
