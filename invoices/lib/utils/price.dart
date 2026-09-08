/// Prices are stored ex. VAT with up to 4 decimals, so that a round incl. VAT
/// price (e.g. €10,00) survives the conversion without rounding drift.
const int kPriceDecimals = 4;

/// Rounds to the precision that is actually persisted.
double roundPrice(double value) =>
    double.parse(value.toStringAsFixed(kPriceDecimals));

/// Formats a stored price for a text input: full stored precision, with
/// trailing zeros trimmed (8.2645 → "8.2645", 8.26 → "8.26", 10 → "10").
///
/// Showing the stored value rather than a 2-decimal rounding is what keeps the
/// value stable: re-saving a form parses back exactly what was loaded.
String formatPriceInput(double value) {
  var s = value.toStringAsFixed(kPriceDecimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return s;
}

/// The thousands separator used everywhere money is shown. A non-breaking
/// space keeps an amount on one line: "1 000,00" must never wrap into "1" on
/// one line and "000,00" on the next.
const String kThousandsSeparator = '\u00A0';

/// Formats a money amount for display: thousands grouped with a space
/// (1 000, 250 000 000), [decimals] digits after the separator, and
/// [currency] in front. [decimalSeparator] is the point on screen and the
/// comma on the customer's document.
String formatMoney(
  double amount, {
  String currency = '',
  int decimals = 2,
  String decimalSeparator = '.',
}) {
  final fixed = amount.abs().toStringAsFixed(decimals);
  final dot = fixed.indexOf('.');
  final whole = dot == -1 ? fixed : fixed.substring(0, dot);
  final fraction = dot == -1 ? '' : fixed.substring(dot + 1);
  final grouped = whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}$kThousandsSeparator',
  );
  final sign = amount < 0 ? '-' : '';
  final decimalPart = fraction.isEmpty ? '' : '$decimalSeparator$fraction';
  return '$sign$currency$grouped$decimalPart';
}

/// Formats an amount for display, as a span when [max] is above [min]. A quote
/// whose items are estimated ("1-4 uur") totals to a range rather than a
/// single number.
String formatAmountRange(double min, double max, String currency) {
  final low = formatMoney(min, currency: currency);
  if (max <= min) return low;
  return '$low - ${formatMoney(max, currency: currency)}';
}

/// Parses a number as typed. A Dutch keyboard offers a decimal comma while
/// `double.tryParse` only accepts a point, so both are read the same way
/// ("8,25" and "8.25" both give 8.25). Surrounding spaces are ignored.
double? parseDecimalInput(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));
