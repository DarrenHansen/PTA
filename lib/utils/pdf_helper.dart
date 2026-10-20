import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../models/invoice.dart';
import '../models/item.dart';
import '../models/business_profile.dart';
import 'helpers.dart';

/// PDF Helper - Generate invoice PDF profesional
class PdfHelper {
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static pw.Font? _italicFont;
  static pw.MemoryImage? _cachedLogo;
  static String? _cachedLogoPath;
  static Future<pw.MemoryImage?> _loadLogo(String path,
      {String base64Data = ''}) async {
    if (base64Data.isNotEmpty) {
      final cacheKey = 'base64:${base64Data.hashCode}';
      if (_cachedLogo != null && _cachedLogoPath == cacheKey) {
        return _cachedLogo;
      }
      try {
        final value = base64Data.startsWith('data:')
            ? base64Data.substring(base64Data.indexOf(',') + 1)
            : base64Data;
        _cachedLogo = pw.MemoryImage(base64Decode(value));
        _cachedLogoPath = cacheKey;
        return _cachedLogo;
      } catch (_) {
        // Fall back to the Storage URL below if the embedded image is invalid.
      }
    }
    if (path.isEmpty) return null;

    // gunakan cache jika path sama
    if (_cachedLogo != null && _cachedLogoPath == path) {
      return _cachedLogo;
    }

    late final Uint8List imageBytes;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      final response = await http.get(Uri.parse(path)).timeout(
            const Duration(seconds: 15),
          );
      if (response.statusCode != 200) return null;
      imageBytes = response.bodyBytes;
    } else {
      return null;
    }

    _cachedLogo = pw.MemoryImage(imageBytes);

    _cachedLogoPath = path;

