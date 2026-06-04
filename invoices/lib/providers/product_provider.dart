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
        _products = products;
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
