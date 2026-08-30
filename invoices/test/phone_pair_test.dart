import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/services/whatsapp_service.dart';
import 'package:invoices/utils/phone_format.dart';

/// Types [input] one character at a time, the way the field sees it.
TextEditingValue typeOut(String input) {
  const formatter = PhonePairFormatter();
  var value = TextEditingValue.empty;
  for (final ch in input.split('')) {
    final caret = value.selection.baseOffset.clamp(0, value.text.length);
    final next = TextEditingValue(
      text: value.text.replaceRange(caret, caret, ch),
      selection: TextSelection.collapsed(offset: caret + 1),
    );
    value = formatter.formatEditUpdate(value, next);
  }
  return value;
}

void main() {
  test('groups digits in pairs', () {
    expect(PhonePairFormatter.format('0612345678'), '06 12 34 56 78');
    expect(PhonePairFormatter.format('06 12 3'), '06 12 3');
    expect(PhonePairFormatter.format('+31612345678'), '+31 61 23 45 67 8');
    expect(PhonePairFormatter.format(''), '');
    expect(PhonePairFormatter.format('+'), '+');
  });

  test('typing digit by digit keeps the caret at the end', () {
    final value = typeOut('0612345678');
    expect(value.text, '06 12 34 56 78');
    expect(value.selection.baseOffset, value.text.length);
  });

  test('caret stays put when editing mid-number', () {
    // "06 12 34" with the caret after the 4th digit, then a digit is typed.
    const formatter = PhonePairFormatter();
    const before = TextEditingValue(
      text: '06 12 34',
      selection: TextSelection.collapsed(offset: 5),
    );
    final after = formatter.formatEditUpdate(
      before,
      const TextEditingValue(
        text: '06 129 34',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    expect(after.text, '06 12 93 4');
    // Five digits precede the caret, so it lands just after the typed 9.
    expect(after.selection.baseOffset, 7);
    expect(after.text[after.selection.baseOffset - 1], '9');
  });

  test('stripping the display spaces round-trips through normalizePhone', () {
    final typed = typeOut('0612345678').text;
    expect(typed, '06 12 34 56 78');
    final stored = typed.replaceAll(' ', '').trim();
    expect(stored, '0612345678');
    expect(WhatsappService.normalizePhone(stored), '31612345678');
  });

  test('normalizePhone keeps a foreign country code intact', () {
    expect(WhatsappService.normalizePhone('+49 170 1234567'), '491701234567');
    expect(WhatsappService.normalizePhone('0031612345678'), '31612345678');
    expect(WhatsappService.normalizePhone('612345678'), '31612345678');
    expect(WhatsappService.normalizePhone('123'), isNull);
    expect(WhatsappService.normalizePhone(''), isNull);
  });
}
