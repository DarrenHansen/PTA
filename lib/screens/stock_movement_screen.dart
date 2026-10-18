import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/product_provider.dart';
import '../utils/helpers.dart';

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key, this.productId, this.productName});

  final int? productId;
  final String? productName;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  late Future<List<Map<String, dynamic>>> _movements;

  @override
  void initState() {
    super.initState();
    _movements = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => context
      .read<ProductProvider>()
      .loadStockMovements(productId: widget.productId);

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _movements = next);
    await next;
  }

  String _movementLabel(String type) {
    switch (type) {
      case 'opening':
        return 'Stok awal';
      case 'stock_in':
        return 'Stok masuk';
      case 'stock_opname':
        return 'Stok opname';
      case 'sale':
      case 'invoice_sale':
        return 'Terjual melalui invoice';
      case 'invoice_edit_return':
        return 'Pengembalian dari perubahan invoice';
      case 'invoice_edit_sale':
        return 'Penjualan dari perubahan invoice';
      case 'invoice_cancel':
        return 'Pengembalian dari pembatalan invoice';
      default:
        return type.isEmpty ? 'Perubahan stok' : type;
    }
  }

  int _delta(Map<String, dynamic> row) {
    final previous = (row['previous_stock'] as num?)?.toInt();
    final next = (row['new_stock'] as num?)?.toInt();
    if (previous != null && next != null) return next - previous;
    return (row['quantity'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.productName == null
        ? 'Riwayat Pergerakan Stok'
        : 'Riwayat Stok · ${widget.productName}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _movements,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Belum ada riwayat pergerakan stok.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rows.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Menampilkan hingga 300 pergerakan stok terbaru.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                final row = rows[index - 1];
                final type = '${row['type'] ?? ''}';
                final delta = _delta(row);
                final color = delta >= 0 ? Colors.green : Colors.red;
                final previous = row['previous_stock'];
                final next = row['new_stock'];
                final createdAt = '${row['created_at'] ?? ''}';
                final note = '${row['note'] ?? ''}'.trim();
                final invoiceId = row['invoice_id'];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Icon(
                        delta >= 0 ? Icons.south_west : Icons.north_east,
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      widget.productName == null
                          ? '${row['product_name'] ?? 'Produk'} · ${_movementLabel(type)}'
                          : _movementLabel(type),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Helpers.formatDateTime(createdAt)),
                          if (previous != null && next != null)
                            Text('Stok: $previous → $next'),
                          if (note.isNotEmpty) Text('Catatan: $note'),
                          if (invoiceId != null) Text('Invoice ID: $invoiceId'),
                        ],
                      ),
                    ),
                    trailing: Text(
                      '${delta > 0 ? '+' : ''}$delta',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    isThreeLine: previous != null && next != null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
