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

/// Formats an amount for display, as a span when [max] is above [min]. A quote
/// whose items are estimated ("1-4 uur") totals to a range rather than a
/// single number.
String formatAmountRange(double min, double max, String currency) {
  final low = '$currency${min.toStringAsFixed(2)}';
  if (max <= min) return low;
  return '$low - $currency${max.toStringAsFixed(2)}';
}
