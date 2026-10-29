import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/product.dart';
import 'package:invoices/services/purchase_import_service.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('reads the product lines out of a real PDF table', () async {
    final doc = pw.Document()
      ..addPage(pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Onderdelenshop B.V.'),
            pw.Text('Factuurnummer: 2026-1042'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Aantal', 'Omschrijving', 'Prijs', 'Totaal'],
              data: [
                ['2', 'Remblokken voor Bosch', 'EUR 24,95', 'EUR 49,90'],
                ['4', 'Bougie NGK BKR6E', 'EUR 3,50', 'EUR 14,00'],
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Text('Totaal incl. BTW: EUR 77,32'),
          ],
        ),
      ));
    final rows = pdfRows(await doc.save());
    final lines = parsePurchaseRows(rows);
    expect(lines.map((l) => (l.description, l.quantity)), [
      ('Remblokken voor Bosch', 2),
      ('Bougie NGK BKR6E', 4),
    ]);
  });

  group('parseInvoiceNumber', () {
    test('reads either decimal separator and thousands', () {
      expect(parseInvoiceNumber('12,34'), 12.34);
      expect(parseInvoiceNumber('12.34'), 12.34);
      expect(parseInvoiceNumber('1.234,56'), 1234.56);
      expect(parseInvoiceNumber('1,234.56'), 1234.56);
      expect(parseInvoiceNumber('€24,95'), 24.95);
    });
  });

  group('parsePurchaseRows', () {
    test('a table with a leading quantity column', () {
      final lines = parsePurchaseRows([
        'Factuur\tFactuurnummer 2026-1042',
        'Aantal\tOmschrijving\tPrijs\tTotaal',
        '2\tRemblokken voor Bosch\t€ 24,95\t€ 49,90',
        '4\tBougie NGK BKR6E\t€ 3,50\t€ 14,00',
        'Subtotaal\t€ 63,90',
        'Verzendkosten\t€ 6,95',
        'BTW 21%\t€ 13,42',
        'Totaal\t€ 84,27',
      ]);
      expect(lines, hasLength(2));
      expect(lines[0].description, 'Remblokken voor Bosch');
      expect(lines[0].quantity, 2);
      expect(lines[0].unitPrice, 24.95);
      expect(lines[1].quantity, 4);
      expect(lines[1].codes, contains('BKR6E'));
    });

    test('quantity found from unit price times total, anywhere on the row',
        () {
      final lines = parsePurchaseRows([
        'Motorolie 5W30 5 liter\t3\t€ 32,50\t21%\t€ 97,50',
      ]);
      expect(lines.single.quantity, 3);
      expect(lines.single.unitPrice, 32.5);
    });

    test('spelled-out quantities', () {
      expect(parsePurchaseRows(['Ruitenwisser 2x € 9,99']).single.quantity, 2);
      expect(
        parsePurchaseRows(['Ruitenwisser\t3 stuks\t€ 29,97']).single.quantity,
        3,
      );
      expect(
        parsePurchaseRows(['Ruitenwisser Aantal: 5 € 49,95']).single.quantity,
        5,
      );
      expect(
        parsePurchaseRows(['Ruitenwisser 9,99 x 2 19,98']).single.quantity,
        2,
      );
    });

    test('quantity printed with decimals', () {
      final line =
          parsePurchaseRows(['2,00\tOliefilter Mann\t8,25\t16,50']).single;
      expect(line.quantity, 2);
    });

    test('no quantity anywhere defaults to 1', () {
      expect(parsePurchaseRows(['Accu Varta 60Ah\t€ 89,00']).single.quantity, 1);
    });

    test('description on the row above, article number below', () {
      final lines = parsePurchaseRows([
        'Luchtfilter Bosch',
        '1\t€ 12,10\t€ 12,10',
        'Artikelnr. F026400123',
      ]);
      expect(lines.single.description, 'Luchtfilter Bosch');
      expect(lines.single.codes, contains('F026400123'));
    });
  });

  group('matching', () {
    const brakes = Product(id: 'b', name: 'Remblokken Bosch', price: 20);
    const plugs = Product(
      id: 'p',
      name: 'Bougie',
      description: 'NGK BKR-6E',
      price: 3,
    );
    const oil = Product(id: 'o', name: 'Motorolie 5W30', price: 30);
    const products = [brakes, plugs, oil];

    PurchaseLine line(String description, {List<String> codes = const []}) =>
        PurchaseLine(
          text: description,
          description: description,
          quantity: 1,
          codes: codes,
        );

    test('by words', () {
      final ranked = rankProducts(line('Remblokken voor Bosch'), products);
      expect(ranked.first.product.id, 'b');
      expect(ranked.first.score, greaterThan(matchThreshold));
    });

    test('by article code, ignoring dashes', () {
      final ranked = rankProducts(
        line('Spark plug iridium BKR6E', codes: ['BKR6E']),
        products,
      );
      expect(ranked.first.product.id, 'p');
      expect(ranked.first.score, greaterThanOrEqualTo(0.95));
    });

    test('sizes and grades only match exactly', () {
      final ranked = rankProducts(line('Motorolie 10W40'), products);
      expect(ranked.first.product.id, 'o');
      expect(ranked.first.score, lessThan(0.85));
    });

    test('an unrelated line matches nothing', () {
      final ranked = rankProducts(line('Werkhandschoenen nitril'), products);
      expect(ranked.first.score, lessThan(matchThreshold));
    });

    test('remembered supplier wording matches outright', () {
      final known = Product(
        id: 'k',
        name: 'Remschijf voor',
        price: 40,
        supplierNames: [normalizeSupplierText('BR-DSC 280mm Vented')],
      );
      expect(matchScore(line('BR-DSC 280mm vented'), known), 1);
    });
  });
}
