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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          AppStrings.productMgmt,
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: () => _showProductDialog(context),
                icon: const Icon(Icons.add),
                label: const Text(AppStrings.addProduct),
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
          // Filter Bar
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Mahsulot nomi bo'yicha qidirish...",
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
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: selectedCategoryFilter,
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
                    hint: const Text("Barcha kategoriyalar"),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text("Barcha kategoriyalar"),
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
                    value: selectedStatusFilter,
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
                    hint: const Text("Barcha holatlar"),
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text("Barcha holatlar"),
                      ),
                      DropdownMenuItem(value: true, child: Text("Faol")),
                      DropdownMenuItem(value: false, child: Text("Tugagan")),
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
            "Mahsulotlar topilmadi",
            style: TextStyle(color: Colors.grey.shade500, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
                              ? 16
                              : 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          "${PriceFormatter.format(product.price)} so'm",
                          style: TextStyle(
                            fontSize: MediaQuery.of(context).size.width <= 1100
                                ? 18
                                : 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text(
                              "Holati:",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              height: 24,
                              child: Switch(
                                value: product.isActive,
                                onChanged: (val) {
                                  context.read<ProductProvider>().updateProduct(
                                    product.copyWith(isActive: val),
                                  );
                                },
                                activeColor: Colors.green,
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
        isActive ? "Faol" : "Tugagan",
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
        title: const Text("O'chirishni tasdiqlang"),
        content: Text("${product.name} ni o'chirmoqchimisiz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Bekor qilish"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("O'chirish", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ProductProvider>().deleteProduct(product.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Mahsulot o'chirildi"),
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
    String? selectedCategory = product?.category;
    String? selectedImagePath = product?.imagePath;
    final categories = context.read<CategoryProvider>().categories;

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
            content: SingleChildScrollView(
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
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: AppStrings.productCategory,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat.name,
                        child: Text(cat.name),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCategory = val),
                    validator: (val) =>
                        val == null ? AppStrings.selectCategory : null,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Mahsulot rasmi",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (selectedImagePath != null &&
                      File(selectedImagePath!).existsSync())
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedImagePath!),
                            height: 120,
                            width: 120,
                            fit: BoxFit.cover,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              selectedImagePath = null;
                            });
                          },
                          icon: const Icon(Icons.delete, color: Colors.red),
                          label: const Text(
                            "Rasmni olib tashlash",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.image);
                        if (result != null) {
                          setDialogState(() {
                            selectedImagePath = result.files.single.path;
                          });
                        }
                      },
                      icon: const Icon(Icons.image),
                      label: const Text("Rasm tanlash (ixtiyoriy)"),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  AppStrings.cancel,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedCategory == null || nameController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(AppStrings.selectCategory)),
                    );
                    return;
                  }

                  String? finalImagePath;
                  if (selectedImagePath != null) {
                    if (product?.imagePath == selectedImagePath) {
                      finalImagePath = selectedImagePath;
                    } else {
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
                      finalImagePath = newPath;
                    }
                  }

                  final newProduct = Product(
                    id: product?.id,
                    name: nameController.text,
                    price: double.tryParse(priceController.text) ?? 0.0,
                    category: selectedCategory!,
                    isActive: product?.isActive ?? true,
                    imagePath: finalImagePath,
                  );

                  if (product == null) {
                    if (context.mounted) {
                      context.read<ProductProvider>().addProduct(newProduct);
                    }
                  } else {
                    if (context.mounted) {
                      context.read<ProductProvider>().updateProduct(newProduct);
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
                child: const Text(AppStrings.save),
              ),
            ],
          );
        },
      ),
    );
  }
}
