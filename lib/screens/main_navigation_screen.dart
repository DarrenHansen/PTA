import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/app_localizations.dart';
import '../providers/invoice_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/business_profile_provider.dart';
import 'invoice_list_screen.dart';
import 'items_screen.dart';
import 'clients_screen.dart';
import 'settings_screen.dart';
import 'add_invoice_screen.dart';
import 'sales_report_screen.dart';
import 'dashboard_screen.dart';

/// Main Navigation Screen - Bottom navigation with Items, Clients, Settings
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();
  final GlobalKey<SalesReportScreenState> _reportKey =
      GlobalKey<SalesReportScreenState>();

  late final List<Widget> _screens = [
    DashboardScreen(key: _dashboardKey),
    const InvoiceListScreen(),
    SalesReportScreen(key: _reportKey),
    const ItemsScreen(),
    const ClientsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvoiceProvider>().loadInvoices();
      context.read<CustomerProvider>().loadCustomers();
      context.read<ProductProvider>().loadProducts();
      context.read<BusinessProfileProvider>().loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const AddInvoiceScreen(),
              transitionDuration: const Duration(milliseconds: 400),
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                          begin: const Offset(0, 0.08), end: Offset.zero)
                      .animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                );
              },
            ),
          );
          if (!context.mounted) return;
          context.read<InvoiceProvider>().loadInvoices();
          context.read<ProductProvider>().loadProducts();
        },
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          loc.get('create_invoice'),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0D1A) : Colors.white,
          border: Border(
              top: BorderSide(
                  color: isDark
                      ? const Color(0xFF2A2A4A)
                      : const Color(0xFFEEEEF0),
                  width: 1)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                    child: _buildNavItem(
                        Icons.dashboard_outlined, 'Ringkasan', 0, isDark)),
                Expanded(
                    child: _buildNavItem(Icons.receipt_long_outlined,
                        loc.get('invoices'), 1, isDark)),
                Expanded(
                    child: _buildNavItem(Icons.bar_chart_rounded,
                        loc.get('reports'), 2, isDark)),
                Expanded(
                    child: _buildNavItem(
                        Icons.inventory_2_outlined, 'Stok', 3, isDark)),
                Expanded(
                    child: _buildNavItem(
                        Icons.people_outline, 'Kontak', 4, isDark)),
                Expanded(
                    child: _buildNavItem(Icons.settings_outlined,
                        loc.get('settings'), 5, isDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? (isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E))
        : (isDark ? const Color(0xFF6666AA) : const Color(0xFF9999AA));

    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
        if (index == 0) _dashboardKey.currentState?.refresh();
        if (index == 2) _reportKey.currentState?.refresh();
        if (index == 3) context.read<ProductProvider>().loadProducts();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
