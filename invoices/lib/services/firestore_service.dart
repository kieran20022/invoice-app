import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_info.dart';
import '../models/client.dart';
import '../models/inventory.dart';
import '../models/product.dart';
import '../models/vehicle.dart';
import '../models/invoice.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Business Info ──────────────────────────────────────────────────────────

  Stream<BusinessInfo?> businessInfoStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business')
        .snapshots()
        .map((snap) => snap.exists ? BusinessInfo.fromMap(snap.id, snap.data()!) : null);
  }

  Future<void> saveBusinessInfo(String userId, BusinessInfo info) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business')
        .set(info.toMap());
  }

  Future<void> saveFavoriteCategories(
      String userId, List<String> categories) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business')
        .set({'favoriteCategories': categories}, SetOptions(merge: true));
  }

  Future<void> saveCategoryOrder(String userId, List<String> order) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business')
        .set({'categoryOrder': order}, SetOptions(merge: true));
  }

  /// [order] holds `'<category>::<sub>'` keys across all categories.
  Future<void> saveSubCategoryOrder(String userId, List<String> order) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business')
        .set({'subCategoryOrder': order}, SetOptions(merge: true));
  }

  // Merge-writes only the logo so it survives even before full business info is saved.
  Future<void> saveLogoUrl(String userId, String? logoBase64) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('settings')
        .doc('business')
        .set({'logoBase64': logoBase64}, SetOptions(merge: true));
  }

  Future<int> incrementAndGetInvoiceNumber(String userId) =>
      _incrementCounter(userId, 'nextInvoiceNumber');

  /// Quotes count in their own sequence, separate from the invoice numbers.
  Future<int> incrementAndGetQuoteNumber(String userId) =>
      _incrementCounter(userId, 'nextQuoteNumber');

  Future<int> _incrementCounter(String userId, String field) async {
    final ref = _db.collection('users').doc(userId).collection('settings').doc('business');
    int nextNumber = 1;
    await _db.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (doc.exists) {
        nextNumber = (doc.data()?[field] ?? 1) as int;
        tx.update(ref, {field: nextNumber + 1});
      }
    });
    return nextNumber;
  }

  // ── Clients ────────────────────────────────────────────────────────────────

  Stream<List<Client>> clientsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('clients')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Client.fromMap(d.id, d.data())).toList());
  }

  Future<String> saveClient(String userId, Client client) async {
    if (client.id.isEmpty) {
      final ref = await _db
          .collection('users')
          .doc(userId)
          .collection('clients')
          .add(client.toMap());
      return ref.id;
    } else {
      await _db
          .collection('users')
          .doc(userId)
          .collection('clients')
          .doc(client.id)
          .set(client.toMap());
      return client.id;
    }
  }

  Future<void> deleteClient(String userId, String clientId) async {
    await _db.collection('users').doc(userId).collection('clients').doc(clientId).delete();
  }

  // ── Products ───────────────────────────────────────────────────────────────

  Stream<List<Product>> productsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList());
  }

  Future<String> saveProduct(String userId, Product product) async {
    if (product.id.isEmpty) {
      final ref = await _db
          .collection('users')
          .doc(userId)
          .collection('products')
          .add(product.toMap());
      return ref.id;
    } else {
      await _db
          .collection('users')
          .doc(userId)
          .collection('products')
          .doc(product.id)
          // Merged so fields the form does not carry (supplierNames) survive.
          .set(product.toMap(), SetOptions(merge: true));
      return product.id;
    }
  }

  /// Writes the manual position of each product in one batch.
  /// [orderedIds] is the products of a single category, in their new order.
  Future<void> saveProductOrder(String userId, List<String> orderedIds) async {
    final col = _db.collection('users').doc(userId).collection('products');
    final batch = _db.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.set(col.doc(orderedIds[i]), {'sortOrder': i}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Moves several products to one category in a single batch. Used to rename
  /// a category, which is really a rewrite of every product carrying it.
  Future<void> saveProductCategory(
    String userId,
    List<String> productIds,
    String category,
  ) async {
    final col = _db.collection('users').doc(userId).collection('products');
    final batch = _db.batch();
    for (final id in productIds) {
      batch.set(col.doc(id), {'category': category}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Files several products under one sub-category in a single batch.
  Future<void> saveProductSubCategory(
    String userId,
    List<String> productIds,
    String subCategory,
  ) async {
    final col = _db.collection('users').doc(userId).collection('products');
    final batch = _db.batch();
    for (final id in productIds) {
      batch.set(col.doc(id), {'subCategory': subCategory}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> deleteProduct(String userId, String productId) async {
    await _db.collection('users').doc(userId).collection('products').doc(productId).delete();
  }

  /// Marks [productIds] as kept in the inventory, or takes them out of it.
  /// Their count is left as it is, so switching tracking back on resumes it.
  Future<void> saveProductTracking(
    String userId,
    List<String> productIds,
    bool trackStock,
  ) async {
    final col = _db.collection('users').doc(userId).collection('products');
    final batch = _db.batch();
    for (final id in productIds) {
      batch.set(col.doc(id), {'trackStock': trackStock}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Adds [delta] to a product's stock as an increment, so it cannot clobber
  /// a count an invoice is changing at the same moment.
  Future<void> adjustProductStock(
    String userId,
    String productId,
    double delta,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(productId)
        .update({'stock': FieldValue.increment(delta)});
  }

  /// Books a supplier delivery in one batch: each product's stock goes up by
  /// its [quantities] entry (as an increment), and the supplier's wording in
  /// [supplierNames] is remembered on it.
  Future<void> receiveDelivery(
    String userId,
    Map<String, double> quantities,
    Map<String, Set<String>> supplierNames,
  ) async {
    final col = _db.collection('users').doc(userId).collection('products');
    final batch = _db.batch();
    for (final id in {...quantities.keys, ...supplierNames.keys}) {
      batch.update(col.doc(id), {
        if ((quantities[id] ?? 0) != 0)
          'stock': FieldValue.increment(quantities[id]!),
        if (supplierNames[id]?.isNotEmpty ?? false)
          'supplierNames': FieldValue.arrayUnion(supplierNames[id]!.toList()),
      });
    }
    await batch.commit();
  }

  /// Sets a product's stock outright — a count taken off the shelf.
  Future<void> setProductStock(
    String userId,
    String productId,
    double stock,
  ) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('products')
        .doc(productId)
        .update({'stock': stock});
  }

  // ── Inventory holds ───────────────────────────────────────────────────────

  /// Holds of invoices that are not paid yet — the "Gereserveerd" list.
  Stream<List<StockHold>> openHoldsStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('stockHolds')
        .where('settled', isEqualTo: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => StockHold.fromMap(d.id, d.data())).toList());
  }

  /// Brings the stock in line with what invoice [invoiceId] holds now, as
  /// stored in Firestore. Everything is read inside one transaction — the
  /// invoice, its earlier hold and the products involved — so the stock moves
  /// by exactly the difference since the last sync, however the invoice got
  /// here (saved, edited, paid, converted, released from the workshop).
  ///
  /// A deleted invoice keeps its unpaid hold: its parts are then waiting in
  /// the reserved list to be put back or written off. A paid one's parts were
  /// sold, so its hold is simply dropped.
  Future<void> syncInvoiceStock(String userId, String invoiceId) async {
    final user = _db.collection('users').doc(userId);
    final invoiceRef = user.collection('invoices').doc(invoiceId);
    final holdRef = user.collection('stockHolds').doc(invoiceId);

    await _db.runTransaction((tx) async {
      final invoiceSnap = await tx.get(invoiceRef);
      final holdSnap = await tx.get(holdRef);
      final hold = holdSnap.exists
          ? StockHold.fromMap(holdSnap.id, holdSnap.data()!)
          : null;

      if (!invoiceSnap.exists) {
        if (hold != null && hold.settled) tx.delete(holdRef);
        return;
      }
      final invoice = Invoice.fromMap(invoiceSnap.id, invoiceSnap.data()!);

      // A paid invoice that never held anything predates the inventory (or
      // the product's tracking): its parts left the shelf long ago, so an edit
      // to it now must not take them a second time.
      if (hold == null && invoice.isPaid) return;

      final ids = {
        ...invoiceProductIds(invoice),
        ...?hold?.quantities.keys,
      };
      final products = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in ids) {
        products[id] = await tx.get(user.collection('products').doc(id));
      }

      final desired = stockClaims(invoice, (id) {
        final p = products[id];
        return p != null && p.exists && p.data()?['trackStock'] == true;
      });
      final held = hold?.quantities ?? const <String, double>{};

      stockDelta(held, desired).forEach((id, delta) {
        final p = products[id];
        if (p == null || !p.exists) return;
        tx.update(p.reference, {'stock': FieldValue.increment(-delta)});
      });

      if (desired.isEmpty) {
        if (hold != null) tx.delete(holdRef);
      } else {
        tx.set(holdRef, StockHold.forInvoice(invoice, desired).toMap());
      }
    });
  }

  /// Takes lines out of a deleted invoice's hold. With [restock] they go back
  /// on the shelf; without, they are written off (used, broken, lost).
  /// [productIds] null means every line. Refused while the invoice still
  /// exists — its parts are then still on it, and putting them back would
  /// count them twice.
  Future<void> releaseHold(
    String userId,
    String invoiceId, {
    Iterable<String>? productIds,
    required bool restock,
  }) async {
    final user = _db.collection('users').doc(userId);
    final holdRef = user.collection('stockHolds').doc(invoiceId);

    await _db.runTransaction((tx) async {
      final invoiceSnap = await tx.get(user.collection('invoices').doc(invoiceId));
      if (invoiceSnap.exists) {
        throw StateError('De factuur bestaat nog — pas hem daar aan.');
      }
      final holdSnap = await tx.get(holdRef);
      if (!holdSnap.exists) return;
      final hold = StockHold.fromMap(holdSnap.id, holdSnap.data()!);

      final release = (productIds ?? hold.quantities.keys)
          .where(hold.quantities.containsKey)
          .toList();
      final products = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      if (restock) {
        for (final id in release) {
          products[id] = await tx.get(user.collection('products').doc(id));
        }
      }

      for (final p in products.values) {
        if (!p.exists) continue;
        tx.update(p.reference, {
          'stock': FieldValue.increment(hold.quantities[p.id]!),
        });
      }

      final remaining = Map.of(hold.quantities)
        ..removeWhere((id, _) => release.contains(id));
      if (remaining.isEmpty) {
        tx.delete(holdRef);
      } else {
        tx.update(holdRef, {'quantities': remaining});
      }
    });
  }

  // ── Invoices ───────────────────────────────────────────────────────────────

  Stream<List<Invoice>> invoicesStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Invoice.fromMap(d.id, d.data())).toList());
  }

  Future<String> saveInvoice(String userId, Invoice invoice) async {
    if (invoice.id.isEmpty) {
      final ref = await _db
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .add(invoice.toMap());
      return ref.id;
    } else {
      await _db
          .collection('users')
          .doc(userId)
          .collection('invoices')
          .doc(invoice.id)
          .set(invoice.toMap());
      return invoice.id;
    }
  }

  /// Moves an invoice into [status], stamping when it was paid. The stamp is
  /// what the income overview dates and orders by, so it is written with the
  /// status rather than left to be inferred later; moving back out of a paid
  /// state clears it.
  Future<void> updateInvoiceStatus(String userId, String invoiceId, String status) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .doc(invoiceId)
        .update({
      'status': status,
      'paidAt': Invoice.paidAtFor(status)?.toIso8601String(),
    });
  }

  Future<void> deleteInvoice(String userId, String invoiceId) async {
    await _db.collection('users').doc(userId).collection('invoices').doc(invoiceId).delete();
  }

  // ── Vehicles ───────────────────────────────────────────────────────

  /// Vehicles in the shop, most recently added first.
  Stream<List<Vehicle>> vehiclesStream(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Vehicle.fromMap(d.id, d.data())).toList());
  }

  Future<String> saveVehicle(String userId, Vehicle vehicle) async {
    if (vehicle.id.isEmpty) {
      final ref = await _db
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .add(vehicle.toMap());
      return ref.id;
    } else {
      await _db
          .collection('users')
          .doc(userId)
          .collection('vehicles')
          .doc(vehicle.id)
          .set(vehicle.toMap());
      return vehicle.id;
    }
  }

  Future<void> deleteVehicle(String userId, String vehicleId) async {
    await _db.collection('users').doc(userId).collection('vehicles').doc(vehicleId).delete();
  }
}
