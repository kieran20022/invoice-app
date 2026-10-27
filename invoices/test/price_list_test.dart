import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/product.dart';
import 'package:invoices/services/price_list_service.dart';

void main() {
  String build(
    List<({String category, String subCategory, List<Product> products})>
        sections,
  ) =>
      PriceListService.buildCsv(
        sections: sections,
        taxRate: 21,
        currency: '€',
      );

  test('one header row, then one row per product with both prices', () {
    final csv = build([
      (
        category: 'Banden',
        subCategory: 'Winter',
        products: const [
          Product(id: '1', name: 'Winterband', price: 10, unit: 'stuk'),
        ],
      ),
      (
        category: '',
        subCategory: '',
        products: const [Product(id: '2', name: 'Olie', price: 5)],
      ),
    ]);
    expect(
      csv.split('\r\n'),
      [
        'Categorie,Subcategorie,Product,Omschrijving,Eenheid,'
            'Prijs excl. BTW (EUR),BTW %,Prijs incl. BTW (EUR)',
        'Banden,Winter,Winterband,,stuk,10.00,21,12.10',
        ',,Olie,,item,5.00,21,6.05',
        '',
      ],
    );
  });

  test('commas, quotes and line breaks are quoted', () {
    final csv = build([
      (
        category: '',
        subCategory: '',
        products: const [
          Product(
            id: '1',
            name: 'Band 205/55, R16',
            description: 'De "beste"\nkeuze',
            price: 1,
          ),
        ],
      ),
    ]);
    expect(
      csv,
      contains('"Band 205/55, R16","De ""beste""\nkeuze",item,1.00,21,1.21'),
    );
  });
}
