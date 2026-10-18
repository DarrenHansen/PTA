import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/db_helper.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../providers/product_provider.dart';
import '../utils/helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  List<Invoice> _invoices = [];
  int _lateInvoicesCount = 0;
  bool _loading = true;
  String? _error;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  Future<void> refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final start = _today.subtract(const Duration(days: 6));
      final rows = await DBHelper.instance.getInvoicesInDateRange(
        Helpers.dateToDb(start),
        Helpers.dateToDb(_today),
      );
      final lateRows = await DBHelper.instance.getOverdueInvoices();
      if (!mounted) return;
      setState(() {
        _invoices = rows.map(Invoice.fromMap).toList();
        _lateInvoicesCount = lateRows.length;
      });
      await context.read<ProductProvider>().loadProducts();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _paidSales => _invoices
      .where((invoice) => invoice.status == InvoiceStatus.paid)
      .fold(0, (sum, invoice) => sum + invoice.total);

  double get _unpaidAmount => _invoices
      .where((invoice) => invoice.status != InvoiceStatus.paid)
      .fold(0, (sum, invoice) => sum + invoice.total);

  List<Product> _lowStockProducts(List<Product> products) => products
      .where((product) =>
          product.minimumStock > 0 && product.stock <= product.minimumStock)
      .toList()
    ..sort((a, b) => a.stock.compareTo(b.stock));

  Map<String, double> _salesByDay() {
    final values = <String, double>{};
    for (var offset = 6; offset >= 0; offset--) {
      final day = _today.subtract(Duration(days: offset));
      values[Helpers.dateToDb(day)] = 0;
    }
    for (final invoice in _invoices) {
      if (invoice.status != InvoiceStatus.paid) continue;
      final key = invoice.date.length >= 10
          ? invoice.date.substring(0, 10)
          : invoice.date;
      if (values.containsKey(key)) values[key] = values[key]! + invoice.total;
    }
    return values;
  }

  Widget _metricCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: (MediaQuery.sizeOf(context).width - 44) / 2,
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE8E8EF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 8),
          Text(title,
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 10),
        child: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final lowStock = _lowStockProducts(products);
    final salesByDay = _salesByDay();
    final maxSale = salesByDay.values.fold<double>(0, (max, value) {
      return value > max ? value : max;
    });
    final stockUnits =
        products.fold<int>(0, (sum, product) => sum + product.stock);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ringkasan',
                            style: TextStyle(
                                fontSize: 27, fontWeight: FontWeight.w800)),
                        Text(
                          'Aktivitas 7 hari terakhir',
                          style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Muat ulang ringkasan',
                    onPressed: _loading ? null : refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading && _invoices.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _invoices.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.cloud_off_outlined, size: 40),
                                const SizedBox(height: 12),
                                const Text('Ringkasan belum dapat dimuat.'),
                                const SizedBox(height: 8),
                                Text(_error!,
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                                TextButton(
                                    onPressed: refresh,
                                    child: const Text('Coba lagi')),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: refresh,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _metricCard(
                                    icon: Icons.receipt_long_outlined,
                                    color: const Color(0xFF5367B1),
                                    title: 'Invoice dibuat',
                                    value: '${_invoices.length}',
                                  ),
                                  _metricCard(
                                    icon: Icons.payments_outlined,
                                    color: Colors.green,
                                    title: 'Penjualan lunas',
                                    value: Helpers.formatCurrency(_paidSales),
                                  ),
                                  _metricCard(
                                    icon: Icons.hourglass_bottom_rounded,
                                    color: Colors.orange,
                                    title: 'Belum dibayar',
                                    value:
                                        Helpers.formatCurrency(_unpaidAmount),
                                  ),
                                  _metricCard(
                                    icon: Icons.warning_amber_rounded,
                                    color: Colors.deepOrange,
                                    title: 'Terlambat (semua)',
                                    value: '$_lateInvoicesCount invoice',
                                  ),
                                  _metricCard(
                                    icon: Icons.inventory_2_outlined,
                                    color: const Color(0xFF5367B1),
                                    title: 'Jumlah produk',
                                    value: '${products.length}',
                                  ),
                                  _metricCard(
                                    icon: Icons.warehouse_outlined,
                                    color: Colors.teal,
                                    title: 'Total unit persediaan',
                                    value: '$stockUnits unit',
                                  ),
                                ],
                              ),
                              _sectionTitle('Penjualan lunas per hari'),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1A1A2E)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF2A2A4A)
                                          : const Color(0xFFE8E8EF)),
                                ),
                                child: Column(
                                  children: salesByDay.entries.map((entry) {
                                    final day = DateTime.tryParse(entry.key);
                                    final label = day == null
                                        ? entry.key
                                        : '${day.day}/${day.month}';
                                    final progress = maxSale == 0
                                        ? 0.0
                                        : (entry.value / maxSale)
                                            .clamp(0.0, 1.0);
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 11),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                              width: 42, child: Text(label)),
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: LinearProgressIndicator(
                                                value: progress,
                                                minHeight: 10,
                                                backgroundColor: isDark
                                                    ? Colors.white12
                                                    : const Color(0xFFEDEDF3),
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              Helpers.formatCurrency(
                                                  entry.value),
                                              textAlign: TextAlign.end,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              _sectionTitle(
                                  'Peringatan stok minimum (${lowStock.length})'),
                              if (lowStock.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF1A1A2E)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                      'Tidak ada produk yang mencapai batas minimum stok. Atur batasnya melalui menu Ubah Produk.'),
                                )
                              else
                                ...lowStock.take(5).map((product) => Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.deepOrange),
                                        title: Text(product.name),
                                        subtitle: Text(
                                            'Batas minimum: ${product.minimumStock}'),
                                        trailing: Text(
                                          '${product.stock} tersisa',
                                          style: const TextStyle(
                                            color: Colors.deepOrange,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )),
                              if (lowStock.length > 5)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                      'Dan ${lowStock.length - 5} produk lainnya.'),
                                ),
                              if (_loading)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