    return _cachedLogo;
  }

  static Future<void> _initFonts() async {
    if (_fontInitialized) return;

    _regularFont = await PdfGoogleFonts.nunitoRegular();

    _boldFont = await PdfGoogleFonts.nunitoBold();

    _italicFont = await PdfGoogleFonts.nunitoItalic();

    _fontInitialized = true;
  }

  static Future<void> preload() async {
    await _initFonts();
  }

  static bool _fontInitialized = false;
  static Future<void> generateAndPreviewInvoice({
    required Invoice invoice,
    required List<Item> items,
    BusinessProfile? businessProfile,
  }) async {
    final pdf = await _buildInvoicePdf(invoice, items, businessProfile);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<Uint8List> generateInvoiceBytes({
    required Invoice invoice,
    required List<Item> items,
    BusinessProfile? businessProfile,
  }) async {
    final pdf = await _buildInvoicePdf(invoice, items, businessProfile);
    return Uint8List.fromList(await pdf.save());
  }

  static Future<void> generateSalesReportPdf({
    required List<Invoice> invoices,
    required int lateInvoiceCount,
    required int soldItemQuantity,
    required DateTime startDate,
    required DateTime endDate,
    BusinessProfile? businessProfile,
  }) async {
    await _initFonts();
    final paidInvoices = invoices
        .where((invoice) => invoice.status == InvoiceStatus.paid)
        .toList();
    final unpaidInvoices =
        invoices.where((invoice) => invoice.status != InvoiceStatus.paid);
    final unpaidTotal =
        unpaidInvoices.fold<double>(0, (sum, invoice) => sum + invoice.total);
    final total =
        paidInvoices.fold<double>(0, (sum, invoice) => sum + invoice.total);
    final tableRows = paidInvoices.asMap().entries.map((entry) {
      final invoice = entry.value;
      return [
        '${entry.key + 1}',
        invoice.invoiceNumber,
        Helpers.formatDate(invoice.date),
        invoice.customerName,
        invoice.status.label,
        Helpers.formatCurrency(invoice.total),
      ];
    }).toList();
    tableRows.add([
      '',
      '',
      '',
      '',
      'TOTAL LUNAS',
      Helpers.formatCurrency(total),
    ]);
    pw.MemoryImage? reportLogo;
    if (businessProfile != null &&
        (businessProfile.logoBase64.isNotEmpty ||
            businessProfile.logoPath.isNotEmpty)) {
      try {
        reportLogo = await _loadLogo(
          businessProfile.logoPath,
          base64Data: businessProfile.logoBase64,
        );
      } catch (_) {
        reportLogo = null;
      }
    }
    final detailWidgets = <pw.Widget>[];
    if (paidInvoices.isNotEmpty) {
      detailWidgets.add(pw.NewPage());
      detailWidgets.add(
        pw.Text(
          'DETAIL NOTA PENJUALAN',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      );
      detailWidgets.add(pw.SizedBox(height: 5));
      detailWidgets.add(
        pw.Text(
          'Rincian berikut hanya memuat invoice yang sudah lunas.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      );
      detailWidgets.add(pw.SizedBox(height: 14));
      for (var index = 0; index < paidInvoices.length; index++) {
        if (index > 0) detailWidgets.add(pw.NewPage());
        detailWidgets.addAll(
          _buildSalesReportInvoiceDetail(
            paidInvoices[index],
            index + 1,
            businessProfile,
            reportLogo,
          ),
        );
      }
    }
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _regularFont!,
        bold: _boldFont!,
        italic: _italicFont!,
      ),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text('LAPORAN PENJUALAN',
              style:
                  pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text(
              'Periode: ${Helpers.formatDateFull(startDate.toIso8601String())} - ${Helpers.formatDateFull(endDate.toIso8601String())}'),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            pw.Expanded(
                child: pw.Text('Jumlah invoice (periode): ${invoices.length}')),
            pw.Expanded(
                child: pw.Text(
                    'Belum dibayar (periode): ${Helpers.formatCurrency(unpaidTotal)}')),
          ]),
          pw.SizedBox(height: 5),
          pw.Row(children: [
            pw.Expanded(
                child: pw.Text(
                    'Telat bayar (semua periode): $lateInvoiceCount invoice')),
            pw.Expanded(
                child:
                    pw.Text('Invoice lunas diekspor: ${paidInvoices.length}')),
          ]),
          pw.SizedBox(height: 5),
          pw.Text(
              'Total penjualan lunas (periode): ${Helpers.formatCurrency(total)}'),
          pw.SizedBox(height: 5),
          pw.Text('Jumlah barang terjual (periode): $soldItemQuantity unit'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Rincian tabel hanya memuat invoice lunas.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: [
              'No',
              'Invoice',
              'Tanggal',
              'Pelanggan',
              'Status',
              'Total'
            ],
            data: tableRows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {5: pw.Alignment.centerRight},
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerPadding: const pw.EdgeInsets.all(6),
            cellPadding: const pw.EdgeInsets.all(6),
          ),
          ...detailWidgets,
        ],
      ),
    );
    final filename =
        'laporan_penjualan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await Printing.sharePdf(bytes: await pdf.save(), filename: filename);
  }

  static List<pw.Widget> _buildSalesReportInvoiceDetail(
    Invoice invoice,
    int number,
    BusinessProfile? businessProfile,
    pw.MemoryImage? businessLogo,
  ) {
    final businessInfo = <String>[
      if (businessProfile?.businessAddress.isNotEmpty == true)
        'Alamat: ${businessProfile!.businessAddress}',
      if (businessProfile?.businessPhone.isNotEmpty == true)
        'Telepon: ${businessProfile!.businessPhone}',
      if (businessProfile?.businessEmail.isNotEmpty == true)
        'Email: ${businessProfile!.businessEmail}',
      if (businessProfile?.bankAccounts.isNotEmpty == true)
        ...businessProfile!.bankAccounts.map(
          (bank) =>
              'Bank: ${bank.bankName} - ${bank.bankAccount} (${bank.bankHolder})',
        ),
    ];
    final customerInfo = <String>[
      'Nama: ${invoice.customerName}',
      if (invoice.customerAddress.isNotEmpty)
        'Alamat: ${invoice.customerAddress}',
      if (invoice.customerPhone.isNotEmpty) 'Telepon: ${invoice.customerPhone}',
      if (invoice.customerEmail.isNotEmpty) 'Email: ${invoice.customerEmail}',
    ];

    return [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Row(
              children: [
                if (businessLogo != null) ...[
                  pw.Container(
                    width: 44,
                    height: 44,
                    margin: const pw.EdgeInsets.only(right: 8),
                    child: pw.Image(businessLogo, fit: pw.BoxFit.contain),
                  ),
                ],
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (businessProfile?.businessName.isNotEmpty == true)
                        pw.Text(
                          businessProfile!.businessName,
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      pw.Text(
                        'DETAIL NOTA ${number.toString().padLeft(2, '0')}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(invoice.invoiceNumber),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              _buildStatusBadge(invoice.status),
              pw.SizedBox(height: 5),
              pw.Text('Tanggal: ${Helpers.formatDateFull(invoice.date)}'),
              if (invoice.dueDate.isNotEmpty)
                pw.Text(
                    'Jatuh tempo: ${Helpers.formatDateFull(invoice.dueDate)}'),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 12),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _buildReportInfoCard(
              'INFO BISNIS',
              businessProfile?.businessName ?? 'Fasnote',
              businessInfo,
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _buildReportInfoCard(
              'INFO PELANGGAN',
              invoice.customerName,
              customerInfo.skip(1).toList(),
            ),
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      _buildSectionTitle('RINCIAN ITEM'),
      pw.SizedBox(height: 6),
      _buildItemsTable(invoice.items),
      pw.SizedBox(height: 12),
      _buildSummary(invoice, invoice.items),
      if (invoice.notes.isNotEmpty) ...[
        pw.SizedBox(height: 12),
        _buildReportInfoCard('CATATAN', invoice.notes, const []),
      ],
    ];
  }

  static pw.Widget _buildReportInfoCard(
    String title,
    String heading,
    List<String> details,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(title),
            pw.SizedBox(height: 6),
            pw.Text(
              heading,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            ...details.map(
              (detail) => pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(detail, style: const pw.TextStyle(fontSize: 9)),
              ),
            ),
          ],
        ),
      );

  static Future<pw.Document> _buildInvoicePdf(
    Invoice invoice,
    List<Item> items,
    BusinessProfile? businessProfile,
  ) async {
    await _initFonts();

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _regularFont!,
        bold: _boldFont!,
        italic: _italicFont!,
      ),
    );

    pw.MemoryImage? logoImage;

    if (businessProfile != null &&
        (businessProfile.logoBase64.isNotEmpty ||
            businessProfile.logoPath.isNotEmpty)) {
      logoImage = await _loadLogo(
        businessProfile.logoPath,
        base64Data: businessProfile.logoBase64,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // ===== HEADER =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // LEFT SIDE
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LOGO
                  if (logoImage != null)
                    pw.Container(
                      width: 90,
                      height: 90,
                      margin: const pw.EdgeInsets.only(right: 16),
                      child: pw.Image(
                        logoImage,
                        fit: pw.BoxFit.contain,
                      ),
                    ),

                  // BUSINESS NAME + INVOICE
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (businessProfile != null &&
                          businessProfile.businessName.isNotEmpty) ...[
                        pw.Text(
                          businessProfile.businessName,
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'INVOICE',
                          style: const pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ] else ...[
                        pw.Text(
                          'INVOICE',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Text(
                        invoice.invoiceNumber,
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // RIGHT SIDE
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _buildStatusBadge(invoice.status),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Tanggal: ${Helpers.formatDateFull(invoice.date)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    'Jatuh Tempo: ${Helpers.formatDateFull(invoice.dueDate)}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

// ===== INFO BISNIS & CUSTOMER =====
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // INFO BISNIS
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('INFO BISNIS'),
                      pw.SizedBox(height: 8),
                      if (businessProfile != null) ...[
                        if (businessProfile.businessAddress.isNotEmpty)
                          _buildCompactInfo(
                            'Alamat',
                            businessProfile.businessAddress,
                          ),

                        if (businessProfile.businessPhone.isNotEmpty)
                          _buildCompactInfo(
                            'Telp',
                            businessProfile.businessPhone,
                          ),

                        if (businessProfile.businessEmail.isNotEmpty)
                          _buildCompactInfo(
                            'Email',
                            businessProfile.businessEmail,
                          ),

                        // MULTI BANK
                        if (businessProfile.bankAccounts.isNotEmpty)
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'Bank',
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: PdfColors.grey600,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              ...businessProfile.bankAccounts
                                  .map((bank) => pw.Padding(
                                        padding:
                                            const pw.EdgeInsets.only(bottom: 3),
                                        child: pw.Text(
                                          '${bank.bankName} - ${bank.bankAccount} (${bank.bankHolder})',
                                          style: const pw.TextStyle(
                                            fontSize: 10,
                                            color: PdfColors.black,
                                          ),
                                        ),
                                      )),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              pw.SizedBox(width: 16),

              // INFO CUSTOMER
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('INFO PELANGGAN'),
                      pw.SizedBox(height: 8),
                      _buildCompactInfo(
                        'Nama',
                        invoice.customerName,
                      ),
                      if (invoice.customerAddress.isNotEmpty)
                        _buildCompactInfo(
                          'Alamat',
                          invoice.customerAddress,
                        ),
                      if (invoice.customerEmail.isNotEmpty)
                        _buildCompactInfo(
                          'Email',
                          invoice.customerEmail,
                        ),
                      if (invoice.customerPhone.isNotEmpty)
                        _buildCompactInfo(
                          'Telepon',
                          invoice.customerPhone,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ===== TABEL ITEMS =====
          pw.SizedBox(height: 15),
          _buildSectionTitle('RINCIAN ITEM'),
          pw.SizedBox(height: 4),
          _buildItemsTable(items),

          pw.SizedBox(height: 12),

          // ===== TOTAL SUMMARY =====
          _buildSummary(invoice, items),
          if (invoice.notes.isNotEmpty ||
              (businessProfile != null &&
                  businessProfile.notes.isNotEmpty)) ...[
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // CATATAN BISNIS
                if (businessProfile != null && businessProfile.notes.isNotEmpty)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Text(
                        businessProfile.notes,
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey700,
                          lineSpacing: 2,
                        ),
                      ),
                    ),
                  ),

                // SPACING TENGAH
                if (businessProfile != null &&
                    businessProfile.notes.isNotEmpty &&
                    invoice.notes.isNotEmpty)
                  pw.SizedBox(width: 16),

                // CATATAN INVOICE
                if (invoice.notes.isNotEmpty)
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(12),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('CATATAN'),
                          pw.SizedBox(height: 8),
                          pw.Text(
                            invoice.notes,
                            style: const pw.TextStyle(
                              fontSize: 10,
                              color: PdfColors.grey700,
                              lineSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // ===== FOOTER =====
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Terima kasih atas kepercayaan Anda.',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey500),
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  static pw.Widget _buildStatusBadge(dynamic status) {
    String label;
    PdfColor color;

    switch (status.toString()) {
      case 'InvoiceStatus.paid':
      case 'paid':
        label = 'LUNAS';
        color = PdfColors.green;
        break;
      case 'InvoiceStatus.overdue':
      case 'overdue':
        label = 'JATUH TEMPO';
        color = PdfColors.red;
        break;
      default:
        label = 'BELUM BAYAR';
        color = PdfColors.orange;
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: pw.BoxDecoration(
          color: color, borderRadius: pw.BorderRadius.circular(4)),
      child: pw.Text(label,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)),
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Text(title,
        style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700));
  }

  static pw.Widget _buildCompactInfo(
    String label,
    String value,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey600,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(List<Item> items) {
    return pw.TableHelper.fromTextArray(
      headers: ['No', 'Produk', 'Harga', 'Qty', 'Total'],
      data: items.asMap().entries.map((entry) {
        final index = entry.key + 1;
        final item = entry.value;
        return [
          index.toString(),
          item.productName,
          Helpers.formatCurrency(item.price),
          item.qty.toString(),
          Helpers.formatCurrency(item.total),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.blue800,
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(6),
          topRight: pw.Radius.circular(6),
        ),
      ),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
      ),
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FixedColumnWidth(40),
        4: const pw.FlexColumnWidth(2),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.center,
        4: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _buildSummary(Invoice invoice, List<Item> items) {
    final subtotal = items.fold<double>(0, (sum, item) => sum + item.total);
    final taxAmount = subtotal * (invoice.tax / 100);
    final grandTotal = subtotal + taxAmount - invoice.discount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        children: [
          _buildSummaryRow('Subtotal', Helpers.formatCurrency(subtotal)),
          if (invoice.tax > 0)
            _buildSummaryRow('Pajak (${invoice.tax.toStringAsFixed(0)}%)',
                Helpers.formatCurrency(taxAmount)),
          if (invoice.discount > 0)
            _buildSummaryRow(
                'Diskon', '- ${Helpers.formatCurrency(invoice.discount)}',
                textColor: PdfColors.red),
          pw.Divider(color: PdfColors.grey300),
          _buildSummaryRow('GRAND TOTAL', Helpers.formatCurrency(grandTotal),
              isBold: true, fontSize: 14),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow(String label, String value,
      {bool isBold = false, double fontSize = 11, PdfColor? textColor}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: textColor)),
        ],
      ),
    );
  }
}
