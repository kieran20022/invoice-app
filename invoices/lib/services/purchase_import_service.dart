import 'dart:typed_data';

import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/product.dart';

/// Reads a supplier's invoice (a webshop order as PDF) and matches its lines
/// to the products in the Voorraad. Entirely rule-based: the PDF's text is
/// laid out in rows, each row is read for a quantity, prices and a
/// description, and descriptions are compared to product names by their
/// words and article codes. Confirmed matches are remembered on the product
/// ([Product.supplierNames]), so the next invoice from the same shop matches
/// on the exact wording.

/// One product line read off a supplier invoice.
class PurchaseLine {
  /// The row as it appeared in the PDF, for showing next to the match.
  final String text;

  /// The words of the row that describe the product — the row without its
  /// quantity, prices and VAT.
  final String description;
  final double quantity;

  /// Price per piece, when the row shows it next to the line total.
  final double? unitPrice;

  /// Article numbers and other letter/digit codes on the row (and on a
  /// detail row under it), which identify a product more surely than words.
  final List<String> codes;

  const PurchaseLine({
    required this.text,
    required this.description,
    required this.quantity,
    this.unitPrice,
    this.codes = const [],
  });
}

// ── PDF → rows ───────────────────────────────────────────────────────────────

/// The PDF's text as rows, top to bottom, page after page. Words sharing a
/// baseline form one row whatever text object they were drawn in, so a
/// table row comes out as one row; a wide gap between words (a column
/// break) is kept as a tab.
///
/// Top-level so it can run through `compute`.
List<String> pdfRows(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    final words = <({int page, double left, double right, double top,
        double bottom, String text})>[];
    for (final line in PdfTextExtractor(document).extractTextLines()) {
      for (final w in line.wordCollection) {
        final text = w.text.trim();
        if (text.isEmpty) continue;
        words.add((
          page: line.pageIndex,
          left: w.bounds.left,
          right: w.bounds.right,
          top: w.bounds.top,
          bottom: w.bounds.bottom,
          text: text,
        ));
      }
    }
    words.sort((a, b) {
      final byPage = a.page.compareTo(b.page);
      if (byPage != 0) return byPage;
      return ((a.top + a.bottom) / 2).compareTo((b.top + b.bottom) / 2);
    });

    // Cluster into rows: a word belongs to the row when its middle lies
    // within half a line height of the row's.
    final rows = <List<({double left, double right, double height,
        String text})>>[];
    int? rowPage;
    double rowMid = 0;
    for (final w in words) {
      final mid = (w.top + w.bottom) / 2;
      final height = (w.bottom - w.top).abs().clamp(1.0, 1000.0);
      if (rows.isEmpty || w.page != rowPage || (mid - rowMid).abs() >
          height / 2) {
        rows.add([]);
        rowPage = w.page;
        rowMid = mid;
      }
      rows.last.add(
          (left: w.left, right: w.right, height: height, text: w.text));
    }

    return [
      for (final row in rows)
        () {
          row.sort((a, b) => a.left.compareTo(b.left));
          final out = StringBuffer(row.first.text);
          for (var i = 1; i < row.length; i++) {
            final prev = row[i - 1];
            final gap = row[i].left - prev.right;
            // A gap wider than about two characters is a column break.
            out.write(gap > prev.height * 1.2 ? '\t' : ' ');
            out.write(row[i].text);
          }
          return out.toString();
        }(),
    ];
  } finally {
    document.dispose();
  }
}

// ── Rows → product lines ─────────────────────────────────────────────────────

/// Words that mark a row as bookkeeping (totals, shipping, payment, the
/// invoice's own details) rather than something delivered.
const _skipWords = {
  'totaal', 'subtotaal', 'total', 'subtotal', 'totaalbedrag', 'eindtotaal',
  'btw', 'vat', 'tax', 'belasting', 'verzendkosten', 'verzending',
  'verzenden', 'shipping', 'bezorgkosten', 'bezorging', 'levering',
  'leveringskosten', 'transportkosten', 'handlingkosten', 'administratiekosten',
  'korting', 'discount', 'kortingscode', 'voucher', 'cadeaubon',
  'iban', 'bic', 'kvk', 'betaald', 'betaling', 'betaalwijze', 'payment',
  'factuurnummer', 'factuurdatum', 'ordernummer', 'bestelnummer',
  'klantnummer', 'orderdatum', 'besteldatum', 'vervaldatum', 'invoice',
  'saldo', 'openstaand', 'te', 'statiegeld', 'rembours',
};

