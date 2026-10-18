import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/invoice.dart';
import '../models/item.dart';
import '../models/business_profile.dart';
import '../database/db_helper.dart';
import 'pdf_helper.dart';
import 'helpers.dart';

/// Share Helper - Bagikan invoice via WhatsApp, Email, atau file
class ShareHelper {
  /// Share invoice sebagai file PDF
  static Future<void> shareInvoicePdf({
    required Invoice invoice,
    required List<Item> items,
  }) async {
    try {
      final profileData = await DBHelper.instance.getBusinessProfile();
      final profile =
          profileData != null ? BusinessProfile.fromMap(profileData) : null;

      final bytes = await PdfHelper.generateInvoiceBytes(
        invoice: invoice,
        items: items,
        businessProfile: profile,
      );

      await Share.shareXFiles(
        [
          XFile.fromData(bytes,
              name: '${invoice.invoiceNumber}.pdf', mimeType: 'application/pdf')
        ],
        subject: 'Invoice ${invoice.invoiceNumber} - ${invoice.customerName}',
        text: _buildShareText(invoice),
      );
    } catch (e) {
      throw Exception('Gagal membagikan invoice: $e');
    }
  }

  /// Share invoice teks langsung ke WhatsApp
  static Future<void> shareToWhatsApp({
    required Invoice invoice,
    required List<Item> items,
  }) async {
    final text = _buildWhatsAppText(invoice, items);
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(text)}');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await Share.share(text, subject: 'Invoice ${invoice.invoiceNumber}');
    }
  }

  /// Share invoice via Email
  static Future<void> shareViaEmail({
    required Invoice invoice,
    required List<Item> items,
  }) async {
    try {
      final profileData = await DBHelper.instance.getBusinessProfile();
      final profile =
          profileData != null ? BusinessProfile.fromMap(profileData) : null;

      final bytes = await PdfHelper.generateInvoiceBytes(
        invoice: invoice,
        items: items,
        businessProfile: profile,
      );

      final emailUri = Uri(
        scheme: 'mailto',
        path: invoice.customerEmail.isNotEmpty ? invoice.customerEmail : '',
        queryParameters: {
          'subject':
              'Invoice ${invoice.invoiceNumber} - ${invoice.customerName}',
          'body': _buildShareText(invoice),
        },
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        await Share.shareXFiles(
          [
            XFile.fromData(bytes,
                name: '${invoice.invoiceNumber}.pdf',
                mimeType: 'application/pdf')
          ],
          subject: 'Invoice ${invoice.invoiceNumber} - ${invoice.customerName}',
        );
      }
    } catch (e) {
      throw Exception('Gagal mengirim email: $e');
    }
  }

  static String _buildShareText(Invoice invoice) {
    final buffer = StringBuffer();
    buffer.writeln('--- INVOICE ---');
    buffer.writeln('No: ${invoice.invoiceNumber}');
    buffer.writeln('Customer: ${invoice.customerName}');
    buffer.writeln('Tanggal: ${Helpers.formatDateFull(invoice.date)}');
    buffer.writeln('Jatuh Tempo: ${Helpers.formatDateFull(invoice.dueDate)}');
    buffer.writeln('Status: ${invoice.status.label}');
    buffer.writeln('Total: ${Helpers.formatCurrency(invoice.total)}');
    if (invoice.notes.isNotEmpty) {
      buffer.writeln('Catatan: ${invoice.notes}');
    }
    buffer.writeln('---');
    return buffer.toString();
  }

  static String _buildWhatsAppText(Invoice invoice, List<Item> items) {
    final buffer = StringBuffer();
    buffer.writeln('*INVOICE*');
    buffer.writeln('No: ${invoice.invoiceNumber}');
    buffer.writeln('Customer: ${invoice.customerName}');
    buffer.writeln('Tanggal: ${Helpers.formatDateFull(invoice.date)}');
    buffer.writeln('Jatuh Tempo: ${Helpers.formatDateFull(invoice.dueDate)}');
    buffer.writeln('');
    buffer.writeln('*Detail Item:*');

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln('${i + 1}. ${item.productName}');
      buffer.writeln(
          '   ${item.qty} x ${Helpers.formatCurrency(item.price)} = ${Helpers.formatCurrency(item.total)}');
    }

    buffer.writeln('');
    buffer.writeln('*Total: ${Helpers.formatCurrency(invoice.total)}*');
    buffer.writeln('Status: ${invoice.status.label}');
    buffer.writeln('');
    buffer.writeln('Terima kasih!');
    return buffer.toString();
  }
}
