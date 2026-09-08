import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/utils/price.dart';

void main() {
  const nb = kThousandsSeparator;

  test('groups thousands with a space', () {
    expect(formatMoney(1000, currency: '€'), '€1${nb}000.00');
    expect(formatMoney(250000000, currency: '€', decimals: 0), '€250${nb}000${nb}000');
    expect(formatMoney(999.5, currency: '€'), '€999.50');
    expect(formatMoney(1234567.891, currency: '€'), '€1${nb}234${nb}567.89');
  });

  test('honours the decimal separator and sign', () {
    expect(formatMoney(1234.5, currency: '€', decimalSeparator: ','),
        '€1${nb}234,50');
    expect(formatMoney(-1234.5, currency: '€'), '-€1${nb}234.50');
  });

  test('ranges are formatted the same way', () {
    expect(formatAmountRange(1200, 4800, '€'),
        '€1${nb}200.00 - €4${nb}800.00');
    expect(formatAmountRange(1200, 1200, '€'), '€1${nb}200.00');
  });
}
