import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';

// Pre-computed PdfColor constants from hex values
const _kPrimary = PdfColor(0.145, 0.388, 0.922);     // #2563EB
const _kLightBlue = PdfColor(0.937, 0.965, 1.0);     // #EFF6FF
const _kDark1 = PdfColor(0.118, 0.161, 0.231);       // #1E293B
const _kGrey1 = PdfColor(0.392, 0.455, 0.545);       // #64748B
const _kDark2 = PdfColor(0.122, 0.161, 0.216);       // #1F2937
const _kGrey2 = PdfColor(0.420, 0.447, 0.502);       // #6B7280
const _kBorder = PdfColor(0.820, 0.835, 0.859);      // #D1D5DB
const _kRowAlt = PdfColor(0.973, 0.980, 0.992);      // #F8FAFC
const _kBgLight = PdfColor(0.949, 0.953, 0.965);     // #F3F4F6
const _kWhite70 = PdfColor(1, 1, 1, 0.7);

class PdfService {
  // Roboto supports the full Unicode BMP including €, £, ¥ and other symbols
  // that the built-in Helvetica/Type1 fonts cannot render.
  static Future<pw.ThemeData> _theme() async {
    final base   = await PdfGoogleFonts.robotoRegular();
    final bold   = await PdfGoogleFonts.robotoBold();
    final italic = await PdfGoogleFonts.robotoItalic();
    return pw.ThemeData.withFont(base: base, bold: bold, italic: italic);
  }

