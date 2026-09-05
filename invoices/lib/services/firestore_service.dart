import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_info.dart';
import '../models/client.dart';
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
          .set(product.toMap());
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

  Future<void> updateInvoiceStatus(String userId, String invoiceId, String status) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('invoices')
        .doc(invoiceId)
        .update({'status': status});
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
