import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/invoice.dart';
import '../models/item.dart';
import '../models/business_profile.dart';
import '../providers/invoice_provider.dart';
import '../providers/business_profile_provider.dart';
import '../database/db_helper.dart';
import '../utils/helpers.dart';
import '../utils/app_localizations.dart';
import '../utils/pdf_helper.dart';
import '../utils/share_helper.dart';
import '../widgets/status_badge.dart';
import 'add_invoice_screen.dart';

/// Invoice Detail Screen
class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;
  final bool readOnly;

  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    this.readOnly = false,
  });

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  List<Item> _items = [];
  bool _isLoading = true;
  bool _isGeneratingPdf = false;
  late Invoice invoice;

  @override
  void initState() {
    super.initState();

    invoice = widget.invoice;

    _loadItems();
  }

  Future<void> _loadItems() async {
    final data = await DBHelper.instance.getItems(invoice.id!);
    setState(() {
      _items = data.map((map) => Item.fromMap(map)).toList();
      _isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    await _loadItems();
  }

  Future<void> _generatePdf() async {
    if (_isGeneratingPdf) return;

    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      final profile = context.read<BusinessProfileProvider>().profile;

      await PdfHelper.generateAndPreviewInvoice(
        invoice: invoice,
        items: _items,
        businessProfile: profile,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal generate PDF: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
  }

  Future<void> _changeStatus(InvoiceStatus newStatus) async {
    if (widget.readOnly) return;
    await context.read<InvoiceProvider>().updateStatus(invoice.id!, newStatus);

    setState(() {
      invoice = invoice.copyWith(status: newStatus);
    });

    if (mounted) {
      Navigator.pop(context, invoice);
    }
  }

  Future<void> _deleteInvoice() async {
    if (widget.readOnly) return;
    final loc = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.get('delete_invoice')),
        content: Text(loc.get('delete_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(loc.get('cancel'))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(loc.get('delete'))),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<InvoiceProvider>().deleteInvoice(invoice.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  void _showShareBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.get('share_invoice'),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  ),
                  title: Text(loc.get('whatsapp')),
                  subtitle: Text(loc.get('share_whatsapp')),
                  onTap: () {
                    Navigator.pop(ctx);
                    final updatedInvoice = invoice.copyWith(items: _items);
                    ShareHelper.shareToWhatsApp(
                      invoice: updatedInvoice,
                      items: _items,
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEA4335).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.email, color: Color(0xFFEA4335)),
                  ),
                  title: Text(loc.get('email_share')),
                  subtitle: Text(loc.get('send_pdf_email')),
                  onTap: () {
                    Navigator.pop(ctx);
                    final updatedInvoice = invoice.copyWith(items: _items);

                    ShareHelper.shareViaEmail(
                      invoice: updatedInvoice,
                      items: _items,
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: (isDark
                                ? const Color(0xFFE94560)
                                : const Color(0xFF1A1A2E))
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.picture_as_pdf,
                        color: isDark
                            ? const Color(0xFFE94560)
                            : const Color(0xFF1A1A2E)),
                  ),
                  title: Text(loc.get('share_pdf')),
                  subtitle: Text(loc.get('share_pdf_desc')),
                  onTap: () {
                    Navigator.pop(ctx);
                    final updatedInvoice = invoice.copyWith(items: _items);
                    ShareHelper.shareInvoicePdf(
                      invoice: updatedInvoice,
                      items: _items,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToEdit() async {
    if (widget.readOnly) return;
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            AddInvoiceScreen(editInvoice: invoice.copyWith(items: _items)),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: child,
          );
        },
      ),
    );

    if (result != null && result is Invoice) {
      setState(() {
        invoice = result;
      });

      await _refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.get('detail_invoice'),
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: loc.get('export_pdf'),
            onPressed: _isGeneratingPdf ? null : _generatePdf,
            icon: _isGeneratingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
          ),
          IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: loc.get('share'),
              onPressed: _showShareBottomSheet),
          if (!widget.readOnly)
            IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: loc.get('edit'),
                onPressed: _navigateToEdit),
          if (!widget.readOnly)
            IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red.shade400),
                tooltip: loc.get('delete'),
                onPressed: _deleteInvoice),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(isDark, loc),
                  const SizedBox(height: 16),
                  _buildCustomerCard(isDark, loc),
                  const SizedBox(height: 16),
                  _buildItemsCard(isDark, loc),
                  const SizedBox(height: 16),
                  _buildSummaryCard(isDark, loc),
                  const SizedBox(height: 16),
                  if (invoice.notes.isNotEmpty) _buildNotesCard(isDark, loc),
                  const SizedBox(height: 16),
                  if (!widget.readOnly) _buildStatusAction(isDark, loc),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard(bool isDark, AppLocalizations loc) {
    final daysLeft = Helpers.daysUntilDue(invoice.dueDate);
    String? dueInfo;
    Color? dueColor;

    if (invoice.status != InvoiceStatus.paid) {
      if (daysLeft < 0) {
        dueInfo = '${Helpers.formatOverdueDuration(invoice.dueDate)} terlambat';
        dueColor = Colors.red;
      } else if (daysLeft == 0) {
        dueInfo = loc.get('due_today');
        dueColor = Colors.orange;
      } else if (daysLeft <= 7) {
        dueInfo = '$daysLeft ${loc.get('days_left')}';
        dueColor = Colors.orange;
      } else {
        dueInfo = '$daysLeft ${loc.get('days_left')}';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F5FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(invoice.invoiceNumber,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFF9999AA),
                      fontWeight: FontWeight.w500)),
              StatusBadge(status: invoice.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14,
                  color: isDark
                      ? const Color(0xFF6666AA)
                      : const Color(0xFFBBBBCC)),
              const SizedBox(width: 4),
              Text(Helpers.formatDateFull(invoice.date),
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? const Color(0xFF6666AA)
                          : const Color(0xFFBBBBCC))),
              const SizedBox(width: 16),
              Icon(Icons.schedule_outlined,
                  size: 14,
                  color: dueColor ??
                      (isDark
                          ? const Color(0xFF6666AA)
                          : const Color(0xFFBBBBCC))),
              const SizedBox(width: 4),
              Text('JT: ${Helpers.formatDateFull(invoice.dueDate)}',
                  style: TextStyle(
                      fontSize: 13,
                      color: dueColor ??
                          (isDark
                              ? const Color(0xFF6666AA)
                              : const Color(0xFFBBBBCC)))),
            ],
          ),
          if (dueInfo != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: (dueColor ?? Colors.orange).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: dueColor),
                  const SizedBox(width: 4),
                  Text(dueInfo,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dueColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerCard(bool isDark, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.get('customer_info'),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFF8888AA)
                      : const Color(0xFF9999AA),
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    (isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E))
                        .withOpacity(0.1),
                child: Text(
                  invoice.customerName.isNotEmpty
                      ? invoice.customerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? const Color(0xFFE94560)
                          : const Color(0xFF1A1A2E)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(invoice.customerName,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E))),
                    if (invoice.customerAddress.isNotEmpty)
                      Text(invoice.customerAddress,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF8888AA)
                                  : const Color(0xFF9999AA))),
                    if (invoice.customerEmail.isNotEmpty)
                      Text(invoice.customerEmail,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF8888AA)
                                  : const Color(0xFF9999AA))),
                    if (invoice.customerPhone.isNotEmpty)
                      Text(invoice.customerPhone,
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF8888AA)
                                  : const Color(0xFF9999AA))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(bool isDark, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFF0F0F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.get('product_items'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFF9999AA),
                      letterSpacing: 0.5)),
              Text('${_items.length} item',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFF9999AA))),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Text('${index + 1}.',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF8888AA)
                                  : const Color(0xFF9999AA))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item.productName,
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E)))),
                      Text(
                          '${item.qty} x ${Helpers.formatCurrency(item.price)}',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? const Color(0xFF8888AA)
                                  : const Color(0xFF9999AA))),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 90,
                        child: Text(
                          Helpers.formatCurrency(item.total),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < _items.length - 1) const Divider(),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark, AppLocalizations loc) {
    final subtotal = _items.fold<double>(0, (sum, item) => sum + item.total);
    final tax = subtotal * (invoice.tax / 100);
    final total = subtotal + tax - invoice.discount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16162A)]
              : [const Color(0xFF1A1A2E), const Color(0xFF2D2D5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(loc.get('payment_summary'),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 0.5)),
          const SizedBox(height: 14),
          _buildSummaryRow(loc.get('subtotal'),
              Helpers.formatCurrency(subtotal), Colors.white.withOpacity(0.7)),
          if (invoice.tax > 0)
            _buildSummaryRow('Pajak (${invoice.tax.toStringAsFixed(0)}%)',
                Helpers.formatCurrency(tax), Colors.white.withOpacity(0.7)),
          if (invoice.discount > 0)
            _buildSummaryRow(
                loc.get('discount'),
                '-${Helpers.formatCurrency(invoice.discount)}',
                Colors.red.shade300),
          const Divider(color: Color(0xFF3A3A5A), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(loc.get('grand_total'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text(Helpers.formatCurrency(total),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: color)),
        Text(value, style: TextStyle(fontSize: 14, color: color)),
      ]),
    );
  }

  Widget _buildNotesCard(bool isDark, AppLocalizations loc) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? const Color(0xFF2A2A4A) : const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes,
                  size: 16,
                  color: isDark
                      ? const Color(0xFF8888AA)
                      : const Color(0xFFF57F17)),
              const SizedBox(width: 6),
              Text(loc.get('notes'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? const Color(0xFF8888AA)
                          : const Color(0xFFF57F17),
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(invoice.notes,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? const Color(0xFFBBBBCC)
                      : const Color(0xFF5D4037),
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildStatusAction(bool isDark, AppLocalizations loc) {
    if (invoice.status == InvoiceStatus.paid) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () => _changeStatus(InvoiceStatus.unpaid),
          style: OutlinedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(
                color:
                    isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E)),
          ),
          child: Text(loc.get('mark_unpaid'),
              style: TextStyle(
                  color: isDark
                      ? const Color(0xFFE94560)
                      : const Color(0xFF1A1A2E),
                  fontWeight: FontWeight.w600)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: () => _changeStatus(InvoiceStatus.paid),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isDark ? const Color(0xFFE94560) : const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 20),
            const SizedBox(width: 8),
            Text(loc.get('mark_paid'),
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
