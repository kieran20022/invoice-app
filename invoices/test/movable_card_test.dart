import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/screens/invoices/movable_invoice_card.dart';

void main() {
  late List<String> log;

  Future<void> pumpCard(WidgetTester tester, {bool payable = true}) async {
    log = [];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MovableInvoiceCard(
            onDelete: () => log.add('delete'),
            swipeUp: payable
                ? MovableCardAction(
                    label: 'Contant',
                    icon: Icons.payments_rounded,
                    color: Colors.green,
                    onPressed: () => log.add('contant'),
                  )
                : null,
            swipeDown: payable
                ? MovableCardAction(
                    label: 'Pin',
                    icon: Icons.credit_card_rounded,
                    color: Colors.blue,
                    onPressed: () => log.add('pin'),
                  )
                : null,
            child: SizedBox(
              height: 72,
              width: double.infinity,
              child: GestureDetector(
                onTap: () => log.add('open-invoice'),
                child: const Text('F-0001'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Swipes the card by [dx] horizontally while the finger also travels [dy]
  /// vertically — the diagonal the card reads as up or down.
  Future<void> swipe(WidgetTester tester, double dx, {double dy = 0}) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('F-0001')),
    );
    // In steps, so the widget sees the finger travel rather than teleport.
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(dx / 10, dy / 10));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('right and up marks contant', (tester) async {
    await pumpCard(tester);
    await swipe(tester, 110, dy: -40);
    expect(log, ['contant']);
  });

  testWidgets('right and down marks pin', (tester) async {
    await pumpCard(tester);
    await swipe(tester, 110, dy: 40);
    expect(log, ['pin']);
  });

  testWidgets('the aimed action is shown while swiping', (tester) async {
    await pumpCard(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('F-0001')),
    );
    for (var i = 0; i < 6; i++) {
      await gesture.moveBy(const Offset(10, -5));
      await tester.pump();
    }

    expect(find.text('Contant'), findsOneWidget);
    expect(find.text('Pin'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();
    // Nothing is left uncovered once the card springs back.
    expect(find.text('Contant'), findsNothing);
  });

  testWidgets('a right swipe with no direction to it does nothing',
      (tester) async {
    await pumpCard(tester);
    await swipe(tester, 110);
    expect(log, isEmpty);
  });

  testWidgets('too short a swipe does nothing either way', (tester) async {
    await pumpCard(tester);
    await swipe(tester, 30, dy: -30);
    expect(log, isEmpty);

    await swipe(tester, -30);
    expect(log, isEmpty);
  });

  testWidgets('left asks to delete', (tester) async {
    await pumpCard(tester);
    await swipe(tester, -110);
    expect(log, ['delete']);
  });

  testWidgets('a quote can only be deleted', (tester) async {
    await pumpCard(tester, payable: false);

    await swipe(tester, 110, dy: -40);
    await swipe(tester, 110, dy: 40);
    expect(log, isEmpty);

    await swipe(tester, -110);
    expect(log, ['delete']);
  });

  testWidgets('the card itself stays tappable', (tester) async {
    await pumpCard(tester);
    await tester.tap(find.text('F-0001'));
    await tester.pumpAndSettle();
    expect(log, ['open-invoice']);
  });
}
