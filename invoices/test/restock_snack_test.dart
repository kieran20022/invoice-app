import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/widgets/restock_snack.dart';

void main() {
  test('counts pieces when every quantity is whole', () {
    expect(
      restockLabel({'bougie': 4, 'filter': 1}),
      '5 producten terug in voorraad',
    );
    expect(restockLabel({'filter': 1}), '1 product terug in voorraad');
  });

  test('counts products when a quantity is fractional', () {
    expect(
      restockLabel({'olie': 1.5, 'bougie': 4}),
      '2 producten terug in voorraad',
    );
  });

  test('merges what several invoices put back', () {
    expect(
      mergeRestocked([
        {'a': 2, 'b': 1},
        {'a': 1},
        {},
      ]),
      {'a': 3, 'b': 1},
    );
  });

  testWidgets('toast sits at the top and its button takes the parts back', (
    tester,
  ) async {
    final undone = await _pumpToast(tester);
    final toast = find.text('4 producten terug in voorraad');
    expect(toast, findsOneWidget);
    expect(tester.getCenter(toast).dy, lessThan(200));

    await tester.tap(find.text('Producten Verwijderen'));
    await tester.pumpAndSettle();
    expect(undone, [1]);
    expect(toast, findsNothing);
  });

  testWidgets('toast can be swiped away, up or sideways', (tester) async {
    var undone = await _pumpToast(tester);
    await tester.fling(
      find.text('4 producten terug in voorraad'),
      const Offset(0, -200),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('4 producten terug in voorraad'), findsNothing);

    undone = await _pumpToast(tester);
    await tester.fling(
      find.text('4 producten terug in voorraad'),
      const Offset(400, 0),
      1000,
    );
    await tester.pumpAndSettle();
    expect(find.text('4 producten terug in voorraad'), findsNothing);
    expect(undone, isEmpty);
  });

  testWidgets('toast goes by itself', (tester) async {
    await _pumpToast(tester);
    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(find.text('4 producten terug in voorraad'), findsNothing);
  });
}

/// Opens a page whose button deletes "an invoice" that put [restocked] back,
/// and returns how often the toast's undo ran.
Future<List<int>> _pumpToast(
  WidgetTester tester, {
  Map<String, double> restocked = const {'bougie': 4},
}) async {
  final undone = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showRestockSnack(
                Overlay.of(context, rootOverlay: true),
                ScaffoldMessenger.of(context),
                restocked,
                onUndo: () async => undone.add(1),
              ),
              child: const Text('delete'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('delete'));
  await tester.pumpAndSettle();
  return undone;
}
