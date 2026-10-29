import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/inventory.dart';
import '../services/firestore_service.dart';

/// The reserved side of the inventory: parts taken by invoices that are not
/// paid yet. The stock counts themselves live on the products
/// ([ProductProvider]); this holds what is on its way out.
class InventoryProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<StockHold> _holds = [];
  bool _isLoaded = false;
  String? _userId;
  StreamSubscription<List<StockHold>>? _sub;

  /// Open holds, most recently changed first.
  List<StockHold> get holds => _holds;
  bool get isLoaded => _isLoaded;

  /// How many of [productId] open invoices currently hold.
  double reservedFor(String productId) =>
      _holds.fold(0, (sum, h) => sum + (h.quantities[productId] ?? 0));

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _holds = [];
    _isLoaded = false;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _firestore.openHoldsStream(userId).listen(
      (holds) {
        _holds = holds..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _isLoaded = true;
        notifyListeners();
      },
      onError: (_) {
        _isLoaded = true;
        notifyListeners();
      },
    );
  }

  /// Puts a deleted invoice's parts back on the shelf ([productIds] null:
  /// all of them).
  Future<void> restock(String invoiceId, {Iterable<String>? productIds}) async {
    if (_userId == null) return;
    await _firestore.releaseHold(
      _userId!,
      invoiceId,
      productIds: productIds,
      restock: true,
    );
  }

  /// Drops a deleted invoice's parts without restocking them.
  Future<void> writeOff(String invoiceId, {Iterable<String>? productIds}) async {
    if (_userId == null) return;
    await _firestore.releaseHold(
      _userId!,
      invoiceId,
      productIds: productIds,
      restock: false,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
