import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/category_provider.dart';
import '../../models/product.dart';
import '../../core/theme.dart';
import '../../core/app_strings.dart';
import '../../core/utils/price_formatter.dart';
import '../../providers/connectivity_provider.dart';
import '../../widgets/ai_action_button.dart';
import '../../providers/ai_provider.dart';

class ProductsMgmtScreen extends StatefulWidget {
  const ProductsMgmtScreen({super.key});

  @override
  State<ProductsMgmtScreen> createState() => _ProductsMgmtScreenState();
}

class _ProductsMgmtScreenState extends State<ProductsMgmtScreen> {
  String searchQuery = '';
  String? selectedCategoryFilter;
  bool? selectedStatusFilter; // true = Faol, false = Tugagan, null = Hammasi

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final filteredProducts = productProvider.products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(
        searchQuery.toLowerCase(),
      );
      final matchesCategory =
          selectedCategoryFilter == null ||
          p.category == selectedCategoryFilter;
      final matchesStatus =
          selectedStatusFilter == null || p.isActive == selectedStatusFilter;
      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.productMgmt,
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
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                AiActionButton(
                  onAnalyze: () {
                    final now = DateTime.now();
                    // Last 30 days for menu optimization
                    final from = now.subtract(const Duration(days: 30));
                    context.read<AiProvider>().getMenuOptimization(from, now);
                  },
                  label: AppStrings.aiMenu,
                  dialogTitle: AppStrings.menuOptimization,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: selectedCategoryFilter == null
                      ? null
                      : () => _showReorderDialog(
                          context,
                          selectedCategoryFilter!,
                        ),
                  icon: const Icon(Icons.reorder),
                  label: Text(AppStrings.reorder),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
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
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _showProductDialog(context),
                  icon: const Icon(Icons.add),
                  label: Text(AppStrings.addProduct),
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
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: theme.colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: AppStrings.searchProductHint,
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white12
                          : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: selectedCategoryFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    hint: Text(AppStrings.allCategories),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(AppStrings.allCategories),
                      ),
                      ...categoryProvider.categories.map(
                        (c) => DropdownMenuItem(
                          value: c.name,
                          child: Text(c.name),
                        ),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedCategoryFilter = val),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<bool?>(
                    initialValue: selectedStatusFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                    hint: Text(AppStrings.allStatuses),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(AppStrings.allStatuses),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: Text(AppStrings.active),
                      ),
                      DropdownMenuItem(
                        value: false,
                        child: Text(AppStrings.outOfStock),
                      ),
                    ],
                    onChanged: (val) =>
                        setState(() => selectedStatusFilter = val),
                  ),
                ),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredProducts.isEmpty
                ? _buildEmptyState()
                : GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent:
                          MediaQuery.of(context).size.width <= 1100 ? 280 : 350,
                      childAspectRatio:
                          MediaQuery.of(context).size.width <= 1100 ? 1.4 : 1.6,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                    ),
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return _buildProductCard(context, product);
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
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.noProductsFound,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showProductDialog(context, product: product),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width <= 1100
                              ? 14
                              : 16,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (product.quantity != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${product.quantity!.toStringAsFixed(product.unit == 'kg' ? 2 : 0)} ${_getUnitLabel(product.unit)}",
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(product.isActive),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    product.category,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${PriceFormatter.format(product.price)} ${AppStrings.currencyLabel}",
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width <= 1100
                                ? 16
                                : 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              "${AppStrings.statusLabel}:",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Transform.scale(
                              scale: 0.8,
                              child: SizedBox(
                                height: 24,
                                child: Switch(
                                  value: product.isActive,
                                  onChanged: (val) {
                                    context
                                        .read<ProductProvider>()
                                        .updateProduct(
                                          product.copyWith(isActive: val),
                                          connectivity: context
                                              .read<ConnectivityProvider>(),
                                        );
                                  },
                                  activeThumbColor: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                            size: 24,
                          ),
                          onPressed: () =>
                              _showProductDialog(context, product: product),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 24,
                          ),
                          onPressed: () => _confirmDelete(context, product),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
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

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? AppStrings.active : AppStrings.outOfStock,
        style: TextStyle(
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.confirmDeleteTitle),
        content: Text("${product.name} ${AppStrings.confirmDeleteExpense}"),
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

    if (confirmed == true && context.mounted) {
      context.read<ProductProvider>().deleteProduct(
        product.id!,
        connectivity: context.read<ConnectivityProvider>(),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.productDeletedSuccess),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showProductDialog(BuildContext context, {Product? product}) {
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product?.price.toString() ?? '',
    );
    final quantityController = TextEditingController(
      text: product?.quantity?.toString() ?? '',
    );
    String? selectedCategory = product?.category;
    String? selectedImagePath = product?.imagePath;
    final categories = context.read<CategoryProvider>().categories;
    bool isSet = product?.isSet ?? false;
    List<BundleItem>? bundleItems = product?.bundleItems != null
        ? List.from(product!.bundleItems!)
        : null;
    bool noServiceCharge = product?.noServiceCharge ?? false;
    String? selectedUnit = product?.unit ?? 'portion';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              product == null ? AppStrings.addProduct : AppStrings.editProduct,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Image Selection
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppStrings.productImage,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (selectedImagePath != null)
                            Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Builder(
                                    builder: (context) {
                                      final connectivity = context
                                          .read<ConnectivityProvider>();
                                      final imageUrl = connectivity.getImageUrl(
                                        selectedImagePath,
                                      );
                                      if (imageUrl != null &&
                                          imageUrl.startsWith('http')) {
                                        return Image.network(
                                          imageUrl,
                                          height: 180,
                                          width: 180,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.error),
                                        );
                                      }
                                      if (selectedImagePath != null &&
                                          File(
                                            selectedImagePath!,
                                          ).existsSync()) {
                                        return Image.file(
                                          File(selectedImagePath!),
                                          height: 180,
                                          width: 180,
                                          fit: BoxFit.cover,
                                        );
                                      }
                                      return const Icon(
                                        Icons.image_not_supported,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedImagePath = null;
                                    });
                                  },
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  label: Text(
                                    AppStrings.deleteImage,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            )
                          else
                            InkWell(
                              onTap: () async {
                                FilePickerResult? result = await FilePicker
                                    .platform
                                    .pickFiles(type: FileType.image);
                                if (result != null) {
                                  setDialogState(() {
                                    selectedImagePath =
                                        result.files.single.path;
                                  });
                                }
                              },
                              child: Container(
                                height: 180,
                                width: 180,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      AppStrings.selectImage,
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 32, indent: 10, endIndent: 10),
                    // Right Column: Input Fields
                    Expanded(
                      flex: 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: InputDecoration(
                              labelText: AppStrings.productName,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: priceController,
                            decoration: InputDecoration(
                              labelText: AppStrings.productPrice,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              suffixText: AppStrings.currencyLabel,
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedCategory,
                            decoration: InputDecoration(
                              labelText: AppStrings.productCategory,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat.name,
                                child: Text(cat.name),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedCategory = val),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: selectedUnit,
                            decoration: InputDecoration(
                              labelText: AppStrings.productUnit,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'portion',
                                child: Text(AppStrings.unitPortion),
                              ),
                              DropdownMenuItem(
                                value: 'dona',
                                child: Text(AppStrings.unitDona),
                              ),
                              DropdownMenuItem(
                                value: 'kg',
                                child: Text(AppStrings.unitKg),
                              ),
                              DropdownMenuItem(
                                value: 'set',
                                child: Text(AppStrings.unitSet),
                              ),
                            ],
                            onChanged: (val) =>
                                setDialogState(() => selectedUnit = val),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: quantityController,
                            decoration: InputDecoration(
                              labelText: AppStrings.productQuantity,
                              hintText: "Masalan: 50",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          // SET Taom Toggle
                          SwitchListTile(
                            title: Text(
                              AppStrings.setProduct,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(AppStrings.setProductDescription),
                            value: isSet,
                            onChanged: (val) {
                              setDialogState(() {
                                isSet = val;
                                if (isSet) bundleItems ??= [];
                              });
                            },
                          ),
                          SwitchListTile(
                            title: Text(
                              AppStrings.noServiceCharge,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            value: noServiceCharge,
                            onChanged: (val) {
                              setDialogState(() {
                                noServiceCharge = val;
                              });
                            },
                          ),
                          if (isSet) ...[
                            const Divider(height: 32),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AppStrings.bundleItems,
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  onPressed: () => _showBundleItemSelector(
                                    context,
                                    setDialogState,
                                    bundleItems!,
                                  ),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.blue,
                                  ),
                                  tooltip: AppStrings.addProduct,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (bundleItems!.isEmpty)
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    AppStrings.noItemsAdded,
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ...bundleItems!.map((item) {
                                final pName = context
                                    .read<ProductProvider>()
                                    .products
                                    .firstWhere(
                                      (p) => p.id == item.productId,
                                      orElse: () => Product(
                                        name: 'Noma\'lum',
                                        price: 0,
                                        category: '',
                                      ),
                                    )
                                    .name;
                                return ListTile(
                                  title: Text(pName),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            suffixText: "x",
                                          ),
                                          keyboardType: TextInputType.number,
                                          controller:
                                              TextEditingController(
                                                  text: item.quantity
                                                      .toString(),
                                                )
                                                ..selection =
                                                    TextSelection.collapsed(
                                                      offset: item.quantity
                                                          .toString()
                                                          .length,
                                                    ),
                                          onChanged: (val) {
                                            final qty =
                                                double.tryParse(val) ?? 1.0;
                                            setDialogState(() {
                                              final idx = bundleItems!.indexOf(
                                                item,
                                              );
                                              bundleItems![idx] = item.copyWith(
                                                quantity: qty,
                                              );
                                            });
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          setDialogState(() {
                                            bundleItems!.remove(item);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              }),
                          ],
                        ],
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
                onPressed: () async {
                  if (selectedCategory == null || nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppStrings.selectCategory)),
                    );
                    return;
                  }

                  String? finalImagePath;
                  final connectivity = context.read<ConnectivityProvider>();

                  if (selectedImagePath != null) {
                    if (product?.imagePath == selectedImagePath) {
                      finalImagePath = selectedImagePath;
                      // Ensure it's just a filename if it's already in our images dir
                      if (finalImagePath != null &&
                          (finalImagePath.contains('product_images') ||
                              (!finalImagePath.contains('/') &&
                                  !finalImagePath.contains('\\')))) {
                        finalImagePath = p.basename(finalImagePath);
                      }
                    } else if (connectivity.mode == ConnectivityMode.client) {
                      // Upload to server
                      final fileName = await connectivity.uploadImage(
                        File(selectedImagePath!),
                      );
                      finalImagePath = fileName;
                    } else {
                      // Local save
                      final appDocDir = await getApplicationSupportDirectory();
                      final imagesDir = Directory(
                        p.join(appDocDir.path, 'product_images'),
                      );
                      if (!await imagesDir.exists()) {
                        await imagesDir.create(recursive: true);
                      }
                      final fileName =
                          "${DateTime.now().millisecondsSinceEpoch}${p.extension(selectedImagePath!)}";
                      final newPath = p.join(imagesDir.path, fileName);
                      await File(selectedImagePath!).copy(newPath);
                      finalImagePath = fileName; // Save ONLY the filename
                    }
                  }

                  final newProduct = Product(
                    id: product?.id,
                    name: nameController.text,
                    price: double.tryParse(priceController.text) ?? 0.0,
                    category: selectedCategory!,
                    isActive: product?.isActive ?? true,
                    imagePath: finalImagePath,
                    bundleItems: isSet ? bundleItems : null,
                    sortOrder: product?.sortOrder ?? 0,
                    quantity: double.tryParse(quantityController.text),
                    trackType: product?.trackType ?? 0,
                    allowNegativeStock: product?.allowNegativeStock ?? false,
                    noServiceCharge: noServiceCharge,
                    unit: selectedUnit,
                  );

                  if (product == null) {
                    if (context.mounted) {
                      context.read<ProductProvider>().addProduct(
                        newProduct,
                        connectivity: context.read<ConnectivityProvider>(),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      context.read<ProductProvider>().updateProduct(
                        newProduct,
                        connectivity: context.read<ConnectivityProvider>(),
                      );
                    }
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
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

  void _showBundleItemSelector(
    BuildContext context,
    StateSetter setDialogState,
    List<BundleItem> currentItems,
  ) {
    final products = context
        .read<ProductProvider>()
        .products
        .where((p) => !p.isSet && p.isActive)
        .toList(); // No nested sets
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInternalState) {
          final filtered = products
              .where(
                (p) => p.name.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .toList();

          return AlertDialog(
            title: Text(AppStrings.selectProduct),
            content: SizedBox(
              width: 400,
              height: 500,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (val) =>
                        setInternalState(() => searchQuery = val),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isAlreadyAdded = currentItems.any(
                          (it) => it.productId == p.id,
                        );

                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text(PriceFormatter.format(p.price)),
                          trailing: isAlreadyAdded
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : const Icon(Icons.add_circle_outline),
                          onTap: isAlreadyAdded
                              ? null
                              : () {
                                  setDialogState(() {
                                    currentItems.add(
                                      BundleItem(
                                        bundleId: 0, // Will be set on save
                                        productId: p.id!,
                                        quantity: 1.0,
                                        productName: p.name,
                                      ),
                                    );
                                  });
                                  Navigator.pop(context);
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReorderDialog(BuildContext context, String category) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final productProvider = context.watch<ProductProvider>();
            final categoryProducts = productProvider.products
                .where((p) => p.category == category)
                .toList();

            return AlertDialog(
              title: Text("$category - ${AppStrings.reorder}"),
              content: SizedBox(
                width: 400,
                height: 500,
                child: ReorderableListView.builder(
                  itemCount: categoryProducts.length,
                  itemBuilder: (context, index) {
                    final product = categoryProducts[index];
                    return ListTile(
                      key: ValueKey(product.id),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(product.name),
                      subtitle: Text(PriceFormatter.format(product.price)),
                    );
                  },
                  onReorder: (oldIndex, newIndex) {
                    context.read<ProductProvider>().reorderProducts(
                      oldIndex,
                      newIndex,
                      category,
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

  String _getUnitLabel(String? unit) {
    return AppStrings.getUnitLabel(unit);
  }
}
