import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/utils/invoice_numbering.dart';

void main() {
  test('reads the sequence number off an invoice number', () {
    expect(sequenceOf('F-0055'), 55);
    expect(sequenceOf('OFF-0003'), 3);
    expect(sequenceOf(''), isNull);
  });

  group('rolledBackCounter', () {
    int roll(int counter, List<int> remaining, List<int> deleted) =>
        rolledBackCounter(
          counter: counter,
          remaining: remaining,
          deleted: deleted,
        );

    test('deleting the latest invoice gives its number back', () {
      expect(roll(56, [53, 54], [55]), 55);
    });

    test('deleting several at the end winds back past all of them', () {
      expect(roll(57, [53, 54], [55, 56]), 55);
    });

    test('deleting the latest twice in a row keeps giving numbers back', () {
      // The reported bug: 56 deleted (counter back to 56), then 55.
      expect(roll(57, [54, 55], [56]), 56);
      expect(roll(56, [54], [56, 55]), 55);
    });

    test('a number reissued after a delete can be given back again', () {
      // 55 deleted, 55 handed out again, then deleted again.
      expect(roll(56, [54], [55]), 55);
      expect(roll(56, [54], [55, 55]), 55);
    });

    test('an earlier gap at the end is closed once the latest goes', () {
      // 55 was deleted first (in the middle then), 56 after it.
      expect(roll(57, [53, 54, 56], [55]), 57);
      expect(roll(57, [53, 54], [55, 56]), 55);
    });

    test('an old gap from before this session is closed too', () {
      // 55 went missing in an earlier session, so only 56 is known deleted.
      expect(roll(57, [53, 54], [56]), 55);
    });

    test('a number in the middle is not given back', () {
      expect(roll(56, [53, 55], [54]), 56);
    });

    test('a counter set ahead of the list on purpose is left alone', () {
      expect(roll(100, [53, 54], [55]), 100);
    });

    test('deleting the only invoice hands its number out again', () {
      expect(roll(101, [], [100]), 100);
      expect(roll(102, [], [100, 101]), 100);
    });

    test('deletes running side by side agree, in either order', () {
      // Both see 55 and 56 as deleted; whichever commits second sees the
      // counter already wound back and leaves it.
      expect(roll(57, [54], [55, 56]), 55);
      expect(roll(55, [54], [55, 56]), 55);
    });
  });
}
