import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/invoice.dart';
import 'package:invoices/services/excel_service.dart';

Invoice _invoice({
  required String number,
  required DateTime date,
  required double price,
  double qty = 1,
  String status = Invoice.paidCash,
  bool isQuote = false,
  DateTime? paidAt,
  String kmstand = '',
}) =>
    Invoice(
      id: number,
      invoiceNumber: number,
      issueDate: date,
      clientNaam: 'Jan',
      clientKenteken: 'AB-12-CD',
      clientKmstand: kmstand,
      businessName: 'Bromfix',
      items: [
        InvoiceItem(
          id: '1',
          omschrijving: 'Reparatie',
          aantal: qty,
          prijsExBtw: price,
        ),
      ],
      status: status,
      paidAt: paidAt,
      createdAt: date,
      isQuote: isQuote,
    );

String _sheetOf(List<Invoice> invoices, int year) {
  final bytes = ExcelService.build(
    invoices: invoices,
    year: year,
    businessName: 'Bromfix',
  );
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.files.firstWhere(
    (f) => f.name == 'xl/worksheets/sheet1.xml',
  );
  return String.fromCharCodes(file.content as List<int>);
}

/// The row numbers in the sheet, in the order they are written.
List<int> _rowOrder(String sheet) => RegExp(r'<row r="(\d+)"')
    .allMatches(sheet)
    .map((m) => int.parse(m[1]!))
    .toList();

