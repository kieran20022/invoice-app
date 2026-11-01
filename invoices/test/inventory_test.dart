import 'package:flutter_test/flutter_test.dart';
import 'package:invoices/models/inventory.dart';
import 'package:invoices/models/invoice.dart';
import 'package:invoices/models/product.dart';

InvoiceItem _item(String? productId, double aantal, {String name = 'Band'}) =>
    InvoiceItem(
      id: '${productId}_$aantal',
      omschrijving: name,
      aantal: aantal,
      prijsExBtw: 10,
      productId: productId,
    );

Invoice _invoice(
  List<InvoiceItem> items, {
  bool isQuote = false,
  String status = 'concept',
}) =>
    Invoice(
      id: 'inv1',
      invoiceNumber: 'F-0007',
      issueDate: DateTime(2026, 1, 1),
      clientNaam: 'Jan',
      clientKenteken: 'AB-12-CD',
      businessName: 'Garage',
      items: items,
      status: status,
      createdAt: DateTime(2026, 1, 1),
      isQuote: isQuote,
    );

bool _tracked(String id) => id != 'labour';

void main() {
  group('stockClaims', () {
    test('sums tracked products and skips labour and hand-typed lines', () {
      final claims = stockClaims(
        _invoice([
          _item('tyre', 2),
          _item('labour', 3, name: 'Arbeid'),
          _item(null, 1, name: 'Los onderdeel'),
          _item('tyre', 1),
        ]),
        _tracked,
      );
      expect(claims, {'tyre': 3});
    });

    test('a line made of parts takes the parts it records', () {
      final service = InvoiceItem(
        id: 'service',
        omschrijving: 'Onderhoud',
        aantal: 1,
        prijsExBtw: 80,
        productId: 'labour',
        parts: const [
          ItemPart(productId: 'oil', naam: 'Olie', aantal: 4.5),
          ItemPart(productId: 'plug', naam: 'Bougie', aantal: 4),
        ],
      );
      final invoice = _invoice([service, _item('oil', 1, name: 'Olie')]);
      expect(stockClaims(invoice, _tracked), {'oil': 5.5, 'plug': 4});
      expect(
        StockHold.forInvoice(invoice, stockClaims(invoice, _tracked)).names,
        {'oil': 'Olie', 'plug': 'Bougie'},
      );
      expect(invoiceProductIds(invoice), {'labour', 'oil', 'plug'});
    });

    test('parts survive a round trip through Firestore', () {
      const item = InvoiceItem(
        id: 'service',
        omschrijving: 'Onderhoud',
        aantal: 1,
        prijsExBtw: 80,
        parts: [ItemPart(productId: 'oil', naam: 'Olie', aantal: 4)],
      );
      final back = InvoiceItem.fromMap(item.toMap());
      expect(back.parts.single.productId, 'oil');
      expect(back.parts.single.aantal, 4);
      expect(InvoiceItem.fromMap({'omschrijving': 'Oud'}).parts, isEmpty);
    });

    test('a quote takes nothing off the shelf', () {
      expect(
        stockClaims(_invoice([_item('tyre', 2)], isQuote: true), _tracked),
        isEmpty,
      );
    });
  });

  group('stockDelta', () {
    test('only the difference since the last sync moves', () {
      expect(
        stockDelta({'tyre': 2, 'chain': 1}, {'tyre': 3, 'bulb': 1}),
        {'tyre': 1, 'chain': -1, 'bulb': 1},
      );
    });

    test('an unchanged invoice moves nothing', () {
      expect(stockDelta({'tyre': 2}, {'tyre': 2}), isEmpty);
    });
  });

  test('a hold remembers the invoice, and settles once paid', () {
    final open = StockHold.forInvoice(
      _invoice([_item('tyre', 2), _item('labour', 1, name: 'Arbeid')]),
      {'tyre': 2},
    );
    expect(open.names, {'tyre': 'Band'});
    expect(open.invoiceLabel, 'Factuur F-0007');
    expect(open.settled, isFalse);

    final round = StockHold.fromMap('inv1', open.toMap());
    expect(round.quantities, {'tyre': 2.0});
    expect(round.clientKenteken, 'AB-12-CD');

    final paid = StockHold.forInvoice(
      _invoice([_item('tyre', 2)], status: Invoice.paidCash),
      {'tyre': 2},
    );
    expect(paid.settled, isTrue);
  });

  test('products read without stock fields are not tracked', () {
    final p = Product.fromMap('p', {'name': 'Band', 'price': 10});
    expect(p.trackStock, isFalse);
    expect(p.stock, 0);
    expect(formatStock(3), '3');
    expect(formatStock(2.5), '2.5');
  });
}
