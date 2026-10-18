import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/invoice_provider.dart';
import '../providers/product_provider.dart';
import '../utils/app_localizations.dart';
import '../models/invoice.dart';
import '../widgets/invoice_card.dart';
import '../widgets/app_search_bar.dart';
import '../widgets/status_filter_chips.dart';
import '../widgets/empty_state_widget.dart';
import 'add_invoice_screen.dart';
import 'invoice_detail_screen.dart';

/// Invoice List Screen - Halaman utama daftar invoice
class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceProvider>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<InvoiceProvider>().searchInvoices(query);
  }

  void _onSearchClose() {
    _searchController.clear();

    FocusScope.of(context).unfocus();

    setState(() => _isSearching = false);

    context.read<InvoiceProvider>().resetFilters();
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
    final provider = context.read<InvoiceProvider>();
    if (filter == 'all') {
      provider.filterByStatus(null);
    } else {
      provider.filterByStatus(_statusFromString(filter));
    }
  }

  InvoiceStatus _statusFromString(String status) {
    switch (status) {
      case 'paid':
        return InvoiceStatus.paid;
      case 'unpaid':
        return InvoiceStatus.unpaid;
      case 'overdue':
        return InvoiceStatus.overdue;
      default:
        return InvoiceStatus.unpaid;
    }
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
            _buildHeader(context, isDark, loc),
            const SizedBox(height: 8),
            if (_isSearching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onClose: _onSearchClose,
                  showClose: true,
                ),
              ),
            if (_isSearching) const SizedBox(height: 12),
            StatusFilterChips(
                selectedFilter: _selectedFilter,
                onFilterChanged: _onFilterChanged),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<InvoiceProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final invoices = provider.invoices;

                  if (invoices.isEmpty) {
                    if (_isSearching || _selectedFilter != 'all') {
                      return EmptyStateWidget(
                        icon: Icons.search_off_rounded,
                        title: loc.get('not_found'),
                        subtitle: loc.get('try_change_search'),
                      );
                    }
                    return EmptyStateWidget(
                      icon: Icons.receipt_long_outlined,
                      title: loc.get('no_invoices'),
                      subtitle: loc.get('create_first'),
                      actionIcon: Icons.add,
                      actionLabel: loc.get('create_invoice'),
                      onAction: () => _navigateToAdd(context),
                    );
                  }

                  return RefreshIndicator(
                    color: isDark
                        ? const Color(0xFFE94560)
                        : const Color(0xFF1A1A2E),
                    onRefresh: () => provider.loadInvoices(),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, bottom: 100),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: invoices.length,
                      itemBuilder: (context, index) {
                        return FutureBuilder(
                          future: provider.loadItems(invoices[index].id!),
                          builder: (context, itemSnapshot) {
                            final invoice = invoices[index]
                                .copyWith(items: itemSnapshot.data ?? []);
                            return InvoiceCard(
                              invoice: invoice,
                              onTap: () async {
                                final result = await Navigator.push(
                                  context,
                                  PageRouteBuilder(
                                    pageBuilder: (_, __, ___) =>
                                        InvoiceDetailScreen(invoice: invoice),
                                    transitionDuration:
                                        const Duration(milliseconds: 400),
                                    transitionsBuilder:
                                        (_, animation, __, child) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      );
                                    },
                                  ),
                                );

                                if (result == true && mounted) {
                                  provider.loadInvoices();
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.get('invoices'),
                  style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      letterSpacing: -0.5),
                ),
                Consumer<InvoiceProvider>(
                  builder: (context, provider, _) {
                    return Text(
                      '${provider.totalCount} ${loc.get('invoice_total')}',
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? const Color(0xFF8888AA)
                              : const Color(0xFF888899)),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF0F0F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(_isSearching ? Icons.close : Icons.search_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  size: 22),
              onPressed: () {
                if (_isSearching) {
                  _onSearchClose();
                } else {
                  setState(() => _isSearching = true);

                  Future.delayed(
                    const Duration(milliseconds: 100),
                    () {
                      _searchFocusNode.requestFocus();
                    },
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToAdd(BuildContext context) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AddInvoiceScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      ),
    );
    if (mounted) {
      context.read<InvoiceProvider>().loadInvoices();
      context.read<ProductProvider>().loadProducts();
    }
  }
}
