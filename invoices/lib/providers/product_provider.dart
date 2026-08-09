import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

class ProductProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Product> _products = [];
  bool _isLoaded = false;
  String? _userId;
  StreamSubscription<List<Product>>? _sub;

  List<Product> get products => _products;
  bool get isLoaded => _isLoaded;

  List<String> get categories {
    final cats = _products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    cats.sort();
    return cats;
  }

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _products = [];
    _isLoaded = false;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _firestore.productsStream(userId).listen(
      (products) {
        _products = products..sort(compareProducts);
        _isLoaded = true;
        notifyListeners();
      },
      onError: (_) {
        _isLoaded = true;
        notifyListeners();
      },
    );
  }

  Future<void> saveProduct(Product product) async {
    if (_userId == null) return;
    await _firestore.saveProduct(_userId!, product);
  }

  /// Products of one category in their new order. Applied locally right away so
  /// the list does not jump while the Firestore write is in flight.
  Future<void> reorderProducts(List<Product> ordered) async {
    if (_userId == null || ordered.isEmpty) return;
    final positions = <String, int>{
      for (var i = 0; i < ordered.length; i++) ordered[i].id: i,
    };
    _products = _products
        .map((p) => positions.containsKey(p.id)
            ? p.copyWith(sortOrder: positions[p.id])
            : p)
        .toList()
      ..sort(compareProducts);
    notifyListeners();
    await _firestore.saveProductOrder(_userId!, ordered.map((p) => p.id).toList());
  }

  Future<void> deleteProduct(String productId) async {
    if (_userId == null) return;
    await _firestore.deleteProduct(_userId!, productId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
