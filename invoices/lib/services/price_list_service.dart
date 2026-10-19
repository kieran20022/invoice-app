import 'package:intl/intl.dart';
import '../models/business_info.dart';
import '../models/product.dart';

/// The Producten tab's prijslijst, written as Markdown so it can be handed to
/// an AI assistant (or pasted into a chat) as well as read by a person.
///
/// Markdown rather than PDF, CSV or JSON: a PDF's text has to be scraped back
/// out of its layout, CSV cannot carry the category headings without
/// repeating them on every row, and JSON is noisy to read. Headings plus a
/// pipe table are what language models parse most reliably and still render
/// as a readable list anywhere Markdown is shown.
///
/// Every row stands on its own: the price columns name their currency and
/// whether BTW is included, and amounts are plain numbers with a decimal
/// point (`12.10`) — no currency sign or Dutch comma for a reader to misparse.
class PriceListService {
  static String buildMarkdown({
    required BusinessInfo? business,
    required List<({String heading, List<Product> products})> sections,
    required double taxRate,
    DateTime? date,
  }) {
    final name = business?.name ?? '';
    final currency = _currencyCode(business?.currency ?? '€');
    final rate = _number(taxRate, maxDecimals: 2);
    final buf = StringBuffer()
      ..writeln(name.isEmpty ? '# Prijslijst' : '# Prijslijst - ${_inline(name)}')
      ..writeln();

    final meta = <String, String>{
      if (name.isNotEmpty) 'Bedrijf': name,
      if ((business?.formattedAddress ?? '').isNotEmpty)
        'Adres': business!.formattedAddress,
      if ((business?.phone ?? '').isNotEmpty) 'Telefoon': business!.phone,
      if ((business?.website ?? '').isNotEmpty) 'Website': business!.website,
      'Datum': DateFormat('yyyy-MM-dd').format(date ?? DateTime.now()),
      'Valuta': currency,
      'BTW-tarief': '$rate%',
      'Prijzen': 'per eenheid; "excl. BTW" is de kale prijs, '
          '"incl. BTW" is wat de klant betaalt',
    };
    for (final e in meta.entries) {
      buf.writeln('- ${e.key}: ${_inline(e.value)}');
    }

    for (final section in sections) {
      buf.writeln();
      if (section.heading.isNotEmpty) {
        buf
          ..writeln('## ${_inline(section.heading)}')
          ..writeln();
      }
      buf
        ..writeln('| Product | Omschrijving | Eenheid '
            '| Prijs excl. BTW ($currency) | Prijs incl. BTW ($currency) |')
        ..writeln('|---|---|---|---:|---:|');
      for (final p in section.products) {
        buf.writeln('| ${_cell(p.name)} | ${_cell(p.description)} '
            '| ${_cell(p.unit)} '
            '| ${p.price.toStringAsFixed(2)} '
            '| ${(p.price * (1 + taxRate / 100)).toStringAsFixed(2)} |');
      }
    }
    return buf.toString();
  }

  /// ISO code for the symbols the app offers; anything else is kept as typed.
  static String _currencyCode(String symbol) => switch (symbol.trim()) {
        '€' => 'EUR',
        r'$' => 'USD',
        '£' => 'GBP',
        final other => other,
      };

  static String _number(double v, {required int maxDecimals}) {
    final s = v.toStringAsFixed(maxDecimals);
    return s.contains('.')
        ? s.replaceFirst(RegExp(r'\.?0+$'), '')
        : s;
  }

  /// One line of text: newlines would end a list item or heading early.
  static String _inline(String s) =>
      s.replaceAll(RegExp(r'\s*\n\s*'), ', ').trim();

  /// A table cell: a `|` would open a new column.
  static String _cell(String s) => _inline(s).replaceAll('|', r'\|');
}
