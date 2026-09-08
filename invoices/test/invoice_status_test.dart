import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/invoice.dart';

Invoice _invoice(String status) => Invoice(
      id: '1',
      invoiceNumber: 'F-0001',
      issueDate: DateTime(2026, 1, 1),
      clientNaam: 'Jan',
      businessName: 'Garage',
      items: const [],
      status: status,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('both payment methods count as paid', () {
    expect(_invoice(Invoice.paidCash).isPaid, isTrue);
    expect(_invoice(Invoice.paidCard).isPaid, isTrue);
    // Invoices paid before the method was recorded stay paid.
    expect(_invoice('betaald').isPaid, isTrue);
    expect(_invoice('concept').isPaid, isFalse);
  });

  test('the method is part of the state label', () {
    expect(_invoice(Invoice.paidCash).statusLabel, 'Contant betaald');
    expect(_invoice(Invoice.paidCard).statusLabel, 'Pin betaald');
    expect(_invoice('betaald').statusLabel, 'Betaald');
    expect(_invoice('concept').statusLabel, 'Concept');
  });
}
