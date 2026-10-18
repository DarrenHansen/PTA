import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/invoice.dart';
import '../models/item.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../providers/invoice_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../database/db_helper.dart';
import '../utils/helpers.dart';
import '../utils/app_localizations.dart';
import '../utils/notification_helper.dart';

/// Add / Edit Invoice Screen
class AddInvoiceScreen extends StatefulWidget {
  final Invoice? editInvoice;

  const AddInvoiceScreen({super.key, this.editInvoice});

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerController = TextEditingController();
  final _addressController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxController = TextEditingController(text: '0');
  final _discountController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  List<Item> _items = [];
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedDueDate = DateTime.now().add(const Duration(days: 30));
  InvoiceStatus _selectedStatus = InvoiceStatus.unpaid;

  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProductProvider>().loadProducts();
    });
    _taxController.addListener(() {
      setState(() {});
    });

    _discountController.addListener(() {
      setState(() {});
    });
    if (widget.editInvoice != null) {
      _isEditing = true;
      final invoice = widget.editInvoice!;
      _customerController.text = invoice.customerName;
      _addressController.text = invoice.customerAddress;
      _emailController.text = invoice.customerEmail;
      _phoneController.text = invoice.customerPhone;
      _taxController.text = invoice.tax.toStringAsFixed(0);
      _discountController.text = invoice.discount.toStringAsFixed(0);
      _notesController.text = invoice.notes;
      _selectedDate = DateTime.tryParse(invoice.date) ?? DateTime.now();
      _selectedDueDate = DateTime.tryParse(invoice.dueDate) ??
          DateTime.now().add(const Duration(days: 30));
      _selectedStatus = invoice.status;
      _loadItemsForEdit(invoice.id!);
    }
  }

  Future<void> _loadItemsForEdit(int invoiceId) async {
    final data = await DBHelper.instance.getItems(invoiceId);
    setState(() {
      _items = data.map((map) => Item.fromMap(map)).toList();
    });
  }

  @override
  void dispose() {
    _customerController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _taxController.dispose();
    _discountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get _taxAmount =>
      _subtotal * ((double.tryParse(_taxController.text) ?? 0) / 100);
  double get _grandTotal =>
      _subtotal + _taxAmount - (double.tryParse(_discountController.text) ?? 0);

  Future<void> _selectDate(BuildContext context, bool isDueDate) async {
    final initial = isDueDate ? _selectedDueDate : _selectedDate;
    final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: DateTime(2100));
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _selectedDueDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
  }

  /// Show customer selection dialog
  void _showCustomerSelection() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final customerProvider = context.read<CustomerProvider>();

    final TextEditingController searchController = TextEditingController();

    List<Customer> filteredCustomers = List.from(customerProvider.customers);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterCustomers(String query) {
              setModalState(() {
                if (query.trim().isEmpty) {
                  filteredCustomers = List.from(customerProvider.customers);
                } else {
                  filteredCustomers = customerProvider.customers
                      .where(
                        (customer) =>
                            customer.name.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                            customer.phone.toLowerCase().contains(
                                  query.toLowerCase(),
                                ) ||
                            customer.email.toLowerCase().contains(
                                  query.toLowerCase(),
                                ),
                      )
                      .toList();
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.get('select_customer'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // BUTTON BUAT PELANGGAN BARU
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final customer = await _showNewCustomerDialog();
                            if (customer == null || !mounted) return;
                            setState(() {
                              _customerController.text = customer.name;
                              _addressController.text = customer.address;
                              _emailController.text = customer.email;
                              _phoneController.text = customer.phone;
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(
                            Icons.person_add,
                            size: 18,
                          ),
                          label: Text(
                            loc.get('create_new_customer'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? const Color(0xFFE94560)
                                : const Color(0xFF1A1A2E),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // SEARCH BAR
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: filterCustomers,
                        decoration: InputDecoration(
                          hintText: loc.get('search_clients'),
                          prefixIcon: const Icon(
                            Icons.search,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFFF5F5FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // CUSTOMER LIST
                    Expanded(
                      child: filteredCustomers.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 40,
                                    color: isDark
                                        ? const Color(0xFF6666AA)
                                        : const Color(0xFFCCCCDD),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    loc.get('no_clients'),
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF6666AA)
                                          : const Color(0xFF9999AA),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredCustomers.length,
                              itemBuilder: (_, index) {
                                final customer = filteredCustomers[index];

                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A1A2E)
                                        : const Color(0xFFF5F5FA),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: (isDark
                                              ? const Color(0xFFE94560)
                                              : const Color(0xFF1A1A2E))
                                          .withOpacity(0.1),
                                      child: Text(
                                        customer.name[0].toUpperCase(),
                                        style: TextStyle(
                                          color: isDark
                                              ? const Color(0xFFE94560)
                                              : const Color(0xFF1A1A2E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      customer.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      customer.phone.isNotEmpty
                                          ? customer.phone
                                          : customer.email,
                                    ),
                                    trailing: Icon(
                                      Icons.check_circle,
                                      color: isDark
                                          ? const Color(0xFFE94560)
                                          : const Color(0xFF1A1A2E),
                                    ),
                                    onTap: () {
                                      setState(() {
                                        _customerController.text =
                                            customer.name;

                                        _addressController.text =
                                            customer.address;

                                        _emailController.text = customer.email;

                                        _phoneController.text = customer.phone;
                                      });

                                      Navigator.pop(ctx);
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Customer?> _showNewCustomerDialog() async {
    final loc = AppLocalizations.of(context);
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    var isSaving = false;

    final customer = await showDialog<Customer>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(loc.get('add_client')),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      InputDecoration(labelText: loc.get('client_name')),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? loc.get('required_field')
                      : null,
                ),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      InputDecoration(labelText: loc.get('client_phone')),
                ),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      InputDecoration(labelText: loc.get('client_email')),
                ),
                TextFormField(
                  controller: addressController,
                  maxLines: 2,
                  decoration:
                      InputDecoration(labelText: loc.get('client_address')),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text(loc.get('cancel')),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final saved = await this
                            .context
                            .read<CustomerProvider>()
                            .addCustomer(Customer(
                              name: nameController.text.trim(),
                              phone: phoneController.text.trim(),
                              email: emailController.text.trim(),
                              address: addressController.text.trim(),
                            ));
                        if (!dialogContext.mounted) return;
                        if (saved == null) {
                          setDialogState(() => isSaving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                                content: Text('Pelanggan gagal disimpan.')),
                          );
                          return;
                        }
                        Navigator.pop(dialogContext, saved);
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                              content:
                                  Text('Gagal menyimpan pelanggan: $error')),
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(loc.get('save')),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    return customer;
  }

  /// Show add item dialog with option to select from saved products
  void _showAddItemDialog() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final productProvider = context.read<ProductProvider>();

    final TextEditingController searchController = TextEditingController();

    List<Product> filteredProducts = List.from(productProvider.products);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void filterProducts(String query) {
              setModalState(() {
                if (query.trim().isEmpty) {
                  filteredProducts = List.from(productProvider.products);
                } else {
                  filteredProducts = productProvider.products
                      .where(
                        (product) => product.name
                            .toLowerCase()
                            .contains(query.toLowerCase()),
                      )
                      .toList();
                }
              });
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loc.get('add_item'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // BUTTON BUAT BARU
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCreateItemDialog();
                          },
                          icon: const Icon(
                            Icons.add,
                            size: 18,
                          ),
                          label: Text(
                            loc.get('create_new_item'),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isDark
                                  ? const Color(0xFF2A2A4A)
                                  : const Color(0xFFE0E0F0),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // SEARCH BAR
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: filterProducts,
                        decoration: InputDecoration(
                          hintText: loc.get('search_products'),
                          prefixIcon: const Icon(
                            Icons.search,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFFF5F5FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PRODUCT LIST
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 40,
                                    color: isDark
                                        ? const Color(0xFF6666AA)
                                        : const Color(0xFFCCCCDD),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    loc.get('no_products'),
                                    style: TextStyle(
                                      color: isDark
                                          ? const Color(0xFF6666AA)
                                          : const Color(0xFF9999AA),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: filteredProducts.length,
                              itemBuilder: (_, index) {
                                final product = filteredProducts[index];

                                return Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A1A2E)
                                        : const Color(0xFFF5F5FA),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: ListTile(
                                    leading: Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF16162A)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2_outlined,
                                      ),
                                    ),
                                    title: Text(
                                      product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${Helpers.formatCurrency(product.price)} · Stok: ${product.stock}',
                                    ),
                                    trailing: Icon(
                                      Icons.add_circle_rounded,
                                      color: isDark
                                          ? const Color(0xFFE94560)
                                          : const Color(0xFF1A1A2E),
                                    ),
                                    onTap: () {
                                      Navigator.pop(ctx);

                                      _showQuantityDialog(
                                        product,
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showCreateItemDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(loc.get('create_new_item'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: loc.get('product_name'),
                      prefixIcon: const Icon(Icons.inventory_2_outlined)),
                  validator: (value) =>
                      value?.isEmpty ?? true ? loc.get('required_field') : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: priceController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: loc.get('price'),
                            prefixIcon: const Icon(Icons.attach_money)),
                        validator: (value) => value?.isEmpty ?? true
                            ? loc.get('required_field')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: loc.get('qty'),
                            prefixIcon: const Icon(Icons.numbers)),
                        validator: (value) => value?.isEmpty ?? true
                            ? loc.get('required_field')
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(loc.get('cancel'))),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      priceController.text.isNotEmpty &&
                      qtyController.text.isNotEmpty) {
                    setState(() {
                      _addOrUpdateItem(
                        productName: nameController.text.trim(),
                        price: double.parse(priceController.text),
                        qty: int.parse(qtyController.text),
                      );
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: Text(loc.get('add')),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showQuantityDialog(Product product) {
    final qtyController = TextEditingController(text: '1');
    final loc = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedQty = int.tryParse(qtyController.text);
            final canAdd = parsedQty != null &&
                parsedQty > 0 &&
                parsedQty <= product.stock;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                product.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Helpers.formatCurrency(product.price),
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text('Stok tersedia: ${product.stock}',
                      style: TextStyle(
                          color:
                              product.stock > 0 ? Colors.green : Colors.red)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          final currentQty =
                              int.tryParse(qtyController.text) ?? 1;
                          if (currentQty > 1) {
                            setDialogState(() {
                              qtyController.text = '${currentQty - 1}';
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final currentQty =
                              int.tryParse(qtyController.text) ?? 0;
                          if (currentQty < product.stock) {
                            setDialogState(() {
                              qtyController.text = '${currentQty + 1}';
                            });
                          }
                        },
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(loc.get('cancel')),
                ),
                ElevatedButton(
                  onPressed: !canAdd
                      ? null
                      : () {
                          _addOrUpdateItem(
                            productId: product.id,
                            productName: product.name,
                            price: product.price,
                            qty: parsedQty!,
                          );
                          Navigator.pop(ctx);
                        },
                  child: Text(loc.get('add')),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(qtyController.dispose);
  }

  Future<void> _saveInvoice() async {
    final loc = AppLocalizations.of(context);
    if (_formKey.currentState?.validate() ?? false) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.get('add_min_item'))));
        return;
      }

      setState(() => _isSaving = true);

      try {
        final invoice = Invoice(
          id: widget.editInvoice?.id,
          invoiceNumber: widget.editInvoice?.invoiceNumber ?? '',
          customerName: _customerController.text.trim(),
          customerAddress: _addressController.text.trim(),
          customerEmail: _emailController.text.trim(),
          customerPhone: _phoneController.text.trim(),
          date: Helpers.dateToDb(_selectedDate),
          dueDate: Helpers.dateToDb(_selectedDueDate),
          total: _grandTotal,
          tax: double.tryParse(_taxController.text) ?? 0,
          discount: double.tryParse(_discountController.text) ?? 0,
          notes: _notesController.text.trim(),
          status: _selectedStatus,
          items: _items,
        );

        final provider = context.read<InvoiceProvider>();
        final productProvider = context.read<ProductProvider>();
        bool success;

        if (_isEditing) {
          success = await provider.updateInvoice(invoice);
        } else {
          final result = await provider.addInvoice(invoice);
          success = result != null;

          // Schedule notifications for new invoice
          if (result != null) {
            await NotificationHelper.scheduleInvoiceReminders(
              invoiceId: result.id ?? 0,
              invoiceNumber: result.invoiceNumber,
              customerName: result.customerName,
              dueDate: _selectedDueDate,
            );
          }
        }

        if (success) {
          await productProvider.loadProducts();
        }

        if (mounted) {
          if (success) {
            Navigator.pop(context, invoice);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(provider.lastError ?? loc.get('failed_save'))),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _addOrUpdateItem({
    int? productId,
    required String productName,
    required double price,
    required int qty,
  }) {
    final existingIndex = _items.indexWhere((item) => productId != null
        ? item.productId == productId
        : item.productId == null &&
            item.productName.toLowerCase() == productName.toLowerCase() &&
            item.price == price);

    if (existingIndex != -1) {
      // Produk sudah ada → tambah quantity
      setState(() {
        final existingItem = _items[existingIndex];

        _items[existingIndex] = Item(
          invoiceId: existingItem.invoiceId,
          productId: existingItem.productId,
          productName: existingItem.productName,
          price: existingItem.price,
          qty: existingItem.qty + qty,
        );
      });
    } else {
      // Produk belum ada → tambah item baru
      setState(() {
        _items.add(
          Item(
            invoiceId: 0,
            productId: productId,
            productName: productName,
            price: price,
            qty: qty,
          ),
        );
      });
    }
  }

  void _showEditQuantityDialog(int index) {
    final qtyController =
        TextEditingController(text: _items[index].qty.toString());
    final loc = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final parsedQty = int.tryParse(qtyController.text);
            final canSave = parsedQty != null && parsedQty > 0;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                _items[index].productName,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    Helpers.formatCurrency(_items[index].price),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          final currentQty =
                              int.tryParse(qtyController.text) ?? 1;
                          if (currentQty > 1) {
                            setDialogState(() {
                              qtyController.text = '${currentQty - 1}';
                            });
                          }
                        },
                        icon: const Icon(
                          Icons.remove_circle_outline,
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Jumlah',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final currentQty =
                              int.tryParse(qtyController.text) ?? 0;
                          setDialogState(() {
                            qtyController.text = '${currentQty + 1}';
                          });
                        },
                        icon: const Icon(
                          Icons.add_circle_outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(loc.get('cancel')),
                ),
                ElevatedButton(
                  onPressed: canSave
                      ? () {
                          setState(() {
                            _items[index] = Item(
                              invoiceId: _items[index].invoiceId,
                              productId: _items[index].productId,
                              productName: _items[index].productName,
                              price: _items[index].price,
                              qty: parsedQty!,
                            );
                          });

                          Navigator.pop(ctx);
                        }
                      : null,
                  child: Text(loc.get('save')),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(qtyController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.get(_isEditing ? 'edit_invoice' : 'create_invoice'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context)),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info Section
              _buildSectionHeader(loc.get('customer_info'), isDark),
              const SizedBox(height: 12),

              // Customer selection button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showCustomerSelection,
                  icon: const Icon(Icons.person_search_outlined, size: 18),
                  label: Text(loc.get('select_saved')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(
                        color: isDark
                            ? const Color(0xFF2A2A4A)
                            : const Color(0xFFE0E0F0)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _customerController,
                decoration: InputDecoration(
                    labelText: loc.get('customer_name'),
                    prefixIcon: const Icon(Icons.person_outline)),
                validator: (value) => value?.isEmpty ?? true
                    ? loc.get('customer_name_required')
                    : null,
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                    labelText: loc.get('customer_address'),
                    prefixIcon: const Icon(Icons.location_on_outlined)),
                // Optional - no validator
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                          labelText: loc.get('email'),
                          prefixIcon: const Icon(Icons.email_outlined)),
                      // Optional - no validator
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                          labelText: loc.get('phone'),
                          prefixIcon: const Icon(Icons.phone_outlined)),
                      // Optional - no validator
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date & Status Section
              _buildSectionHeader(loc.get('date_status'), isDark),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildDatePicker(
                        label: loc.get('date'),
                        date: _selectedDate,
                        isDark: isDark,
                        onTap: () => _selectDate(context, false)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDatePicker(
                        label: loc.get('due_date'),
                        date: _selectedDueDate,
                        isDark: isDark,
                        onTap: () => _selectDate(context, true)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_isEditing)
                DropdownButtonFormField<InvoiceStatus>(
                  value: _selectedStatus,
                  decoration: InputDecoration(
                      labelText: loc.get('status'),
                      prefixIcon: const Icon(Icons.label_outline)),
                  items: InvoiceStatus.values.map((status) {
                    return DropdownMenuItem(
                        value: status, child: Text(status.label));
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedStatus = value);
                  },
                ),
              const SizedBox(height: 20),

              // Items Section
              _buildSectionHeader(loc.get('product_items'), isDark),
              const SizedBox(height: 12),

              if (_items.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFFF5F5FA),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 40,
                          color: isDark
                              ? const Color(0xFF6666AA)
                              : const Color(0xFFCCCCDD)),
                      const SizedBox(height: 10),
                      Text(loc.get('no_items'),
                          style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF6666AA)
                                  : const Color(0xFFCCCCDD))),
                    ],
                  ),
                )
              else
                ...List.generate(_items.length, (index) {
                  final item = _items[index];
                  return _buildItemTile(item, index, isDark);
                }),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _showAddItemDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(loc.get('add_item')),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF2A2A4A)
                          : const Color(0xFFE0E0F0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tax & Discount Section
              _buildSectionHeader(loc.get('tax_discount'), isDark),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _taxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                          labelText: loc.get('tax_percent'),
                          prefixIcon: const Icon(Icons.percent),
                          suffixText: '%'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _discountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: loc.get('discount'),
                          prefixIcon: const Icon(Icons.discount)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: loc.get('notes'),
                    prefixIcon: const Icon(Icons.notes),
                    alignLabelWithHint: true),
              ),
              const SizedBox(height: 24),

              _buildSummaryCard(isDark, loc),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveInvoice,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          loc.get(
                              _isEditing ? 'update_invoice' : 'save_invoice'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E),
          letterSpacing: 0.3),
    );
  }

  Widget _buildDatePicker(
      {required String label,
      required DateTime date,
      required bool isDark,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
        child: Text(
          Helpers.formatDate(Helpers.dateToDb(date)),
          style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildItemTile(Item item, int index, bool isDark) {
    return Dismissible(
      key: ValueKey(item.hashCode + index),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete,
          color: Colors.red.shade400,
        ),
      ),
      onDismissed: (_) => _removeItem(index),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showEditQuantityDialog(index),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.qty} x ${Helpers.formatCurrency(item.price)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF8888AA)
                            : const Color(0xFF9999AA),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to edit quantity',
                      style: TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? const Color(0xFF6666AA)
                            : const Color(0xFFAAAAAA),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: isDark
                        ? const Color(0xFF8888AA)
                        : const Color(0xFF666688),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Helpers.formatCurrency(item.total),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, AppLocalizations loc) {
    final taxPercent = double.tryParse(_taxController.text) ?? 0;

    final discount = double.tryParse(_discountController.text) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            loc.get('subtotal'),
            Helpers.formatCurrency(_subtotal),
            isDark,
          ),

          // TAX
          if (taxPercent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildSummaryRow(
                'Pajak (${taxPercent.toStringAsFixed(0)}%)',
                '${Helpers.formatCurrency(_taxAmount)}',
                isDark,
              ),
            ),

          // DISCOUNT
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildSummaryRow(
                loc.get('discount'),
                '-${Helpers.formatCurrency(discount)}',
                isDark,
                textColor: Colors.red,
              ),
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),

          _buildSummaryRow(
            loc.get('grand_total'),
            Helpers.formatCurrency(_grandTotal),
            isDark,
            isBold: true,
            fontSize: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark,
      {bool isBold = false, double fontSize = 14, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  color: isDark
                      ? const Color(0xFF8888AA)
                      : const Color(0xFF888899),
                  fontWeight: isBold ? FontWeight.w700 : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                  color: textColor ??
                      (isDark ? Colors.white : const Color(0xFF1A1A2E)))),
        ],
      ),
    );
  }
}
