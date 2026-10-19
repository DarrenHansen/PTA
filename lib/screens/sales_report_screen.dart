import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../models/business_profile.dart';
import '../models/invoice.dart';
import '../models/item.dart';
import '../utils/helpers.dart';
import 'invoice_detail_screen.dart';
import '../utils/pdf_helper.dart';
import '../utils/report_export_helper.dart';

enum _ReportStatusFilter { all, paid, unpaid, late }

extension on _ReportStatusFilter {
  String get label => switch (this) {
        _ReportStatusFilter.all => 'Semua',
        _ReportStatusFilter.paid => 'Paid',
        _ReportStatusFilter.unpaid => 'Unpaid',
        _ReportStatusFilter.late => 'Late',
      };
}

/// Sales summary based on invoice dates stored in Fasnote.
class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => SalesReportScreenState();
}

class SalesReportScreenState extends State<SalesReportScreen> {
  late DateTimeRange _range;
  List<Invoice> _invoices = [];
  List<Invoice> _overdueInvoices = [];
  _ReportStatusFilter _statusFilter = _ReportStatusFilter.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(today.year, today.month, 1),
      end: DateTime(today.year, today.month, today.day),
    );
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<List<Map<String, dynamic>>>([
        DBHelper.instance.getInvoicesInDateRange(
          Helpers.dateToDb(_range.start),
          Helpers.dateToDb(_range.end),
        ),
        DBHelper.instance.getOverdueInvoices(),
      ]);
      final invoices = results[0].map(Invoice.fromMap).toList();
      final overdueInvoices = results[1]
          .map(Invoice.fromMap)
          .where((invoice) => invoice.isOverdue)
          .toList();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _overdueInvoices = overdueInvoices;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Laporan gagal dimuat. Coba muat ulang.';
        _loading = false;
      });
    }
  }

  void _toggleStatusFilter(_ReportStatusFilter filter) {
    setState(() {
      _statusFilter =
          _statusFilter == filter ? _ReportStatusFilter.all : filter;
    });
  }

  Future<void> _exportExcel() async {
    try {
      final invoices = await _loadInvoiceDetailsForExport();
      await ReportExportHelper.exportSalesExcel(
        invoices: invoices,
        lateInvoiceCount: _lateInvoices.length,
        startDate: _range.start,
        endDate: _range.end,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor Excel: $error')),
      );
    }
  }

  Future<void> _exportPdf() async {
    try {
      final invoices = await _loadInvoiceDetailsForExport();
      final profileData = await DBHelper.instance.getBusinessProfile();
      await PdfHelper.generateSalesReportPdf(
        invoices: invoices,
        lateInvoiceCount: _lateInvoices.length,
        startDate: _range.start,
        endDate: _range.end,
        businessProfile:
            profileData == null ? null : BusinessProfile.fromMap(profileData),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengekspor PDF: $error')),
      );
    }
  }

  Future<void> refresh() => _loadReport();

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: _range.end,
      initialDate: _range.start,
      helpText: 'Pilih tanggal awal',
    );
    if (picked == null) return;
    setState(() {
      _range = DateTimeRange(
        start: DateTime(picked.year, picked.month, picked.day),
        end: _range.end,
      );
    });
    await _loadReport();
  }

  Future<void> _selectEndDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: _range.start,
      lastDate: DateTime(today.year, today.month, today.day),
      initialDate: _range.end,
      helpText: 'Pilih tanggal akhir',
    );
    if (picked == null) return;
    setState(() {
      _range = DateTimeRange(
        start: _range.start,
        end: DateTime(picked.year, picked.month, picked.day),
      );
    });
    await _loadReport();
  }

  List<Invoice> get _paidInvoices => _invoices
      .where((invoice) => invoice.status == InvoiceStatus.paid)
      .toList();

  List<Invoice> get _unpaidInvoices => _invoices
      .where((invoice) => invoice.status != InvoiceStatus.paid)
      .toList();

  List<Invoice> get _lateInvoices => _overdueInvoices;

  double get _totalSales =>
      _paidInvoices.fold(0, (sum, invoice) => sum + invoice.total);

  double get _totalUnpaid =>
      _unpaidInvoices.fold(0, (sum, invoice) => sum + invoice.total);

  Future<List<Invoice>> _loadInvoiceDetailsForExport() async =>
      Future.wait(_invoices.map((invoice) async {
        if (invoice.status != InvoiceStatus.paid ||
            invoice.items.isNotEmpty ||
            invoice.id == null) {
          return invoice;
        }
        final rows = await DBHelper.instance.getItems(invoice.id!);
        return invoice.copyWith(
          items: rows.map((row) => Item.fromMap(row)).toList(),
        );
      }));

  List<Invoice> get _visibleInvoices {
    switch (_statusFilter) {
      case _ReportStatusFilter.all:
        return _invoices;
      case _ReportStatusFilter.paid:
        return _paidInvoices;
      case _ReportStatusFilter.unpaid:
        return _unpaidInvoices.where((invoice) => !invoice.isOverdue).toList();
      case _ReportStatusFilter.late:
        return _lateInvoices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadReport,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
            children: [
              Text('Laporan Penjualan',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                  'Penjualan mengikuti periode; invoice terlambat dihitung dari semua periode.',
                  style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2A2A4A)
                        : const Color(0xFFE8E8EF),
                  ),
                ),
                child: Column(children: [
                  _DateSelectorTile(
                    label: 'Dari tanggal',
                    value: Helpers.formatDate(Helpers.dateToDb(_range.start)),
                    onTap: _selectStartDate,
                    primary: primary,
                    isDark: isDark,
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? const Color(0xFF2A2A4A)
                        : const Color(0xFFE8E8EF),
                  ),
                  _DateSelectorTile(
                    label: 'Sampai tanggal',
                    value: Helpers.formatDate(Helpers.dateToDb(_range.end)),
                    onTap: _selectEndDate,
                    primary: primary,
                    isDark: isDark,
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Filter status',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    _statusFilter == _ReportStatusFilter.all
                        ? 'Semua status'
                        : _statusFilter.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  _StatusFilterChip(
                    filter: _ReportStatusFilter.paid,
                    selected: _statusFilter == _ReportStatusFilter.paid,
                    color: Colors.green,
                    onSelected: () =>
                        _toggleStatusFilter(_ReportStatusFilter.paid),
                  ),
                  _StatusFilterChip(
                    filter: _ReportStatusFilter.unpaid,
                    selected: _statusFilter == _ReportStatusFilter.unpaid,
                    color: Colors.amber,
                    onSelected: () =>
                        _toggleStatusFilter(_ReportStatusFilter.unpaid),
                  ),
                  _StatusFilterChip(
                    filter: _ReportStatusFilter.late,
                    selected: _statusFilter == _ReportStatusFilter.late,
                    color: Colors.red,
                    onSelected: () =>
                        _toggleStatusFilter(_ReportStatusFilter.late),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _exportExcel,
                      icon: const Icon(Icons.table_view_outlined),
                      label: const Text('Excel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _exportPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _SummaryCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Jumlah Invoice (Periode)',
                  value: '${_invoices.length}',
                  accent: primary,
                  isDark: isDark,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _SummaryCard(
                  icon: Icons.money_off_outlined,
                  label: 'Belum Dibayar (Periode)',
                  value: Helpers.formatCurrency(_totalUnpaid),
                  accent: Colors.orange,
                  isDark: isDark,
                )),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _SummaryCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Telat Bayar (Semua Periode)',
                  value: '${_lateInvoices.length} invoice',
                  accent: Colors.red,
                  isDark: isDark,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _SummaryCard(
                  icon: Icons.payments_outlined,
                  label: 'Total Penjualan Lunas (Periode)',
                  value: Helpers.formatCurrency(_totalSales),
                  accent: const Color(0xFF2E8B57),
                  isDark: isDark,
                )),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                    child: Text(
                        _statusFilter == _ReportStatusFilter.late
                            ? 'Invoice terlambat (semua periode)'
                            : 'Invoice dalam periode',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800))),
                Text('${_visibleInvoices.length} invoice',
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54)),
              ]),
              const SizedBox(height: 10),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                _MessageCard(
                    message: _error!,
                    actionLabel: 'Coba lagi',
                    onAction: _loadReport)
              else if (_visibleInvoices.isEmpty)
                _MessageCard(
                  message: _statusFilter == _ReportStatusFilter.late
                      ? 'Tidak ada invoice yang terlambat.'
                      : _invoices.isEmpty &&
                              _statusFilter == _ReportStatusFilter.all
                          ? 'Belum ada invoice pada periode ini.'
                          : 'Tidak ada invoice dengan status ${_statusFilter.label}.',
                )
              else
                ..._visibleInvoices
                    .map((invoice) => _InvoiceReportTile(invoice: invoice)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final _ReportStatusFilter filter;
  final bool selected;
  final Color color;
  final VoidCallback onSelected;

  const _StatusFilterChip({
    required this.filter,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => ChoiceChip(
        avatar: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        label: Text(filter.label),
        selected: selected,
        onSelected: (_) => onSelected(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}

class _DateSelectorTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color primary;
  final bool isDark;

  const _DateSelectorTile({
    required this.label,
    required this.value,
    required this.onTap,
    required this.primary,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(children: [
            Icon(Icons.calendar_month_outlined, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined, size: 20, color: primary),
          ]),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final bool isDark;

  const _SummaryCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.accent,
      required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 124),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE8E8EF)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: accent, size: 21),
          const SizedBox(height: 12),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : Colors.black54)),
          const SizedBox(height: 4),
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800))),
        ]),
      );
}

class _InvoiceReportTile extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceReportTile({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFE8E8EF)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        title: Text(invoice.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${invoice.invoiceNumber} · ${Helpers.formatDate(invoice.date)}'),
              if (invoice.isOverdue) ...[
                const SizedBox(height: 3),
                Text(
                  '${Helpers.formatOverdueDuration(invoice.dueDate)} terlambat',
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        isThreeLine: invoice.isOverdue,
        trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Helpers.formatCurrency(invoice.total),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(invoice.isOverdue ? 'Terlambat' : invoice.status.label,
                  style: TextStyle(
                      fontSize: 11,
                      color: invoice.status == InvoiceStatus.paid
                          ? Colors.green
                          : invoice.isOverdue
                              ? Colors.red
                              : Colors.orange)),
            ]),
        onTap: () async {
          final items = await DBHelper.instance.getItems(invoice.id!);
          if (!context.mounted) return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(
                    invoice: invoice.copyWith(
                        items:
                            items.map((item) => Item.fromMap(item)).toList())),
              ));
          if (context.mounted) {
            final state =
                context.findAncestorStateOfType<SalesReportScreenState>();
            await state?.refresh();
          }
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _MessageCard({required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A2E)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: [
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ]),
      );
}
