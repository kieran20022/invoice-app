import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/business_info.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class BusinessProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();

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

  Future<String?> uploadLogo(dynamic file) async {
    if (_userId == null) return null;
    _isSaving = true;
    notifyListeners();
    try {
      final url = await _storage.uploadLogo(_userId!, file);
      // Always persist the URL — merge write leaves all other fields intact
      // whether or not the full business document has been saved yet.
      await _firestore.saveLogoUrl(_userId!, url);
      return url;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> removeLogo() async {
    if (_userId == null || _businessInfo == null) return;
    await _storage.deleteLogo(_userId!);
    final updated = BusinessInfo(
      id: _businessInfo!.id,
      name: _businessInfo!.name,
      address: _businessInfo!.address,
      city: _businessInfo!.city,
      state: _businessInfo!.state,
      zip: _businessInfo!.zip,
      country: _businessInfo!.country,
      phone: _businessInfo!.phone,
      email: _businessInfo!.email,
      website: _businessInfo!.website,
      logoUrl: null,
      nextInvoiceNumber: _businessInfo!.nextInvoiceNumber,
      currency: _businessInfo!.currency,
      defaultTaxRate: _businessInfo!.defaultTaxRate,
      invoicePrefix: _businessInfo!.invoicePrefix,
      defaultPaymentTerms: _businessInfo!.defaultPaymentTerms,
      defaultNotes: _businessInfo!.defaultNotes,
    );
    await _firestore.saveBusinessInfo(_userId!, updated);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
