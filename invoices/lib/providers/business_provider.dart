import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/business_info.dart';
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
