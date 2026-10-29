import 'invoice.dart';

/// What one invoice has taken out of the inventory, keyed by the invoice's id.
///
/// The stock count on a product is what is still on the shelf, so a part is
/// subtracted the moment it lands on an invoice. The hold remembers how much
/// each invoice took, which is what lets a later edit subtract or return only
/// the difference, and what keeps a cancelled invoice's parts findable: while
/// the invoice is unpaid ([settled] false) its parts sit in the "Gereserveerd"
/// list, and if the invoice is deleted they stay there until they are put back
/// on the shelf or written off.
class StockHold {
  final String invoiceId;

  /// Quantity taken per product id.
  final Map<String, double> quantities;

  /// Product names as they were on the invoice, so a line can still be named
  /// after its product or invoice is gone.
  final Map<String, String> names;

  /// The invoice as it was last seen — shown once the invoice itself is gone.
  final String invoiceLabel;
  final String clientNaam;
  final String clientKenteken;

  /// The invoice is paid: its parts are sold and leave the reserved list.
  final bool settled;
  final DateTime updatedAt;

  const StockHold({
    required this.invoiceId,
    required this.quantities,
    this.names = const {},
    this.invoiceLabel = '',
    this.clientNaam = '',
    this.clientKenteken = '',
    this.settled = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'quantities': quantities,
        'names': names,
        'invoiceLabel': invoiceLabel,
        'clientNaam': clientNaam,
        'clientKenteken': clientKenteken,
        'settled': settled,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StockHold.fromMap(String invoiceId, Map<String, dynamic> map) =>
      StockHold(
        invoiceId: invoiceId,
        quantities: {
          for (final e in (map['quantities'] as Map? ?? {}).entries)
            e.key as String: (e.value as num).toDouble(),
        },
        names: {
          for (final e in (map['names'] as Map? ?? {}).entries)
            e.key as String: e.value as String,
        },
        invoiceLabel: map['invoiceLabel'] ?? '',
        clientNaam: map['clientNaam'] ?? '',
        clientKenteken: map['clientKenteken'] ?? '',
        settled: map['settled'] == true,
        updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      );

  /// The hold an invoice would leave if it took [quantities] now.
  factory StockHold.forInvoice(
    Invoice invoice,
    Map<String, double> quantities, {
    DateTime? now,
  }) =>
      StockHold(
        invoiceId: invoice.id,
        quantities: quantities,
        names: {
          for (final item in invoice.items)
            if (item.productId != null && quantities.containsKey(item.productId))
              item.productId!: item.omschrijving,
        },
        invoiceLabel: '${invoice.documentLabel} ${invoice.numberLabel}',
        clientNaam: invoice.clientNaam,
        clientKenteken: invoice.clientKenteken,
        settled: invoice.isPaid,
        updatedAt: now ?? DateTime.now(),
      );
}

/// How much of each tracked product [invoice] takes from the inventory.
/// A quote takes nothing — it only estimates — and an item typed in by hand
/// has no product to take from. The same product on two lines adds up.
Map<String, double> stockClaims(
  Invoice invoice,
  bool Function(String productId) isTracked,
) {
  if (invoice.isQuote) return const {};
  final claims = <String, double>{};
  for (final item in invoice.items) {
    final id = item.productId;
    if (id == null || id.isEmpty || !isTracked(id) || item.aantal <= 0) {
      continue;
    }
    claims[id] = (claims[id] ?? 0) + item.aantal;
  }
  return claims;
}

/// Per product, how much more [desired] takes than [held] did — what has to
/// come off the shelf. Negative is stock going back; unchanged lines are left
/// out.
Map<String, double> stockDelta(
  Map<String, double> held,
  Map<String, double> desired,
) {
  final delta = <String, double>{};
  for (final id in {...held.keys, ...desired.keys}) {
    final d = (desired[id] ?? 0) - (held[id] ?? 0);
    if (d.abs() > 1e-9) delta[id] = d;
  }
  return delta;
}
