import 'package:flutter/services.dart';

/// Groups the digits of a phone number in pairs (`06 12 34 56 78`) as it is
/// typed. Purely cosmetic — the spaces are stripped again before the number is
/// stored, so only the reader sees them.
class PhonePairFormatter extends TextInputFormatter {
  const PhonePairFormatter();

  /// `0612345678` → `06 12 34 56 78`, keeping a leading `+` intact because
  /// that is what marks the number as already international.
  static String format(String raw) {
    final plus = raw.trimLeft().startsWith('+') ? '+' : '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer(plus);
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && i.isEven) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Where the caret sits once [digitsBefore] digits have been regrouped.
  static int caretFor(int digitsBefore, bool hasPlus) {
    if (digitsBefore == 0) return hasPlus ? 1 : 0;
    final spaces = (digitsBefore - 1) ~/ 2;
    return (hasPlus ? 1 : 0) + digitsBefore + spaces;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = format(newValue.text);

    // Count the digits ahead of the caret rather than its raw offset, so the
    // caret survives the spaces being reshuffled around it.
    final caret = newValue.selection.baseOffset;
    final digitsBefore = caret < 0
        ? newValue.text.replaceAll(RegExp(r'[^0-9]'), '').length
        : newValue.text
            .substring(0, caret.clamp(0, newValue.text.length))
            .replaceAll(RegExp(r'[^0-9]'), '')
            .length;

    final offset = caretFor(digitsBefore, text.startsWith('+'));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: offset.clamp(0, text.length),
      ),
    );
  }
}