/// Words that only say "pieces" — after a number they make it the quantity.
const _unitWords = {
  'x', '×', 'st', 'st.', 'stk', 'stk.', 'stuk', 'stuks', 'pcs', 'pc', 'pce',
  'piece', 'pieces', 'stück', 'ea',
};

const _quantityLabels = {'aantal', 'aantal:', 'aant', 'aant.', 'qty', 'qty:',
    'quantity', 'quantity:', 'hoeveelheid'};

final _moneyPattern = RegExp(r'^-?\d{1,3}(?:[.,]\d{3})*[.,]\d{2}$|^-?\d+[.,]\d{2}$');
final _intPattern = RegExp(r'^\d+$');
final _gluedQuantity = RegExp(
    r'^(\d+)(?:x|×|st|st\.|stk|stuks?|pcs)$|^[x×](\d+)$',
    caseSensitive: false);
final _letter = RegExp(r'[a-zA-ZÀ-ÿ]');
final _digit = RegExp(r'\d');

/// A number as an invoice prints it: `12,34`, `12.34`, `1.234,56` or
/// `1,234.56`. The last separator is the decimal one.
double? parseInvoiceNumber(String token) {
  var t = token.replaceAll('€', '').trim();
  if (t.isEmpty) return null;
  final lastSep = t.lastIndexOf(RegExp(r'[.,]'));
  if (lastSep == -1) return double.tryParse(t);
  final whole = t.substring(0, lastSep).replaceAll(RegExp(r'[.,]'), '');
  return double.tryParse('$whole.${t.substring(lastSep + 1)}');
}

enum _Kind { money, integer, quantity, percent, unit, text }

class _Token {
  final String text;
  final int column;
  _Kind kind;
  double? value;
  _Token(this.text, this.column, this.kind, [this.value]);
}

List<_Token> _tokenize(String row) {
  final tokens = <_Token>[];
  final columns = row
      // Pull currency signs off the amounts they are glued to.
      .replaceAll('€', ' € ')
      .replaceAll(RegExp(r'\bEUR\b'), ' € ')
      .split('\t');
  for (var c = 0; c < columns.length; c++) {
    for (final raw in columns[c].split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      final lower = raw.toLowerCase();
      final glued = _gluedQuantity.firstMatch(lower);
      if (raw == '€') {
        tokens.add(_Token(raw, c, _Kind.unit));
      } else if (raw.endsWith('%') || raw == '%') {
        tokens.add(_Token(raw, c, _Kind.percent));
      } else if (_moneyPattern.hasMatch(raw)) {
        tokens.add(_Token(raw, c, _Kind.money, parseInvoiceNumber(raw)));
      } else if (_intPattern.hasMatch(raw)) {
        tokens.add(_Token(raw, c, _Kind.integer, double.parse(raw)));
      } else if (glued != null) {
        tokens.add(_Token(raw, c, _Kind.quantity,
            double.parse(glued.group(1) ?? glued.group(2)!)));
      } else if (_unitWords.contains(lower)) {
        tokens.add(_Token(raw, c, _Kind.unit));
      } else {
        tokens.add(_Token(raw, c, _Kind.text));
      }
    }
  }

  // Context: a number right after € is an amount, before % a VAT rate,
  // and around "x" / "stuks" or after "Aantal" a quantity.
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    final prev = i > 0 ? tokens[i - 1] : null;
    final next = i + 1 < tokens.length ? tokens[i + 1] : null;
    if (t.kind != _Kind.integer && t.kind != _Kind.money) continue;
    if (prev?.text == '€' && t.kind == _Kind.integer) {
      t.kind = _Kind.money;
    } else if (next?.text == '%') {
      t.kind = _Kind.percent;
    } else if (t.kind == _Kind.integer &&
        (next?.kind == _Kind.unit && next!.text != '€' ||
            prev != null &&
                _quantityLabels.contains(prev.text.toLowerCase()))) {
      t.kind = _Kind.quantity;
    } else if (t.kind == _Kind.integer &&
        prev != null &&
        (prev.text == 'x' || prev.text == '×') &&
        (i < 2 || tokens[i - 2].kind != _Kind.integer)) {
      t.kind = _Kind.quantity;
    }
  }
  return tokens;
}