  static Future<Uint8List> generatePdf(Invoice invoice) async {
    Uint8List? logoBytes;
    if (invoice.businessLogoUrl != null && invoice.businessLogoUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(invoice.businessLogoUrl!));
        if (response.statusCode == 200) {
          logoBytes = response.bodyBytes;
        }
      } catch (_) {}
    }

    switch (invoice.template) {
      case 'classic':
        return _generateClassic(invoice, logoBytes);
      case 'minimal':
        return _generateMinimal(invoice, logoBytes);
      default:
        return _generateModern(invoice, logoBytes);
    }
  }

  static String _currency(Invoice invoice, double amount) =>
      '${invoice.currency}${NumberFormat('#,##0.00').format(amount)}';

  static String _date(DateTime d) => DateFormat('MMM dd, yyyy').format(d);

  // ── Modern Template ────────────────────────────────────────────────────────

  static Future<Uint8List> _generateModern(Invoice invoice, Uint8List? logoBytes) async {
    final doc = pw.Document(theme: await _theme());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(32),
            decoration: const pw.BoxDecoration(
              color: _kPrimary,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoBytes != null)
                      pw.Container(
                        height: 48,
                        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                      ),
                    if (logoBytes != null) pw.SizedBox(height: 8),
                    pw.Text(
                      invoice.businessName,
                      style: pw.TextStyle(
                          color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold),
                    ),
                    if (invoice.businessFormattedAddress.isNotEmpty)
                      pw.Text(invoice.businessFormattedAddress,
                          style: pw.TextStyle(color: _kWhite70, fontSize: 10)),
                    if (invoice.businessPhone.isNotEmpty)
                      pw.Text(invoice.businessPhone,
                          style: pw.TextStyle(color: _kWhite70, fontSize: 10)),
                    pw.Text(invoice.businessEmail,
                        style: pw.TextStyle(color: _kWhite70, fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('INVOICE',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 4)),
                    pw.SizedBox(height: 8),
                    pw.Text(invoice.invoiceNumber,
                        style: pw.TextStyle(color: PdfColors.white, fontSize: 14)),
                    pw.Text('Issued: ${_date(invoice.issueDate)}',
                        style: pw.TextStyle(color: _kWhite70, fontSize: 10)),
                    pw.Text('Due: ${_date(invoice.dueDate)}',
                        style: pw.TextStyle(color: _kWhite70, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // Bill To
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: const pw.BoxDecoration(
                    color: _kLightBlue,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('BILL TO',
                          style: pw.TextStyle(
                              color: _kPrimary, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text(invoice.clientName,
                          style: pw.TextStyle(
                              color: _kDark1, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (invoice.clientCompany.isNotEmpty)
                        pw.Text(invoice.clientCompany,
                            style: pw.TextStyle(color: _kGrey1, fontSize: 11)),
                      if (invoice.clientFormattedAddress.isNotEmpty)
                        pw.Text(invoice.clientFormattedAddress,
                            style: pw.TextStyle(color: _kGrey1, fontSize: 11)),
                      if (invoice.clientEmail.isNotEmpty)
                        pw.Text(invoice.clientEmail,
                            style: pw.TextStyle(color: _kGrey1, fontSize: 11)),
                      if (invoice.clientPhone.isNotEmpty)
                        pw.Text(invoice.clientPhone,
                            style: pw.TextStyle(color: _kGrey1, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: invoice.status == 'paid' ? PdfColors.green700 : _kPrimary,
                      width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('STATUS', style: pw.TextStyle(color: _kGrey1, fontSize: 9)),
                    pw.Text(invoice.status.toUpperCase(),
                        style: pw.TextStyle(
                            color: invoice.status == 'paid' ? PdfColors.green700 : _kPrimary,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // Items table
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(40),
              2: const pw.FixedColumnWidth(70),
              3: const pw.FixedColumnWidth(80),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _kPrimary),
                children: [
                  _mHeaderCell('DESCRIPTION'),
                  _mHeaderCell('QTY'),
                  _mHeaderCell('RATE'),
                  _mHeaderCell('AMOUNT'),
                ],
              ),
              ...invoice.items.asMap().entries.map((e) {
                final isEven = e.key.isEven;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: isEven ? PdfColors.white : _kRowAlt),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(e.value.name,
                              style: pw.TextStyle(
                                  color: _kDark1, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          if (e.value.description.isNotEmpty)
                            pw.Text(e.value.description,
                                style: pw.TextStyle(color: _kGrey1, fontSize: 9)),
                        ],
                      ),
                    ),
                    _mDataCell('${e.value.quantity}'),
                    _mDataCell(_currency(invoice, e.value.unitPrice)),
                    _mDataCell(_currency(invoice, e.value.total)),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 16),

          // Totals
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(
                  children: [
                    _totalRow('Subtotal', _currency(invoice, invoice.subtotal)),
                    if (invoice.taxRate > 0)
                      _totalRow('Tax (${invoice.taxRate.toStringAsFixed(1)}%)',
                          _currency(invoice, invoice.taxAmount)),
                    pw.Divider(color: _kPrimary, thickness: 1.5),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL',
                            style: pw.TextStyle(
                                color: _kDark1, fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.Text(_currency(invoice, invoice.total),
                            style: pw.TextStyle(
                                color: _kPrimary, fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          if (invoice.notes.isNotEmpty || invoice.terms.isNotEmpty)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (invoice.notes.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('NOTES',
                            style: pw.TextStyle(
                                color: _kPrimary, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoice.notes,
                            style: pw.TextStyle(color: _kGrey1, fontSize: 10)),
                      ],
                    ),
                  ),
                if (invoice.notes.isNotEmpty && invoice.terms.isNotEmpty)
                  pw.SizedBox(width: 16),
                if (invoice.terms.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PAYMENT TERMS',
                            style: pw.TextStyle(
                                color: _kPrimary, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoice.terms,
                            style: pw.TextStyle(color: _kGrey1, fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _mHeaderCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: pw.Text(text,
            style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                letterSpacing: 0.5)),
      );

  static pw.Widget _mDataCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: pw.Text(text,
            textAlign: pw.TextAlign.right,
            style: pw.TextStyle(color: _kDark1, fontSize: 11)),
      );

  static pw.Widget _totalRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: pw.TextStyle(color: _kDark1, fontSize: 11)),
            pw.Text(value, style: pw.TextStyle(color: _kGrey1, fontSize: 11)),
          ],
        ),
      );

  // ── Classic Template ───────────────────────────────────────────────────────

  static Future<Uint8List> _generateClassic(Invoice invoice, Uint8List? logoBytes) async {
    final doc = pw.Document(theme: await _theme());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      height: 56,
                      child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                    ),
                  if (logoBytes != null) pw.SizedBox(height: 8),
                  pw.Text(invoice.businessName,
                      style: pw.TextStyle(
                          color: _kDark2, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  if (invoice.businessFormattedAddress.isNotEmpty)
                    pw.Text(invoice.businessFormattedAddress,
                        style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                  if (invoice.businessPhone.isNotEmpty)
                    pw.Text(invoice.businessPhone,
                        style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                  pw.Text(invoice.businessEmail,
                      style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                  if (invoice.businessWebsite.isNotEmpty)
                    pw.Text(invoice.businessWebsite,
                        style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('INVOICE',
                      style: pw.TextStyle(
                          color: _kDark2, fontSize: 32, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: _kBorder)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        _cInfoRow('Invoice #', invoice.invoiceNumber),
                        _cInfoRow('Date', _date(invoice.issueDate)),
                        _cInfoRow('Due Date', _date(invoice.dueDate)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 32),
          pw.Divider(color: _kBorder, thickness: 2),
          pw.SizedBox(height: 16),

          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('BILL TO',
                  style: pw.TextStyle(
                      color: _kGrey2, fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(invoice.clientName,
                  style: pw.TextStyle(
                      color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 13)),
              if (invoice.clientCompany.isNotEmpty)
                pw.Text(invoice.clientCompany,
                    style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
              if (invoice.clientFormattedAddress.isNotEmpty)
                pw.Text(invoice.clientFormattedAddress,
                    style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
              pw.Text(invoice.clientEmail,
                  style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
              if (invoice.clientPhone.isNotEmpty)
                pw.Text(invoice.clientPhone,
                    style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
            ],
          ),

          pw.SizedBox(height: 24),

          pw.Table(
            border: pw.TableBorder.all(color: _kBorder),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(45),
              2: const pw.FixedColumnWidth(75),
              3: const pw.FixedColumnWidth(85),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _kBgLight),
                children: [
                  _cTableCell('Description', isHeader: true),
                  _cTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                  _cTableCell('Unit Price', isHeader: true, align: pw.TextAlign.right),
                  _cTableCell('Amount', isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              ...invoice.items.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.name,
                                style: pw.TextStyle(
                                    color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            if (item.description.isNotEmpty)
                              pw.Text(item.description,
                                  style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                          ],
                        ),
                      ),
                      _cTableCell('${item.quantity}', align: pw.TextAlign.center),
                      _cTableCell(_currency(invoice, item.unitPrice), align: pw.TextAlign.right),
                      _cTableCell(_currency(invoice, item.total), align: pw.TextAlign.right),
                    ],
                  )),
            ],
          ),

          pw.SizedBox(height: 12),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 220,
                decoration: pw.BoxDecoration(border: pw.Border.all(color: _kBorder)),
                child: pw.Column(
                  children: [
                    _cTotalRow('Subtotal', _currency(invoice, invoice.subtotal), isBold: false),
                    if (invoice.taxRate > 0)
                      _cTotalRow(
                          'Tax (${invoice.taxRate.toStringAsFixed(1)}%)',
                          _currency(invoice, invoice.taxAmount),
                          isBold: false),
                    _cTotalRow('TOTAL', _currency(invoice, invoice.total), isBold: true),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          if (invoice.notes.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Notes:',
                    style: pw.TextStyle(
                        color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(invoice.notes, style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
              ],
            ),
          if (invoice.terms.isNotEmpty) pw.SizedBox(height: 8),
          if (invoice.terms.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Payment Terms:',
                    style: pw.TextStyle(
                        color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text(invoice.terms, style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _cInfoRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('$label  ', style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
            pw.Text(value,
                style: pw.TextStyle(color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 10)),
          ],
        ),
      );

  static pw.Widget _cTableCell(String text,
          {bool isHeader = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(
                color: isHeader ? _kDark2 : _kDark2,
                fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
                fontSize: 10)),
      );

  static pw.Widget _cTotalRow(String label, String value, {required bool isBold}) =>
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _kBorder)),
          color: isBold ? _kBgLight : PdfColors.white,
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style: pw.TextStyle(
                    color: _kDark2,
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: 11)),
            pw.Text(value,
                style: pw.TextStyle(
                    color: _kDark2,
                    fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    fontSize: 11)),
          ],
        ),
      );

  // ── Minimal Template ───────────────────────────────────────────────────────

  static Future<Uint8List> _generateMinimal(Invoice invoice, Uint8List? logoBytes) async {
    final doc = pw.Document(theme: await _theme());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logoBytes != null)
                pw.Container(
                  height: 48,
                  child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                )
              else
                pw.Text(invoice.businessName,
                    style: pw.TextStyle(
                        color: _kDark2, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Invoice',
                      style: pw.TextStyle(
                          color: _kPrimary, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(invoice.invoiceNumber,
                      style: pw.TextStyle(color: _kGrey2, fontSize: 12)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 40),

          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('FROM', style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                    pw.SizedBox(height: 6),
                    pw.Text(invoice.businessName,
                        style: pw.TextStyle(
                            color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    if (invoice.businessFormattedAddress.isNotEmpty)
                      pw.Text(invoice.businessFormattedAddress,
                          style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                    pw.Text(invoice.businessEmail,
                        style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TO', style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                    pw.SizedBox(height: 6),
                    pw.Text(invoice.clientName,
                        style: pw.TextStyle(
                            color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    if (invoice.clientCompany.isNotEmpty)
                      pw.Text(invoice.clientCompany,
                          style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                    if (invoice.clientFormattedAddress.isNotEmpty)
                      pw.Text(invoice.clientFormattedAddress,
                          style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                    pw.Text(invoice.clientEmail,
                        style: pw.TextStyle(color: _kGrey2, fontSize: 10)),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('DATE', style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text(_date(invoice.issueDate),
                      style: pw.TextStyle(
                          color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.SizedBox(height: 8),
                  pw.Text('DUE', style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                  pw.SizedBox(height: 4),
                  pw.Text(_date(invoice.dueDate),
                      style: pw.TextStyle(
                          color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 36),
          pw.Divider(color: _kBorder),
          pw.SizedBox(height: 4),

          // Table header
          pw.Row(
            children: [
              pw.Expanded(flex: 4, child: _minHeaderCell('DESCRIPTION')),
              pw.SizedBox(width: 50, child: _minHeaderCell('QTY', align: pw.TextAlign.center)),
              pw.SizedBox(width: 80, child: _minHeaderCell('RATE', align: pw.TextAlign.right)),
              pw.SizedBox(
                  width: 90, child: _minHeaderCell('AMOUNT', align: pw.TextAlign.right)),
            ],
          ),

          pw.Divider(color: _kBorder),

          ...invoice.items.map((item) => pw.Column(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 10),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          flex: 4,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(item.name,
                                  style: pw.TextStyle(
                                      color: _kDark2,
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 11)),
                              if (item.description.isNotEmpty)
                                pw.Text(item.description,
                                    style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                            ],
                          ),
                        ),
                        pw.SizedBox(
                          width: 50,
                          child: pw.Text('${item.quantity}',
                              textAlign: pw.TextAlign.center,
                              style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
                        ),
                        pw.SizedBox(
                          width: 80,
                          child: pw.Text(_currency(invoice, item.unitPrice),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
                        ),
                        pw.SizedBox(
                          width: 90,
                          child: pw.Text(_currency(invoice, item.total),
                              textAlign: pw.TextAlign.right,
                              style: pw.TextStyle(
                                  color: _kDark2, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  pw.Divider(color: _kRowAlt),
                ],
              )),

          pw.SizedBox(height: 12),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 200,
                child: pw.Column(
                  children: [
                    if (invoice.taxRate > 0)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal',
                                style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
                            pw.Text(_currency(invoice, invoice.subtotal),
                                style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
                          ],
                        ),
                      ),
                    if (invoice.taxRate > 0)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Tax (${invoice.taxRate.toStringAsFixed(1)}%)',
                                style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
                            pw.Text(_currency(invoice, invoice.taxAmount),
                                style: pw.TextStyle(color: _kGrey2, fontSize: 11)),
                          ],
                        ),
                      ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: const pw.BoxDecoration(color: _kPrimary),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Total',
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 13)),
                          pw.Text(_currency(invoice, invoice.total),
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (invoice.notes.isNotEmpty || invoice.terms.isNotEmpty) pw.SizedBox(height: 32),

          if (invoice.notes.isNotEmpty)
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Notes', style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.notes,
                          style: pw.TextStyle(color: _kDark2, fontSize: 10)),
                    ],
                  ),
                ),
                if (invoice.terms.isNotEmpty)
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Payment Terms',
                            style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoice.terms,
                            style: pw.TextStyle(color: _kDark2, fontSize: 10)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _minHeaderCell(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 8),
        child: pw.Text(text,
            textAlign: align,
            style: pw.TextStyle(color: _kGrey2, fontSize: 9)),
      );
}
