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

  /// Sub-categories in use within [category], alphabetically.
  List<String> subCategoriesFor(String category) =>
      subCategoriesIn(_products, category);

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

  /// Files [productIds] under [subCategory] (empty string clears it). Applied
  /// locally first so the list regroups without waiting for Firestore.
  Future<void> assignSubCategory(
    List<String> productIds,
    String subCategory,
  ) async {
    if (_userId == null || productIds.isEmpty) return;
    final ids = productIds.toSet();
    _products = _products
        .map((p) => ids.contains(p.id) ? p.copyWith(subCategory: subCategory) : p)
        .toList()
      ..sort(compareProducts);
    notifyListeners();
    await _firestore.saveProductSubCategory(_userId!, productIds, subCategory);
  }

  /// Renames a category on every product carrying it. Renaming onto an
  /// existing category merges the two.
  Future<void> renameCategory(String from, String to) async {
    if (_userId == null || from.isEmpty || to.isEmpty || from == to) return;
    final ids = _products
        .where((p) => p.category == from)
        .map((p) => p.id)
        .toList();
    if (ids.isEmpty) return;
    _products = _products
        .map((p) => p.category == from ? p.copyWith(category: to) : p)
        .toList()
      ..sort(compareProducts);
    notifyListeners();
    await _firestore.saveProductCategory(_userId!, ids, to);
  }

  /// Renames a sub-category within [category]. Renaming onto an existing
  /// sub-category merges the two.
  Future<void> renameSubCategory(
    String category,
    String from,
    String to,
  ) async {
    if (from.isEmpty || to.isEmpty || from == to) return;
    final ids = _products
        .where((p) => p.category == category && p.subCategory == from)
        .map((p) => p.id)
        .toList();
    await assignSubCategory(ids, to);
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