/// The normalized word list of [text]: lower case, accents dropped,
/// punctuation turned into spaces.
List<String> supplierWords(String text) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ç': 'c', 'ñ': 'n', 'ß': 'ss',
  };
  final lower = text.toLowerCase().split('').map((c) => accents[c] ?? c).join();
  return lower
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
}

/// The form a description is remembered in on [Product.supplierNames].
String normalizeSupplierText(String text) => supplierWords(text).join(' ');

/// Reads the product lines out of an invoice's [rows] (see [pdfRows]).
///
/// A row counts as a product line when it has an amount and words to
/// describe it, and none of its words is bookkeeping ([_skipWords]). A
/// description printed on the row above its numbers is picked up from
/// there, and a detail row under a line (an article number) adds its codes.
List<PurchaseLine> parsePurchaseRows(List<String> rows) {
  final lines = <PurchaseLine>[];
  String? textAbove;
  for (final row in rows) {
    final tokens = _tokenize(row);
    final words = supplierWords(row);
    if (words.any(_skipWords.contains)) {
      textAbove = null;
      continue;
    }

    final money = tokens.where((t) => t.kind == _Kind.money).toList();
    final descriptionTokens = tokens.where((t) => t.kind == _Kind.text);
    var description = descriptionTokens.map((t) => t.text).join(' ');
    final codes = [
      for (final t in tokens)
        if ((t.kind == _Kind.text && _digit.hasMatch(t.text)) ||
            (t.kind == _Kind.integer && t.text.length >= 4))
          t.text,
    ];

    if (money.isEmpty) {
      // A row of words only: a description waiting for its numbers on the
      // next row, or details of the line above.
      if (_letter.hasMatch(row)) {
        textAbove = description;
        if (lines.isNotEmpty && codes.isNotEmpty) {
          final last = lines.removeLast();
          lines.add(PurchaseLine(
            text: last.text,
            description: last.description,
            quantity: last.quantity,
            unitPrice: last.unitPrice,
            codes: {...last.codes, ...codes}.toList(),
          ));
        }
      }
      continue;
    }

    if (description.replaceAll(RegExp(r'[^a-zA-ZÀ-ÿ]'), '').length < 3) {
      if (textAbove == null) continue;
      description = textAbove;
    }
    textAbove = null;

    final (quantity, unitPrice, used) = _quantityOf(tokens, money);
    lines.add(PurchaseLine(
      text: row.replaceAll('\t', '  '),
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
      codes: [
        for (final c in codes)
          if (used == null || c != used.text) c,
      ],
    ));
  }
  return lines;
}

/// The quantity on a row: one it spells out ("2x", "2 stuks", "Aantal 2");
/// else a whole number that times one amount gives another (the unit price
/// and the line total); else a number leading the row; else 1.
(double, double?, _Token?) _quantityOf(List<_Token> tokens, List<_Token> money) {
  final marked = tokens.where((t) => t.kind == _Kind.quantity).firstOrNull;
  final candidates = [
    ?marked,
    ...tokens.where((t) => t.kind == _Kind.integer && t.value! <= 9999),
    // Some shops print the quantity with decimals: "2,00".
    ...money.where((t) => t.value! >= 1 && t.value! <= 999 &&
        t.value! == t.value!.roundToDouble()),
  ];

  for (final q in candidates) {
    if (q.value! < 2) continue;
    for (final unit in money) {
      if (identical(unit, q)) continue;
      for (final total in money) {
        if (identical(total, q) || identical(total, unit)) continue;
        if ((q.value! * unit.value! - total.value!).abs() <=
            0.02 + total.value!.abs() * 0.005) {
          return (q.value!, unit.value, q);
        }
      }
    }
  }
  if (marked != null) return (marked.value!, null, marked);

  final first = tokens.first;
  if (first.kind == _Kind.integer && first.value! >= 1 && first.value! < 1000) {
    return (first.value!, null, first);
  }
  return (1, null, null);
}

