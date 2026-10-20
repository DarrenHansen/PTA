import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/app_localizations.dart';
import '../providers/invoice_provider.dart';
import '../providers/customer_provider.dart';
import '../providers/product_provider.dart';
import '../providers/business_profile_provider.dart';
import '../services/auth_service.dart';
import 'invoice_list_screen.dart';
import 'items_screen.dart';
import 'clients_screen.dart';
import 'settings_screen.dart';
import 'add_invoice_screen.dart';
import 'sales_report_screen.dart';
import 'dashboard_screen.dart';
import 'stock_movement_screen.dart';
import 'auth_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final String role;
  const MainNavigationScreen({super.key, this.role = 'cashier'});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey =
      GlobalKey<DashboardScreenState>();
  final GlobalKey<SalesReportScreenState> _reportKey =
      GlobalKey<SalesReportScreenState>();

  bool get _isOwner => widget.role == 'owner';

  late final List<Widget> _screens = _isOwner
      ? [
          const ItemsScreen(readOnly: true),
          const StockMovementScreen(),
          SalesReportScreen(key: _reportKey, readOnly: true),
        ]
      : [
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
      if (_isOwner) {
        context.read<ProductProvider>().loadProducts();
        return;
      }
      context.read<InvoiceProvider>().loadInvoices();
      context.read<CustomerProvider>().loadCustomers();
      context.read<ProductProvider>().loadProducts();
      context.read<BusinessProfileProvider>().loadProfile();
    });
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen(hasAccount: true)),
      (_) => false,
    );
  }

  void _selectTab(int index) {
    if (_isOwner && index == 3) {
      _logout();
      return;
    }
    setState(() => _currentIndex = index);
    if (_isOwner) {
      if (index == 0) context.read<ProductProvider>().loadProducts();
      if (index == 2) _reportKey.currentState?.refresh();
      return;
    }
    if (index == 0) _dashboardKey.currentState?.refresh();
    if (index == 2) _reportKey.currentState?.refresh();
    if (index == 3) context.read<ProductProvider>().loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);
    final destinations = _isOwner
        ? <(IconData, String)>[
            (Icons.inventory_2_outlined, 'Barang'),
            (Icons.history_rounded, 'Stok'),
            (Icons.bar_chart_rounded, loc.get('reports')),
            (Icons.logout_rounded, 'Keluar'),
          ]
        : <(IconData, String)>[
            (Icons.dashboard_outlined, 'Ringkasan'),
            (Icons.receipt_long_outlined, loc.get('invoices')),
            (Icons.bar_chart_rounded, loc.get('reports')),
            (Icons.inventory_2_outlined, 'Stok'),
            (Icons.people_outline, 'Kontak'),
            (Icons.settings_outlined, loc.get('settings')),
          ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      floatingActionButton: _isOwner
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const AddInvoiceScreen(),
                    transitionDuration: const Duration(milliseconds: 400),
                    transitionsBuilder: (_, animation, __, child) =>
                        SlideTransition(
                      position: Tween<Offset>(
                              begin: const Offset(0, 0.08), end: Offset.zero)
                          .animate(CurvedAnimation(
                              parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  ),
                );
                if (!context.mounted) return;
                context.read<InvoiceProvider>().loadInvoices();
                context.read<ProductProvider>().loadProducts();
              },
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(loc.get('create_invoice'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14)),
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
                for (var index = 0; index < destinations.length; index++)
                  Expanded(
                    child: _buildNavItem(
                      destinations[index].$1,
                      destinations[index].$2,
                      index,
                      isDark,
                      onTap: () => _selectTab(index),
                      selected: index == _currentIndex,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, bool isDark,
      {required VoidCallback onTap, required bool selected}) {
    final color = selected
        ? (isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E))
        : (isDark ? const Color(0xFF6666AA) : const Color(0xFF9999AA));

    return GestureDetector(
      onTap: onTap,
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
              child: Text(label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
