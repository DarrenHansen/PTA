import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../models/invoice.dart';
import '../utils/helpers.dart';

class ReportExportHelper {
  static const int _reportColumnCount = 7;
  static const int _detailColumnCount = 14;

  static CellIndex _cell(int column, int row) =>
      CellIndex.indexByColumnRow(columnIndex: column, rowIndex: row);

  static void _styleRow(
    Sheet sheet,
    int row,
    int firstColumn,
    int lastColumn,
    CellStyle style,
  ) {
    for (var column = firstColumn; column <= lastColumn; column++) {
      sheet.cell(_cell(column, row)).cellStyle = style;
    }
  }

  static void _setColumnWidths(Sheet sheet, List<double> widths) {
    for (var column = 0; column < widths.length; column++) {
      sheet.setColumnWidth(column, widths[column]);
    }
  }

  static Future<void> exportSalesExcel({
    required List<Invoice> invoices,
    required int lateInvoiceCount,
    required int soldItemQuantity,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Laporan Penjualan'];
    excel.setDefaultSheet('Laporan Penjualan');
    if (excel.tables.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }
    final detailSheet = excel['Detail Nota'];
    final start = Helpers.dateToDb(startDate);
    final end = Helpers.dateToDb(endDate);
    final fileName =
        'laporan_penjualan_${start.replaceAll('-', '')}_${end.replaceAll('-', '')}.xlsx';
    final paidInvoices = invoices
        .where((invoice) => invoice.status == InvoiceStatus.paid)
        .toList();
    final unpaidInvoices =
        invoices.where((invoice) => invoice.status != InvoiceStatus.paid);
    final unpaidTotal =
        unpaidInvoices.fold<double>(0, (sum, invoice) => sum + invoice.total);
    final total =
        paidInvoices.fold<double>(0, (sum, invoice) => sum + invoice.total);
    final taxTotal = paidInvoices.fold<double>(
      0,
      (sum, invoice) => sum + invoice.subtotal * invoice.tax / 100,
    );

    final titleStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1A1A2E'),
      fontColorHex: ExcelColor.white,
      fontSize: 17,
      bold: true,
      verticalAlign: VerticalAlign.Center,
    );
    final summaryLabelStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#EAF0FA'),
      bold: true,
      verticalAlign: VerticalAlign.Center,
    );
    final summaryValueStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );
    final summaryTextStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Left,
      verticalAlign: VerticalAlign.Center,
    );
    final tableHeaderStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#2563A6'),
      fontColorHex: ExcelColor.white,
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );
    final tableCellStyle = CellStyle(
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#D9E2F3'),
      ),
    );
    final centeredCellStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#D9E2F3'),
      ),
    );
    final currencyStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: const CustomNumericNumFormat(formatCode: '#,##0'),
      bottomBorder: Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#D9E2F3'),
      ),
    );
    final summaryCurrencyStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: const CustomNumericNumFormat(formatCode: '"Rp" #,##0'),
    );
    final plainNumberStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      numberFormat: const CustomNumericNumFormat(formatCode: '#,##0.##'),
    );
    final totalRowStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#EAF0FA'),
      verticalAlign: VerticalAlign.Center,
      topBorder: Border(
        borderStyle: BorderStyle.Medium,
        borderColorHex: ExcelColor.fromHexString('#2563A6'),
      ),
    );

    _setColumnWidths(sheet, const [7, 25, 16, 16, 27, 15, 21]);

    sheet.appendRow([
      TextCellValue('LAPORAN PENJUALAN'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    sheet.merge(_cell(0, 0), _cell(_reportColumnCount - 1, 0));
    _styleRow(sheet, 0, 0, _reportColumnCount - 1, titleStyle);
    sheet.setRowHeight(0, 32);

    void appendSummaryRow(String label, CellValue value,
        {bool currency = false}) {
      sheet.appendRow([TextCellValue(label), TextCellValue(''), value]);
      final row = sheet.maxRows - 1;
      sheet.merge(_cell(0, row), _cell(1, row));
      sheet.merge(_cell(2, row), _cell(3, row));
      _styleRow(sheet, row, 0, 1, summaryLabelStyle);
      sheet.cell(_cell(2, row)).cellStyle = currency
          ? summaryCurrencyStyle
          : value is TextCellValue
              ? summaryTextStyle
              : summaryValueStyle;
    }

    appendSummaryRow(
      'Periode',
      TextCellValue(
          '${Helpers.formatDate(start)} - ${Helpers.formatDate(end)}'),
    );
    appendSummaryRow('Jumlah invoice (periode)', IntCellValue(invoices.length));
    appendSummaryRow(
      'Belum dibayar (periode)',
      DoubleCellValue(unpaidTotal),
      currency: true,
    );
    appendSummaryRow(
        'Telat bayar (semua periode)', IntCellValue(lateInvoiceCount));
    appendSummaryRow(
        'Invoice lunas diekspor', IntCellValue(paidInvoices.length));
    appendSummaryRow(
      'Pajak penjualan lunas (periode)',
      DoubleCellValue(taxTotal),
      currency: true,
    );
    appendSummaryRow(
      'Total penjualan lunas (periode)',
      DoubleCellValue(total),
      currency: true,
    );
    appendSummaryRow(
      'Jumlah barang terjual (periode)',
      IntCellValue(soldItemQuantity),
    );
    sheet.appendRow([TextCellValue('')]);

    final reportHeaderRow = sheet.maxRows;
    final reportDataStartRow = reportHeaderRow + 1;
    sheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Nomor invoice'),
      TextCellValue('Tanggal'),
      TextCellValue('Jatuh tempo'),
      TextCellValue('Pelanggan'),
      TextCellValue('Status'),
      TextCellValue('Total (Rp)'),
    ]);
    _styleRow(
        sheet, reportHeaderRow, 0, _reportColumnCount - 1, tableHeaderStyle);
    sheet.setRowHeight(reportHeaderRow, 28);

    for (var index = 0; index < paidInvoices.length; index++) {
      final invoice = paidInvoices[index];
      final row = reportDataStartRow + index;
      sheet.appendRow([
        IntCellValue(index + 1),
        TextCellValue(invoice.invoiceNumber),
        TextCellValue(Helpers.formatDate(invoice.date)),
        TextCellValue(Helpers.formatDate(invoice.dueDate)),
        TextCellValue(invoice.customerName),
        TextCellValue(invoice.status.label),
        DoubleCellValue(invoice.total),
      ]);
      _styleRow(sheet, row, 0, _reportColumnCount - 1, tableCellStyle);
      sheet.cell(_cell(0, row)).cellStyle = centeredCellStyle;
      sheet.cell(_cell(2, row)).cellStyle = centeredCellStyle;
      sheet.cell(_cell(3, row)).cellStyle = centeredCellStyle;
      sheet.cell(_cell(5, row)).cellStyle = centeredCellStyle;
      sheet.cell(_cell(6, row)).cellStyle = currencyStyle;
    }

    final totalRow = reportDataStartRow + paidInvoices.length;
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('TOTAL LUNAS'),
      DoubleCellValue(total),
    ]);
    _styleRow(sheet, totalRow, 0, _reportColumnCount - 1, totalRowStyle);
    sheet.cell(_cell(5, totalRow)).cellStyle = totalRowStyle.copyWith(
      horizontalAlignVal: HorizontalAlign.Right,
    );
    sheet.cell(_cell(6, totalRow)).cellStyle = summaryCurrencyStyle.copyWith(
      boldVal: true,
      backgroundColorHexVal: ExcelColor.fromHexString('#EAF0FA'),
      topBorderVal: Border(
        borderStyle: BorderStyle.Medium,
        borderColorHex: ExcelColor.fromHexString('#2563A6'),
      ),
    );

    _setColumnWidths(detailSheet,
        const [7, 24, 16, 24, 26, 32, 19, 11, 21, 20, 14, 20, 19, 22]);
    detailSheet.appendRow(List.generate(
      _detailColumnCount,
      (index) => TextCellValue(index == 0 ? 'RINCIAN PENJUALAN LUNAS' : ''),
    ));
    detailSheet.merge(_cell(0, 0), _cell(_detailColumnCount - 1, 0));
    _styleRow(detailSheet, 0, 0, _detailColumnCount - 1, titleStyle);
    detailSheet.setRowHeight(0, 32);

    detailSheet.appendRow([
      TextCellValue('Periode'),
      TextCellValue(
          '${Helpers.formatDate(start)} - ${Helpers.formatDate(end)}'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue('Invoice lunas'),
      IntCellValue(paidInvoices.length),
      TextCellValue('Pajak penjualan'),
      DoubleCellValue(taxTotal),
      TextCellValue(''),
      TextCellValue('Total penjualan'),
      DoubleCellValue(total),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);
    detailSheet.merge(_cell(1, 1), _cell(3, 1));
    detailSheet.merge(_cell(7, 1), _cell(8, 1));
    detailSheet.merge(_cell(10, 1), _cell(13, 1));
    _styleRow(detailSheet, 1, 0, _detailColumnCount - 1, summaryLabelStyle);
    detailSheet.cell(_cell(1, 1)).cellStyle = summaryTextStyle;
    detailSheet.cell(_cell(5, 1)).cellStyle = summaryValueStyle;
    detailSheet.cell(_cell(7, 1)).cellStyle = summaryCurrencyStyle;
    detailSheet.cell(_cell(10, 1)).cellStyle = summaryCurrencyStyle;

    detailSheet.appendRow([
      TextCellValue(
          'Tabel berikut merinci produk pada invoice yang sudah lunas.'),
    ]);
    detailSheet.merge(_cell(0, 2), _cell(_detailColumnCount - 1, 2));

    detailSheet.appendRow([TextCellValue('')]);
    const detailHeaderRow = 4;
    const detailDataStartRow = detailHeaderRow + 1;
    detailSheet.appendRow([
      TextCellValue('No'),
      TextCellValue('Nomor invoice'),
      TextCellValue('Tanggal'),
      TextCellValue('Pelanggan'),
      TextCellValue('Produk'),
      TextCellValue('Keterangan'),
      TextCellValue('Harga satuan (Rp)'),
      TextCellValue('Jumlah'),
      TextCellValue('Total item (Rp)'),
      TextCellValue('Subtotal nota (Rp)'),
      TextCellValue('Pajak (%)'),
      TextCellValue('Pajak (Rp)'),
      TextCellValue('Diskon (Rp)'),
      TextCellValue('Grand total (Rp)'),
    ]);
    _styleRow(detailSheet, detailHeaderRow, 0, _detailColumnCount - 1,
        tableHeaderStyle);
    detailSheet.setRowHeight(detailHeaderRow, 34);

    var detailNumber = 1;
    for (final invoice in paidInvoices) {
      if (invoice.items.isEmpty) {
        detailSheet.appendRow([
          IntCellValue(detailNumber++),
          TextCellValue(invoice.invoiceNumber),
          TextCellValue(Helpers.formatDate(invoice.date)),
          TextCellValue(invoice.customerName),
          TextCellValue(''),
          TextCellValue('Tidak ada rincian item'),
          const DoubleCellValue(0),
          const IntCellValue(0),
          const DoubleCellValue(0),
          DoubleCellValue(invoice.subtotal),
          DoubleCellValue(invoice.tax),
          DoubleCellValue(invoice.subtotal * invoice.tax / 100),
          DoubleCellValue(invoice.discount),
          DoubleCellValue(invoice.total),
        ]);
        continue;
      }

      for (var itemIndex = 0; itemIndex < invoice.items.length; itemIndex++) {
        final item = invoice.items[itemIndex];
        final isFirstItem = itemIndex == 0;
        detailSheet.appendRow([
          IntCellValue(detailNumber++),
          TextCellValue(invoice.invoiceNumber),
          TextCellValue(Helpers.formatDate(invoice.date)),
          TextCellValue(invoice.customerName),
          TextCellValue(item.productName),
          TextCellValue(item.description),
          DoubleCellValue(item.price),
          IntCellValue(item.qty),
          DoubleCellValue(item.total),
          isFirstItem ? DoubleCellValue(invoice.subtotal) : TextCellValue(''),
          isFirstItem ? DoubleCellValue(invoice.tax) : TextCellValue(''),
          isFirstItem
              ? DoubleCellValue(invoice.subtotal * invoice.tax / 100)
              : TextCellValue(''),
          isFirstItem ? DoubleCellValue(invoice.discount) : TextCellValue(''),
          isFirstItem ? DoubleCellValue(invoice.total) : TextCellValue(''),
        ]);
      }
      detailSheet.appendRow([TextCellValue('')]);
    }

    final detailLastRow = detailSheet.maxRows - 1;
    for (var row = detailDataStartRow; row <= detailLastRow; row++) {
      _styleRow(
        detailSheet,
        row,
        0,
        _detailColumnCount - 1,
        tableCellStyle,
      );
      detailSheet.cell(_cell(0, row)).cellStyle = centeredCellStyle;
      detailSheet.cell(_cell(2, row)).cellStyle = centeredCellStyle;
      detailSheet.cell(_cell(7, row)).cellStyle = centeredCellStyle;
      for (final column in [6, 8, 9, 11, 12, 13]) {
        detailSheet.cell(_cell(column, row)).cellStyle = currencyStyle;
      }
      detailSheet.cell(_cell(10, row)).cellStyle = plainNumberStyle;
    }

    final bytes = excel.save(fileName: fileName);
    if (kIsWeb) return;
    if (bytes == null) throw StateError('Berkas Excel gagal dibuat.');

    await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(bytes),
          name: fileName,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      subject: 'Laporan Penjualan Fasnote',
      text:
          'Laporan penjualan ${Helpers.formatDate(start)} - ${Helpers.formatDate(end)}',
    );
  }
}