// ── Matching ─────────────────────────────────────────────────────────────────

/// Words too common to say anything about which product is meant.
const _stopWords = {
  'de', 'het', 'een', 'en', 'van', 'voor', 'met', 'in', 'op', 'of', 'aan',
  'the', 'a', 'an', 'and', 'for', 'with', 'to', 'x', 'st', 'stuk',
  'stuks', 'per', 'incl', 'excl', 'inclusief', 'exclusief',
};

List<String> _keywords(String text) =>
    supplierWords(text).where((w) => !_stopWords.contains(w)).toList();

double _dice(String a, String b) {
  Set<String> grams(String s) =>
      {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
  final ga = grams(a), gb = grams(b);
  if (ga.isEmpty || gb.isEmpty) return 0;
  return 2 * ga.intersection(gb).length / (ga.length + gb.length);
}

/// How alike two words are, 0 to 1. Words with digits in them (sizes,
/// codes) only count when they are equal — `M8` is not `M10`.
double _wordSimilarity(String a, String b) {
  if (a == b) return 1;
  if (_digit.hasMatch(a) || _digit.hasMatch(b)) return 0;
  if (a.length >= 4 && b.length >= 4 && (a.startsWith(b) || b.startsWith(a))) {
    return 0.85;
  }
  if (a.length < 3 || b.length < 3) return 0;
  final d = _dice(a, b);
  return d >= 0.7 ? d : 0;
}

/// How much of [from] is found in [into], weighting long words heavier.
double _coverage(List<String> from, List<String> into) {
  if (from.isEmpty || into.isEmpty) return 0;
  var found = 0.0, total = 0.0;
  for (final w in from.toSet()) {
    final weight = w.length.clamp(2, 8).toDouble();
    total += weight;
    var best = 0.0;
    for (final o in into) {
      final s = _wordSimilarity(w, o);
      if (s > best) best = s;
      if (best == 1) break;
    }
    found += weight * best;
  }
  return found / total;
}

String _compact(String s) => supplierWords(s).join();

/// How surely [line] is [product], 0 to 1.
///
/// - 1 when the shop's wording was confirmed for this product before;
/// - 0.95 when an article code on the line appears in the product;
/// - otherwise by words: mostly how much of the product's name the line
///   covers (a shop's description is usually the longer of the two), partly
///   how much of the line the product's name and description cover.
double matchScore(PurchaseLine line, Product product) {
  final normalized = normalizeSupplierText(line.description);
  if (product.supplierNames.contains(normalized)) return 1;

  final lineWords = _keywords(line.description);
  final nameWords = _keywords(product.name);
  final allWords = _keywords('${product.name} ${product.description}');
  var score = 0.65 * _coverage(nameWords, lineWords) +
      0.35 * _coverage(lineWords, allWords);

  for (final alias in product.supplierNames) {
    final aliasWords = _keywords(alias);
    final s = 0.5 * _coverage(aliasWords, lineWords) +
        0.5 * _coverage(lineWords, aliasWords);
    if (s * 0.97 > score) score = s * 0.97;
  }

  final productCompact = _compact('${product.name} ${product.description}');
  for (final code in line.codes) {
    final c = _compact(code);
    if (c.length >= 4 && _digit.hasMatch(c) && productCompact.contains(c)) {
      return score > 0.95 ? score : 0.95;
    }
  }
  return score;
}

/// Below this a product is not proposed for a line by itself, though it is
/// still offered when the user picks one.
const double matchThreshold = 0.5;

/// [products] ranked by how well they match [line], best first.
List<({Product product, double score})> rankProducts(
  PurchaseLine line,
  List<Product> products,
) {
  final ranked = [
    for (final p in products) (product: p, score: matchScore(line, p)),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return ranked;
}
