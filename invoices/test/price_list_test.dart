import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/business_info.dart';
import 'package:invoices/models/product.dart';
import 'package:invoices/services/price_list_service.dart';

void main() {
  String build(
    List<({String heading, List<Product> products})> sections, {
    BusinessInfo? business,
  }) =>
      PriceListService.buildMarkdown(
        business: business,
        sections: sections,
        taxRate: 21,
        date: DateTime(2026, 10, 19),
      );

  test('lists each section as a heading over a table with both prices', () {
    final md = build(
      [
        (
          heading: 'Banden › Winter',
          products: const [
            Product(id: '1', name: 'Winterband', price: 10, unit: 'stuk'),
          ],
        ),
      ],
      business: const BusinessInfo(id: 'b', name: 'Garage Jan'),
    );
    expect(md, startsWith('# Prijslijst - Garage Jan\n'));
    expect(md, contains('- Datum: 2026-10-19\n'));
    expect(md, contains('- Valuta: EUR\n'));
    expect(md, contains('- BTW-tarief: 21%\n'));
    expect(md, contains('## Banden › Winter\n'));
    expect(
      md,
      contains('| Product | Omschrijving | Eenheid '
          '| Prijs excl. BTW (EUR) | Prijs incl. BTW (EUR) |'),
    );
    expect(md, contains('| Winterband |  | stuk | 10.00 | 12.10 |'));
  });

  test('a section without a heading gets no heading line', () {
    final md = build([
      (
        heading: '',
        products: const [Product(id: '1', name: 'Olie', price: 5)],
      ),
    ]);
    expect(md, isNot(contains('##')));
    expect(md, contains('| Olie |'));
  });

  test('pipes and newlines cannot break the table', () {
    final md = build([
      (
        heading: '',
        products: const [
          Product(
            id: '1',
            name: 'A | B',
            description: 'regel een\nregel twee',
            price: 1,
          ),
        ],
      ),
    ]);
    expect(md, contains(r'| A \| B | regel een, regel twee |'));
  });
}
