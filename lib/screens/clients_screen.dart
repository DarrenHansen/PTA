import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/customer_provider.dart';
import '../utils/app_localizations.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/empty_state_widget.dart';

/// Clients/Contacts Screen - Kelola data pelanggan/klien
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  final _searchController = TextEditingController();
  List<Customer> _filteredClients = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) async {
    // Saat kosong -> tampilkan semua customer lagi
    if (query.trim().isEmpty) {
      setState(() {
        _filteredClients = [];
      });
      return;
    }

    final results =
        await context.read<CustomerProvider>().searchCustomers(query);

    if (mounted) {
      setState(() {
        _filteredClients = results;
      });
    }
  }

  void _showAddClientDialog({Customer? editClient}) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: editClient?.name ?? '');
    final phoneController =
        TextEditingController(text: editClient?.phone ?? '');
    final emailController =
        TextEditingController(text: editClient?.email ?? '');
    final addressController =
        TextEditingController(text: editClient?.address ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get(editClient != null ? 'edit_client' : 'add_client'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                      labelText: loc.get('client_name'),
                      prefixIcon: const Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: loc.get('client_phone'),
                      prefixIcon: const Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: loc.get('client_email'),
                      prefixIcon: const Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressController,
                  decoration: InputDecoration(
                      labelText: loc.get('client_address'),
                      prefixIcon: const Icon(Icons.location_on_outlined)),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.get('cancel'))),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nama pelanggan wajib diisi.')),
                );
                return;
              }
              final customer = Customer(
                id: editClient?.id,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim(),
                address: addressController.text.trim(),
              );
              try {
                final saved = editClient != null
                    ? await context
                        .read<CustomerProvider>()
                        .updateCustomer(customer)
                    : await context
                            .read<CustomerProvider>()
                            .addCustomer(customer) !=
                        null;
                if (!saved) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pelanggan gagal disimpan.')),
                  );
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal menyimpan pelanggan: $error')),
                );
              }
            },
            child: Text(loc.get('save')),
          ),
        ],
      ),
    );
  }

  void _deleteClient(Customer client) {
    final loc = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('delete_client')),
        content: Text(loc.get('delete_client_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.get('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<CustomerProvider>().deleteCustomer(client.id!);
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
                      loc.get('clients_contacts'),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                          letterSpacing: -0.5),
                    ),
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
                            _filteredClients = [];
                          });
                        } else {
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
                      _filteredClients = [];
                    });
                  },
                  hintText: loc.get('search_clients'),
                ),
              ),
            Expanded(
              child: Consumer<CustomerProvider>(
                builder: (context, provider, _) {
                  final customers = _searchController.text.trim().isEmpty
                      ? provider.customers
                      : _filteredClients;

                  if (customers.isEmpty) {
                    return EmptyStateWidget(
                      icon: Icons.people_outline,
                      title: loc.get('no_clients'),
                      subtitle: loc.get('create_first_client'),
                      actionIcon: Icons.add,
                      actionLabel: loc.get('add_client'),
                      onAction: () => _showAddClientDialog(),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    itemBuilder: (context, index) {
                      final customer = customers[index];
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
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: (isDark
                                    ? const Color(0xFFE94560)
                                    : const Color(0xFF1A1A2E))
                                .withOpacity(0.1),
                            child: Text(
                              customer.name.isNotEmpty
                                  ? customer.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? const Color(0xFFE94560)
                                      : const Color(0xFF1A1A2E)),
                            ),
                          ),
                          title: Text(customer.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (customer.phone.isNotEmpty)
                                Text(customer.phone,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFF8888AA)
                                            : const Color(0xFF9999AA))),
                              if (customer.email.isNotEmpty)
                                Text(customer.email,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? const Color(0xFF8888AA)
                                            : const Color(0xFF9999AA))),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _showAddClientDialog(
                                      editClient: customer)),
                              IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 20, color: Colors.red.shade400),
                                  onPressed: () => _deleteClient(customer)),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddClientDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
