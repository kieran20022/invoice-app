import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/business_info.dart';
import '../services/firestore_service.dart';

class InvoiceProvider extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  final _uuid = const Uuid();

  List<Invoice> _invoices = [];
  bool _isLoaded = false;
  String? _userId;
  StreamSubscription<List<Invoice>>? _sub;

  Invoice? _draft;

  List<Invoice> get invoices => _invoices;
  bool get isLoaded => _isLoaded;
  Invoice? get draft => _draft;

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _invoices = [];
    _isLoaded = false;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _firestore.invoicesStream(userId).listen(
      (invoices) {
        _invoices = invoices;
        _isLoaded = true;
        notifyListeners();
      },
      onError: (_) {
        _isLoaded = true;
        notifyListeners();
      },
    );
  }

  // ── Draft Management ───────────────────────────────────────────────────────

  void startEditDraft(Invoice invoice) {
    _draft = invoice;
    notifyListeners();
  }

  void startNewDraft(BusinessInfo business) {
    final now = DateTime.now();
    _draft = Invoice(
      id: '',
      invoiceNumber: '',
      issueDate: now,
      clientNaam: '',
      businessName: business.name,
      businessInvoicePrefix: business.invoicePrefix,
      businessKvk: business.kvk,
      businessIban: business.iban,
      businessPhone: business.phone,
      businessAddress: business.address,
      businessCity: business.city,
      businessState: business.state,
      businessZip: business.zip,
      businessCountry: business.country,
      businessWebsite: business.website,
      items: const [],
      notes: business.defaultNotes ?? '',
      template: 'classic',
      taxRate: business.defaultTaxRate,
      currency: business.currency,
      createdAt: now,
    );
    notifyListeners();
  }

  void updateDraftClient({
    String? naam,
    String? kenteken,
    String? productType,
    String? kmstand,
    String? datum,
    String? adres,
    String? telefoonnummer,
  }) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(
      clientNaam: naam,
      clientKenteken: kenteken,
      clientProductType: productType,
      clientKmstand: kmstand,
      clientDatum: datum,
      clientAdres: adres,
      clientTelefoonnummer: telefoonnummer,
    );
    notifyListeners();
  }

  void addDraftItem(InvoiceItem item) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(items: [..._draft!.items, item]);
    notifyListeners();
  }

  void updateDraftItem(InvoiceItem item) {
    if (_draft == null) return;
    final items = _draft!.items.map((i) => i.id == item.id ? item : i).toList();
    _draft = _draft!.copyWith(items: items);
    notifyListeners();
  }

  void removeDraftItem(String itemId) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(
        items: _draft!.items.where((i) => i.id != itemId).toList());
    notifyListeners();
  }

  void updateDraftDetails({
    String? notes,
    double? taxRate,
    DateTime? issueDate,
    String? currency,
  }) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(
      notes: notes,
      taxRate: taxRate,
      issueDate: issueDate,
      currency: currency,
    );
    notifyListeners();
  }

  InvoiceItem createItem({
    String? omschrijving,
    double aantal = 1,
    double prijsExBtw = 0,
    String? productId,
  }) =>
      InvoiceItem(
        id: _uuid.v4(),
        omschrijving: omschrijving ?? '',
        aantal: aantal,
        prijsExBtw: prijsExBtw,
        productId: productId,
      );

  Future<Invoice> saveDraft() async {
    if (_userId == null || _draft == null) throw Exception('Geen concept of gebruiker');

    if (_draft!.id.isNotEmpty) {
      await _firestore.saveInvoice(_userId!, _draft!);
      final saved = _draft!;
      _draft = null;
      notifyListeners();
      return saved;
    }

    final invoiceNumber = await _firestore.incrementAndGetInvoiceNumber(_userId!);
    final prefix = _draft!.businessInvoicePrefix.isEmpty ? 'F' : _draft!.businessInvoicePrefix;
    final formattedNumber = '$prefix-${invoiceNumber.toString().padLeft(4, '0')}';

    final invoice = Invoice(
      id: '',
      invoiceNumber: formattedNumber,
      issueDate: _draft!.issueDate,
      clientNaam: _draft!.clientNaam,
      clientKenteken: _draft!.clientKenteken,
      clientProductType: _draft!.clientProductType,
      clientKmstand: _draft!.clientKmstand,
      clientDatum: _draft!.clientDatum,
      clientAdres: _draft!.clientAdres,
      clientTelefoonnummer: _draft!.clientTelefoonnummer,
      businessName: _draft!.businessName,
      businessInvoicePrefix: _draft!.businessInvoicePrefix,
      businessKvk: _draft!.businessKvk,
      businessIban: _draft!.businessIban,
      businessPhone: _draft!.businessPhone,
      businessAddress: _draft!.businessAddress,
      businessCity: _draft!.businessCity,
      businessState: _draft!.businessState,
      businessZip: _draft!.businessZip,
      businessCountry: _draft!.businessCountry,
      businessWebsite: _draft!.businessWebsite,
      items: _draft!.items,
      notes: _draft!.notes,
      template: 'classic',
      status: 'concept',
      taxRate: _draft!.taxRate,
      currency: _draft!.currency,
      createdAt: DateTime.now(),
    );

    final savedId = await _firestore.saveInvoice(_userId!, invoice);
    final saved = Invoice(
      id: savedId,
      invoiceNumber: invoice.invoiceNumber,
      issueDate: invoice.issueDate,
      clientNaam: invoice.clientNaam,
      clientKenteken: invoice.clientKenteken,
      clientProductType: invoice.clientProductType,
      clientKmstand: invoice.clientKmstand,
      clientDatum: invoice.clientDatum,
      clientAdres: invoice.clientAdres,
      clientTelefoonnummer: invoice.clientTelefoonnummer,
      businessName: invoice.businessName,
      businessInvoicePrefix: invoice.businessInvoicePrefix,
      businessKvk: invoice.businessKvk,
      businessIban: invoice.businessIban,
      businessPhone: invoice.businessPhone,
      businessAddress: invoice.businessAddress,
      businessCity: invoice.businessCity,
      businessState: invoice.businessState,
      businessZip: invoice.businessZip,
      businessCountry: invoice.businessCountry,
      businessWebsite: invoice.businessWebsite,
      items: invoice.items,
      notes: invoice.notes,
      template: invoice.template,
      status: invoice.status,
      taxRate: invoice.taxRate,
      currency: invoice.currency,
      createdAt: invoice.createdAt,
    );

    _draft = null;
    notifyListeners();
    return saved;
  }

  void clearDraft() {
    _draft = null;
    notifyListeners();
  }

  Future<void> deleteInvoice(String invoiceId) async {
    if (_userId == null) return;
    await _firestore.deleteInvoice(_userId!, invoiceId);
  }

  Future<void> updateStatus(String invoiceId, String status) async {
    if (_userId == null) return;
    await _firestore.updateInvoiceStatus(_userId!, invoiceId, status);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
