import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/business_info.dart';
import '../models/product.dart';
import '../services/firestore_service.dart';

class BusinessProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  BusinessInfo? _businessInfo;
  bool _isLoaded = false;
  bool _isSaving = false;
  String? _userId;
  StreamSubscription<BusinessInfo?>? _sub;

  BusinessInfo? get businessInfo => _businessInfo;
  bool get isLoaded => _isLoaded;
  bool get isSaving => _isSaving;
  List<String> get favoriteCategories =>
      _businessInfo?.favoriteCategories ?? [];
  List<String> get categoryOrder => _businessInfo?.categoryOrder ?? [];
  List<String> get subCategoryOrder => _businessInfo?.subCategoryOrder ?? [];

  ThemeMode get themeMode => switch (_businessInfo?.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _businessInfo = null;
    _isLoaded = false;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _firestore.businessInfoStream(userId).listen(
      (info) {
        _businessInfo = info;
        _isLoaded = true;
        notifyListeners();
      },
      onError: (_) {
        _isLoaded = true;
        notifyListeners();
      },
    );
  }

  Future<void> saveBusinessInfo(BusinessInfo info) async {
    if (_userId == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      await _firestore.saveBusinessInfo(_userId!, info);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Converts the picked image to a base64 string and saves it directly
  /// in Firestore — no Firebase Storage needed.
  Future<void> uploadLogo(XFile file) async {
    if (_userId == null) return;
    _isSaving = true;
    notifyListeners();
    try {
      final bytes = await file.readAsBytes();
      final base64str = base64Encode(bytes);
      await _firestore.saveLogoUrl(_userId!, base64str);
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavoriteCategory(String category) async {
    if (_userId == null) return;
    final current = List<String>.from(favoriteCategories);
    if (current.contains(category)) {
      current.remove(category);
    } else {
      current.add(category);
    }
    await _firestore.saveFavoriteCategories(_userId!, current);
  }

  Future<void> saveCategoryOrder(List<String> order) async {
    if (_userId == null) return;
    await _firestore.saveCategoryOrder(_userId!, order);
  }

  Future<void> saveSubCategoryOrder(List<String> order) async {
    if (_userId == null) return;
    await _firestore.saveSubCategoryOrder(_userId!, order);
  }

  /// Follows a category rename through the saved orders and the favourites.
  /// The product documents are rewritten by [ProductProvider.renameCategory].
  Future<void> renameCategory(String from, String to) async {
    if (_userId == null || from == to) return;
    final oldPrefix = subCategoryKey(from, '');
    await Future.wait([
      _firestore.saveCategoryOrder(
        _userId!,
        _replaced(categoryOrder, (c) => c == from ? to : c),
      ),
      _firestore.saveFavoriteCategories(
        _userId!,
        _replaced(favoriteCategories, (c) => c == from ? to : c),
      ),
      _firestore.saveSubCategoryOrder(
        _userId!,
        _replaced(
          subCategoryOrder,
          (key) => key.startsWith(oldPrefix)
              ? subCategoryKey(to, key.substring(oldPrefix.length))
              : key,
        ),
      ),
    ]);
  }

  /// Follows a sub-category rename through the saved sub-category order.
  Future<void> renameSubCategory(
    String category,
    String from,
    String to,
  ) async {
    if (_userId == null || from == to) return;
    final oldKey = subCategoryKey(category, from);
    final newKey = subCategoryKey(category, to);
    await _firestore.saveSubCategoryOrder(
      _userId!,
      _replaced(subCategoryOrder, (key) => key == oldKey ? newKey : key),
    );
  }

  /// Maps [list] through [rename], dropping duplicates the rename creates —
  /// renaming onto an existing name merges the two entries into one.
  List<String> _replaced(List<String> list, String Function(String) rename) {
    final seen = <String>{};
    return [
      for (final value in list)
        if (seen.add(rename(value))) rename(value),
    ];
  }

  Future<void> removeLogo() async {
    if (_userId == null) return;
    await _firestore.saveLogoUrl(_userId!, null);
  }

  Uint8List? get logoBytes {
    final b64 = _businessInfo?.logoBase64;
    if (b64 == null || b64.isEmpty) return null;
    try {
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
