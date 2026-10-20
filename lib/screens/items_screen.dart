import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/helpers.dart';
import '../utils/app_localizations.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/app_image.dart';
import '../widgets/empty_state_widget.dart';
import '../utils/image_data.dart';
import 'stock_movement_screen.dart';

/// Items/Products Screen - Kelola data barang/produk
class ItemsScreen extends StatefulWidget {
  final bool readOnly;
  const ItemsScreen({super.key, this.readOnly = false});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Product> _filteredProducts = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    // Saat kosong -> tampilkan semua produk lagi
    if (query.trim().isEmpty) {
      setState(() {
        _filteredProducts = [];
      });
      return;
    }

    final results = await context.read<ProductProvider>().searchProducts(query);

    if (mounted) {
      setState(() {
        _filteredProducts = results;
      });
    }
  }

  void _showAddProductDialog({Product? editProduct}) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productProvider = context.read<ProductProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final nameController = TextEditingController(text: editProduct?.name ?? '');
    final descController =
        TextEditingController(text: editProduct?.description ?? '');
    final priceController = TextEditingController(
        text: editProduct?.price.toStringAsFixed(0) ?? '');
    final minimumStockController = TextEditingController(
        text: (editProduct?.minimumStock ?? 0).toString());
    String photoPath = editProduct?.photoPath ?? '';
    String photoBase64 = editProduct?.photoBase64 ?? '';
    Uint8List? photoBytes;
    final stockController =
        TextEditingController(text: (editProduct?.stock ?? 0).toString());
    var isSaving = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
                loc.get(editProduct != null ? 'edit_product' : 'add_product'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Photo picker
                    GestureDetector(
                      onTap: () async {
                        try {
                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 70,
                          );
                          if (picked == null || !context.mounted) return;
                          final bytes = ImageData.compressForFirestore(
                            await picked.readAsBytes(),
                          );
                          if (!context.mounted) return;
                          setDialogState(() {
                            photoBytes = bytes;
                            photoBase64 = base64Encode(bytes);
                          });
                        } catch (error) {
                          if (!context.mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content:
                                  Text('Foto produk gagal dipilih: $error'),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF16162A)
                              : const Color(0xFFF0F0F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2A2A4A)
                                  : const Color(0xFFE0E0F0)),
                        ),
                        child: photoBytes != null ||
                                photoBase64.isNotEmpty ||
                                photoPath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: photoBytes != null
                                    ? Image.memory(photoBytes!,
                                        fit: BoxFit.cover)
                                    : AppImage(
                                        path: photoPath,
                                        base64Data: photoBase64,
                                        fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined,
                                      size: 30,
                                      color: isDark
                                          ? const Color(0xFF6666AA)
                                          : const Color(0xFF9999AA)),
                                  const SizedBox(height: 4),
                                  Text(loc.get('product_photo'),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? const Color(0xFF6666AA)
                                              : const Color(0xFF9999AA))),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                          labelText: loc.get('product_name'),
                          prefixIcon: const Icon(Icons.inventory_2_outlined)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descController,
                      decoration: InputDecoration(
                          labelText: loc.get('notes'),
                          prefixIcon: const Icon(Icons.notes)),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: loc.get('price'),
                          prefixIcon: const Icon(Icons.attach_money)),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: stockController,
                      readOnly: editProduct != null,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText:
                            editProduct == null ? 'Stok awal' : 'Stok tersedia',
                        prefixIcon: const Icon(Icons.inventory_outlined),
                        helperText: editProduct == null
                            ? 'Stok dapat ditambah lagi dari daftar barang.'
                            : 'Gunakan tombol tambah stok pada daftar barang.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: minimumStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas minimum stok',
                        prefixIcon: Icon(Icons.warning_amber_rounded),
                        helperText:
                            'Peringatan muncul saat stok mencapai batas. Nilai 0 menonaktifkan peringatan.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: Text(loc.get('cancel'))),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        final price = double.tryParse(
                            priceController.text.trim().replaceAll(',', '.'));
                        final minimumStock =
                            int.tryParse(minimumStockController.text.trim());
                        if (name.isEmpty ||
                            price == null ||
                            price < 0 ||
                            minimumStock == null ||
                            minimumStock < 0) {
                          messenger.showSnackBar(
                            SnackBar(
                                content: Text(name.isEmpty
                                    ? 'Nama produk wajib diisi.'
                                    : price == null || price < 0
                                        ? 'Masukkan harga yang valid.'
                                        : 'Batas minimum stok harus berupa angka 0 atau lebih.')),
                          );
                          return;
                        }
                        setDialogState(() => isSaving = true);
                        final product = Product(
                          id: editProduct?.id,
                          name: name,
                          description: descController.text.trim(),
                          price: price,
                          photoPath: editProduct == null ? '' : photoPath,
                          photoBase64: photoBase64,
                          photoBytes: photoBytes,
                          stock: editProduct?.stock ??
                              int.tryParse(stockController.text.trim()) ??
                              0,
                          openingStock: editProduct?.openingStock ??
                              int.tryParse(stockController.text.trim()) ??
                              0,
                          minimumStock: minimumStock,
                        );
                        try {
                          final saved = editProduct != null
                              ? await productProvider.updateProduct(product)
                              : await productProvider.addProduct(product) !=
                                  null;
                          if (!saved) {
                            if (ctx.mounted) {
                              setDialogState(() => isSaving = false);
                              messenger.showSnackBar(
                                const SnackBar(
                                    content: Text('Produk gagal disimpan.')),
                              );
                            }
                            return;
                          }
                          if (productProvider.lastPhotoStoredInFirestore) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Produk dan foto berhasil disimpan. Foto menggunakan penyimpanan Firestore.',
                                ),
                              ),
                            );
                          } else if (productProvider.lastPhotoUploadFailed) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Produk tersimpan, tetapi foto gagal diunggah. ${productProvider.lastPhotoUploadError ?? ''}',
                                ),
                              ),
                            );
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (error) {
                          if (ctx.mounted) {
                            setDialogState(() => isSaving = false);
                            messenger.showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Gagal menyimpan produk: $error')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(loc.get('save')),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
      priceController.dispose();
      stockController.dispose();
      minimumStockController.dispose();
    });
  }

  Future<void> _showStockEntryDialog(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final quantityController = TextEditingController();
    final noteController = TextEditingController();
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Tambah stok · ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok saat ini: ${product.stock}'),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Jumlah masuk'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration:
                    const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final quantity =
                          int.tryParse(quantityController.text.trim());
                      if (quantity == null || quantity <= 0) {
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Jumlah harus lebih dari 0.')),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final saved = await this
                          .context
                          .read<ProductProvider>()
                          .addStock(product.id!, quantity,
                              note: noteController.text.trim());
                      if (!dialogContext.mounted) return;
                      if (saved) {
                        Navigator.pop(dialogContext);
                      } else {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Stok gagal diperbarui. Coba lagi.')),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    quantityController.dispose();
    noteController.dispose();
  }

  Future<void> _showStockOpnameDialog(Product product) async {
    final messenger = ScaffoldMessenger.of(context);
    final actualStockController =
        TextEditingController(text: product.stock.toString());
    final noteController = TextEditingController();
    var saving = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Stok opname · ${product.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok tercatat saat ini: ${product.stock}'),
              const SizedBox(height: 12),
              TextField(
                controller: actualStockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jumlah stok fisik',
                  helperText: 'Masukkan hasil hitung barang di toko.',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Alasan/catatan (opsional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final actualStock =
                          int.tryParse(actualStockController.text.trim());
                      if (actualStock == null || actualStock < 0) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content:
                                Text('Stok fisik harus angka 0 atau lebih.'),
                          ),
                        );
                        return;
                      }
                      if (actualStock == product.stock) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content:
                                Text('Stok sudah sesuai, tidak ada perubahan.'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      final saved = await this
                          .context
                          .read<ProductProvider>()
                          .adjustStock(
                            product.id!,
                            actualStock,
                            note: noteController.text.trim(),
                          );
                      if (!dialogContext.mounted) return;
                      if (saved) {
                        Navigator.pop(dialogContext);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Stok fisik dan riwayat berhasil diperbarui.'),
                          ),
                        );
                      } else {
                        setDialogState(() => saving = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content:
                                Text('Stok opname gagal disimpan. Coba lagi.'),
                          ),
                        );
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    actualStockController.dispose();
    noteController.dispose();
  }

  Future<void> _openStockMovements({Product? product}) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StockMovementScreen(
          productId: product?.id,
          productName: product?.name,
        ),
      ),
    );
  }

  void _deleteProduct(Product product) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('delete_product')),
        content: Text(loc.get('delete_product_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<ProductProvider>().deleteProduct(product.id!);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(loc.get('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      loc.get('items_products'),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -0.5),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Riwayat pergerakan stok',
                    icon: const Icon(Icons.history_rounded),
                    onPressed: () => _openStockMovements(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1A2E)
                          : const Color(0xFFF0F0F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                          _isSearching ? Icons.close : Icons.search_rounded,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                          size: 22),
                      onPressed: () {
                        if (_isSearching) {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                            _filteredProducts = [];
                          });
                        } else {
                          setState(() => _isSearching = true);
                          setState(() => _isSearching = true);

                          Future.delayed(const Duration(milliseconds: 100), () {
                            _searchFocusNode.requestFocus();
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isSearching)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onClose: () {
                    _searchController.clear();

                    _searchFocusNode.unfocus();

                    setState(() {
                      _isSearching = false;
                      _filteredProducts = [];
                    });
                  },
                  hintText: loc.get('search_products'),
                ),
              ),
            Expanded(
              child: Consumer<ProductProvider>(
                builder: (context, provider, _) {
                  final products = _searchController.text.trim().isEmpty
                      ? provider.products
                      : _filteredProducts;
                  final lowStockCount = products
                      .where((product) =>
                          product.minimumStock > 0 &&
                          product.stock <= product.minimumStock)
                      .length;

                  if (products.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.inventory_2_outlined,
                      title: loc.get('no_products'),
                      subtitle: widget.readOnly
                          ? 'Belum ada data barang.'
                          : loc.get('create_first_product'),
                      actionIcon: widget.readOnly ? null : Icons.add,
                      actionLabel:
                          widget.readOnly ? null : loc.get('add_product'),
                      onAction: widget.readOnly
                          ? null
                          : () => _showAddProductDialog(),
                    );
                  }

                  final showLowStockNotice = lowStockCount > 0 &&
                      _searchController.text.trim().isEmpty;
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: products.length + (showLowStockNotice ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (showLowStockNotice && index == 0) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: Colors.deepOrange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$lowStockCount produk mencapai batas minimum stok.',
                                  style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final productIndex = index - (showLowStockNotice ? 1 : 0);
                      final product = products[productIndex];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1A1A2E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF2A2A4A)
                                  : const Color(0xFFF0F0F5)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF16162A)
                                  : const Color(0xFFF5F5FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: product.photoPath.isNotEmpty ||
                                    product.photoBase64.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: AppImage(
                                        path: product.photoPath,
                                        base64Data: product.photoBase64,
                                        fit: BoxFit.cover),
                                  )
                                : const Icon(Icons.inventory_2_outlined,
                                    size: 24),
                          ),
                          title: Text(product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          subtitle: Text(
                            '${Helpers.formatCurrency(product.price)} · Stok: ${product.stock}${product.minimumStock > 0 && product.stock <= product.minimumStock ? ' · MENIPIS' : ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: product.minimumStock > 0 &&
                                      product.stock <= product.minimumStock
                                  ? Colors.deepOrange
                                  : (isDark
                                      ? const Color(0xFFE94560)
                                      : const Color(0xFF1A1A2E)),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: widget.readOnly
                              ? null
                              : PopupMenuButton<String>(
                                  tooltip: 'Aksi produk',
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'stock_in':
                                        _showStockEntryDialog(product);
                                        break;
                                      case 'stock_opname':
                                        _showStockOpnameDialog(product);
                                        break;
                                      case 'history':
                                        _openStockMovements(product: product);
                                        break;
                                      case 'edit':
                                        _showAddProductDialog(
                                            editProduct: product);
                                        break;
                                      case 'delete':
                                        _deleteProduct(product);
                                        break;
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'stock_in',
                                      child: Text('Tambah stok masuk'),
                                    ),
                                    PopupMenuItem(
                                      value: 'stock_opname',
                                      child: Text('Stok opname'),
                                    ),
                                    PopupMenuItem(
                                      value: 'history',
                                      child: Text('Riwayat stok produk'),
                                    ),
                                    PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Ubah produk'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Hapus produk'),
                                    ),
                                  ],
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddProductDialog(),
              child: const Icon(Icons.add),
            ),
    );
  }
}
