import '../models/product.dart';

/// The Producten tab's prijslijst, written as CSV so it can be handed to an
/// AI assistant as plain data (and opened in a spreadsheet as well).
///
/// One flat table, one row per product: the category and sub-category are
/// columns rather than headings, so every row stands on its own. The price
/// columns name their currency and whether BTW is included, and amounts are
/// plain numbers with a decimal point (`12.10`) — no currency sign or Dutch
/// comma to misparse. Written as RFC 4180: comma-separated, CRLF line ends,
/// a field quoted when it holds a comma, quote or line break.
class PriceListService {
  static const _header = [
    'Categorie',
    'Subcategorie',
    'Product',
    'Omschrijving',
    'Eenheid',
    'Prijs excl. BTW',
    'BTW %',
    'Prijs incl. BTW',
  ];

  static String buildCsv({
    required List<({String category, String subCategory, List<Product> products})>
        sections,
    required double taxRate,
    required String currency,
  }) {
    final code = _currencyCode(currency);
    final rate = _number(taxRate);
    final rows = <List<String>>[
      [
        for (final h in _header)
          h.startsWith('Prijs') ? '$h ($code)' : h,
      ],
      for (final s in sections)
        for (final p in s.products)
          [
            s.category,
            s.subCategory,
            p.name,
            p.description,
            p.unit,
            p.price.toStringAsFixed(2),
            rate,
            (p.price * (1 + taxRate / 100)).toStringAsFixed(2),
          ],
    ];
    return [for (final r in rows) '${r.map(_field).join(',')}\r\n'].join();
  }

  /// ISO code for the symbols the app offers; anything else is kept as typed.
  static String _currencyCode(String symbol) => switch (symbol.trim()) {
        '€' => 'EUR',
        r'$' => 'USD',
        '£' => 'GBP',
        final other => other,
      };

  /// 21 → "21", 9.5 → "9.5".
  static String _number(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  static String _field(String s) => s.contains(RegExp('[",\r\n]'))
      ? '"${s.replaceAll('"', '""')}"'
      : s;
}
