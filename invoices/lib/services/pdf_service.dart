import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/invoice.dart';

const _kDark = PdfColor(0.122, 0.161, 0.216);
const _kGrey = PdfColor(0.420, 0.447, 0.502);
const _kBorder = PdfColor(0.820, 0.835, 0.859);
const _kBgLight = PdfColor(0.949, 0.953, 0.965);
const _kPaid = PdfColor(0.063, 0.725, 0.506); // #10B981
const _kUnpaid = PdfColor(0.937, 0.267, 0.267); // #EF4444
const _kQuote = PdfColor(0.146, 0.388, 0.922); // #2563EB

class PdfService {
  static Future<pw.ThemeData> _theme() async {
    final base = await PdfGoogleFonts.robotoRegular();
    final bold = await PdfGoogleFonts.robotoBold();
    final italic = await PdfGoogleFonts.robotoItalic();
    return pw.ThemeData.withFont(base: base, bold: bold, italic: italic);
  }

  static String _fmt(Invoice inv, double amount) =>
      '${inv.currency}${NumberFormat('#,##0.00').format(amount)}'.replaceAll(
        '.',
        ',',
      );

  static String _date(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  /// A total as a span when the document estimates ranges, otherwise plain.
  static String _fmtRange(Invoice inv, double min, double max) =>
      max > min ? '${_fmt(inv, min)} - ${_fmt(inv, max)}' : _fmt(inv, min);

  static Future<Uint8List> generatePdf(
    Invoice invoice, {
    Uint8List? logoBytes,
  }) async {
    final doc = pw.Document(theme: await _theme());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => [
          // ── Header ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoBytes != null)
                    pw.Container(
                      height: 60,
                      child: pw.Image(
                        pw.MemoryImage(logoBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  if (logoBytes != null) pw.SizedBox(height: 8),
                  pw.Text(
                    invoice.businessName,
                    style: pw.TextStyle(
                      color: _kDark,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (invoice.businessFormattedAddress.isNotEmpty)
                        pw.Text(
                          invoice.businessFormattedAddress,
                          style: pw.TextStyle(color: _kGrey, fontSize: 10),
                        ),
                      if (invoice.businessFormattedAddress.isNotEmpty)
                        pw.SizedBox(width: 24),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          if (invoice.businessWebsite.isNotEmpty)
                            pw.Text(
                              invoice.businessWebsite,
                              style: pw.TextStyle(color: _kGrey, fontSize: 10),
                            ),
                          if (invoice.businessPhone.isNotEmpty)
                            pw.Text(
                              invoice.businessPhone,
                              style: pw.TextStyle(color: _kGrey, fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    invoice.documentLabel.toUpperCase(),
                    style: pw.TextStyle(
                      color: _kDark,
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _kBorder),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        // A quote is identified by its subject, not by a
                        // sequence number, so it prints only the date.
                        if (!invoice.isQuote)
                          _infoRow('Factuurnummer', invoice.numberLabel),
                        _infoRow('Datum', _date(invoice.issueDate)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _statusBadge(invoice),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── KvK & IBAN ──────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              pw.Text(
                invoice.businessKvk.isNotEmpty
                    ? 'KvK: ${invoice.businessKvk}'
                    : '',
                style: pw.TextStyle(color: _kGrey, fontSize: 10),
              ),
              // pw.Text(
              //   invoice.businessIban.isNotEmpty
              //       ? 'IBAN: ${invoice.businessIban}'
              //       : '',
              //   style: pw.TextStyle(color: _kGrey, fontSize: 10),
              // ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Divider(color: _kBorder, thickness: 1.5),
          pw.SizedBox(height: 16),

          // ── Klantgegevens ────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'KLANTGEGEVENS',
                    style: pw.TextStyle(
                      color: _kGrey,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    invoice.clientNaam,
                    style: pw.TextStyle(
                      color: _kDark,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  if (invoice.clientKenteken.isNotEmpty)
                    _clientRow('Kenteken', invoice.clientKenteken)
                  else if (invoice.clientProductType.isNotEmpty)
                    _clientRow('Type', invoice.clientProductType),
                  _clientRow('Km-stand', invoice.clientKmstand),
                  _clientRow('Datum', invoice.clientDatum),
                  if (invoice.clientAdres.isNotEmpty)
                    _clientRow('Adres', invoice.clientAdres),
                  if (invoice.clientTelefoonnummer.isNotEmpty)
                    _clientRow('Tel.', invoice.clientTelefoonnummer),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),

          // ── Regels tabel ─────────────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(color: _kBorder),
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FixedColumnWidth(70),
              2: const pw.FixedColumnWidth(90),
              3: const pw.FixedColumnWidth(90),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _kBgLight),
                children: [
                  _th('Omschrijving'),
                  _th('Aantal', align: pw.TextAlign.center),
                  _th('Prijs ex. BTW', align: pw.TextAlign.right),
                  _th('Prijs incl. BTW', align: pw.TextAlign.right),
                ],
              ),
              ...invoice.items.map(
                (item) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: pw.Text(
                        item.omschrijving,
                        style: pw.TextStyle(color: _kDark, fontSize: 11),
                      ),
                    ),
                    _td(item.aantalLabel, align: pw.TextAlign.center),
                    _td(
                      _fmt(invoice, item.prijsExBtw),
                      align: pw.TextAlign.right,
                    ),
                    _td(
                      _fmt(invoice, item.prijsInclBtw(invoice.taxRate)),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),

          // ── Totalen ──────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 240,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _kBorder),
                ),
                child: pw.Column(
                  children: [
                    _totalRow(
                      'Subtotaal ex. BTW',
                      _fmtRange(
                        invoice,
                        invoice.subtotaalExBtw,
                        invoice.subtotaalExBtwMax,
                      ),
                      isBold: false,
                    ),
                    _totalRow(
                      'BTW ${invoice.taxRate.toStringAsFixed(0)}%',
                      _fmtRange(
                        invoice,
                        invoice.btwBedrag,
                        invoice.btwBedragMax,
                      ),
                      isBold: false,
                    ),
                    _totalRow(
                      'Totaal incl. BTW',
                      _fmtRange(
                        invoice,
                        invoice.totaalInclBtw,
                        invoice.totaalInclBtwMax,
                      ),
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // ── Betalingsgegevens ─────────────────────────────────────────────
          if (invoice.businessIban.isNotEmpty && !invoice.isQuote)
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: _kBgLight,
                border: pw.Border.all(color: _kBorder),
              ),
              child: pw.Row(
                children: [
                  pw.Text(
                    'Betalingsgegevens:  ',
                    style: pw.TextStyle(
                      color: _kGrey,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'IBAN: ${invoice.businessIban}',
                    style: pw.TextStyle(color: _kDark, fontSize: 10),
                  ),
                ],
              ),
            ),

          if (!invoice.isQuote) pw.SizedBox(height: 24),

          // ── Opmerkingen ──────────────────────────────────────────────────
          // Invoices only: a quote states what the work would cost, and the
          // notes field is kept for the app's own reference.
          if (!invoice.isQuote)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Opmerkingen',
                  style: pw.TextStyle(
                    color: _kGrey,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice.notes.isNotEmpty ? invoice.notes : 'Geen opmerkingen',
                  style: pw.TextStyle(color: _kDark, fontSize: 10),
                ),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  static String get businessFormattedAddressExtension => '';

  static pw.Widget _infoRow(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.end,
      children: [
        pw.Text('$label:  ', style: pw.TextStyle(color: _kGrey, fontSize: 10)),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _kDark,
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ],
    ),
  );

  /// Payment state, shown right under the invoice number / date block. A quote
  /// is not owed yet, so it says what it is instead.
  static pw.Widget _statusBadge(Invoice invoice) {
    final isPaid = invoice.status == 'betaald';
    final color = invoice.isQuote
        ? _kQuote
        : isPaid
            ? _kPaid
            : _kUnpaid;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: color)),
      child: pw.Text(
        invoice.isQuote
            ? invoice.documentLabel.toUpperCase()
            : isPaid
                ? 'BETAALD'
                : 'TE BETALEN',
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  static pw.Widget _clientRow(String label, String value) => value.isEmpty
      ? pw.SizedBox()
      : pw.Text(
          '$label: $value',
          style: pw.TextStyle(color: _kGrey, fontSize: 10),
        );

  static pw.Widget _th(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            color: _kDark,
            fontWeight: pw.FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );

  static pw.Widget _td(String text, {pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(color: _kDark, fontSize: 10),
        ),
      );

  static pw.Widget _totalRow(
    String label,
    String value, {
    required bool isBold,
  }) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _kBorder)),
      color: isBold ? _kBgLight : PdfColors.white,
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            color: _kDark,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 11,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            color: _kDark,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );

}

extension _InvoiceAddr on Invoice {
  String get businessFormattedAddress {
    final parts = [
      businessAddress,
      "$businessZip, $businessCity",
      businessState,
    ].where((s) => s.isNotEmpty).toList();
    return parts.join('\n');
  }
}