void main() {
  group('Inkomsten overzicht', () {
    test('counts an invoice on the day it was paid, not the day it was '
        'written', () {
      final rows = ExcelService.invoicesForYear([
        // Written in December, paid in January: it is January's income.
        _invoice(
          number: 'F1',
          date: DateTime(2024, 12, 28),
          price: 50,
          paidAt: DateTime(2025, 1, 6),
        ),
        _invoice(
          number: 'F2',
          date: DateTime(2025, 1, 2),
          price: 50,
          paidAt: DateTime(2025, 1, 2),
        ),
      ], 2025);

      expect(rows.map((i) => i.invoiceNumber), ['F2', 'F1']);
      expect(ExcelService.invoicesForYear([
        _invoice(
          number: 'F1',
          date: DateTime(2024, 12, 28),
          price: 50,
          paidAt: DateTime(2025, 1, 6),
        ),
      ], 2024), isEmpty);
    });

    test('orders by number within one day, by sequence not by text', () {
      final paid = DateTime(2025, 5, 4);
      final rows = ExcelService.invoicesForYear([
        _invoice(number: 'F10', date: paid, price: 1, paidAt: paid),
        _invoice(number: 'F9', date: paid, price: 1, paidAt: paid),
        _invoice(number: 'F2', date: paid, price: 1, paidAt: paid),
      ], 2025);

      expect(rows.map((i) => i.invoiceNumber), ['F2', 'F9', 'F10']);
    });

    test('an open invoice is left out — it is not income yet', () {
      final rows = ExcelService.invoicesForYear([
        _invoice(number: 'F1', date: DateTime(2025, 7, 1), price: 50),
        _invoice(
          number: 'F2',
          date: DateTime(2025, 7, 2),
          price: 50,
          status: 'concept',
        ),
      ], 2025);

      expect(rows.map((i) => i.invoiceNumber), ['F1']);
    });

    test('an invoice paid before the stamp existed falls back to its issue '
        'date', () {
      // The older 'betaald' state carries no paidAt, but still counts.
      final rows = ExcelService.invoicesForYear([
        _invoice(
          number: 'F1',
          date: DateTime(2025, 7, 1),
          price: 50,
          status: 'betaald',
        ),
      ], 2025);

      expect(rows.single.paymentDate, DateTime(2025, 7, 1));
    });

    test('the KM stand column carries the vehicle reading', () {
      final sheet = _sheetOf(
        [
          _invoice(
            number: 'F1',
            date: DateTime(2025, 3, 4),
            price: 100,
            kmstand: '24500',
          ),
        ],
        2025,
      );

      expect(sheet, contains('<is><t xml:space="preserve">KM Stand</t></is>'));
      expect(
        sheet,
        contains('<c r="E3" s="3" t="inlineStr">'
            '<is><t xml:space="preserve">24500</t></is></c>'),
      );
      // Nothing in the file says Openstaand any more.
      expect(sheet, isNot(contains('Openstaand')));
    });

    test('the sheet dates a row on its payment date', () {
      final sheet = _sheetOf(
        [
          _invoice(
            number: 'F1',
            date: DateTime(2025, 3, 4),
            price: 100,
            paidAt: DateTime(2025, 4, 2),
          ),
        ],
        2025,
      );

      // 2 April 2025, not 4 March (45720) — and so it counts towards Q2.
      expect(sheet, contains('<c r="B3" s="5"><v>45749</v></c>'));
    });

    test('lists the invoices of the year, oldest first', () {
      final rows = ExcelService.invoicesForYear([
        _invoice(number: 'F2', date: DateTime(2025, 6, 1), price: 100),
        _invoice(number: 'F1', date: DateTime(2025, 1, 5), price: 50),
        _invoice(number: 'F0', date: DateTime(2024, 12, 31), price: 10),
      ], 2025);

      expect(rows.map((i) => i.invoiceNumber), ['F1', 'F2']);
    });

    test('leaves quotes out', () {
      final rows = ExcelService.invoicesForYear([
        _invoice(number: 'F1', date: DateTime(2025, 1, 5), price: 50),
        _invoice(
          number: 'OFF-1',
          date: DateTime(2025, 2, 5),
          price: 50,
          isQuote: true,
        ),
      ], 2025);

      expect(rows.map((i) => i.invoiceNumber), ['F1']);
    });

    test('writes a row per invoice with its VAT split', () {
      final sheet = _sheetOf(
        [_invoice(number: 'F1', date: DateTime(2025, 3, 4), price: 100)],
        2025,
      );

      // Row 3 is the first data row: number, date serial, amounts.
      expect(sheet, contains('<is><t xml:space="preserve">F1</t></is>'));
      expect(sheet, contains('<c r="B3" s="5"><v>45720</v></c>'));
      expect(sheet, contains('<c r="F3" s="4"><v>100.0</v></c>'));
      expect(sheet, contains('<c r="H3" s="4"><v>21.0</v></c>'));
      expect(sheet, contains('<c r="I3" s="4"><v>121.0</v></c>'));
    });

    test('quarters sum the list by date, with a running cumulative', () {
      final sheet = _sheetOf(
        [
          _invoice(number: 'F1', date: DateTime(2025, 2, 1), price: 100),
          _invoice(number: 'F2', date: DateTime(2025, 5, 1), price: 200),
        ],
        2025,
      );

      // Q1 runs from 1 January (45658) up to, but not including, 1 April
      // (45748) — a day count that must not slip when summer time starts.
      expect(
        sheet,
        contains('SUMIFS(\$F\$3:\$F\$4,\$B\$3:\$B\$4,&quot;&gt;=&quot;&amp;45658,'
            '\$B\$3:\$B\$4,&quot;&lt;&quot;&amp;45748)'),
      );
      // Q2's cumulative adds the quarters above it.
      expect(sheet, contains('<c r="Q4" s="12"><f>SUM(\$M\$3:M4)</f></c>'));
      // The year row totals the four quarters.
      expect(sheet, contains('<f>SUM(M3:M6)</f>'));
    });

    test('rows are written in ascending order on a short year', () {
      // One invoice puts the totals row (4) in the middle of the quarter
      // block (3-7); Excel rejects a sheet whose rows are out of order.
      final sheet = _sheetOf(
        [_invoice(number: 'F1', date: DateTime(2025, 2, 1), price: 100)],
        2025,
      );
      final order = _rowOrder(sheet);

      expect(order, [1, 2, 3, 4, 5, 6, 7]);
      expect(order, List.of(order)..sort());
    });

    test('an empty year still produces a workbook', () {
      final sheet = _sheetOf([], 2025);

      expect(_rowOrder(sheet), [1, 2, 3, 4, 5, 6, 7]);
      expect(sheet, contains('0 facturen'));
    });

    test('filename carries the business and the year', () {
      expect(ExcelService.filename(2025, 'Bromfix'), 'Inkomsten Bromfix 2025.xlsx');
      expect(ExcelService.filename(2025, ''), 'Inkomsten 2025.xlsx');
    });

    test('the current year is offered even when it has no invoices', () {
      final years = ExcelService.availableYears([
        _invoice(number: 'F1', date: DateTime(2023, 2, 1), price: 100),
      ]);

      expect(years.first, DateTime.now().year);
      expect(years, contains(2023));
    });
  });
}
