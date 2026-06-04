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

  // Draft state for invoice being created
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

  void startNewDraft(BusinessInfo business) {
    final now = DateTime.now();
    _draft = Invoice(
      id: '',
      invoiceNumber: '',
      issueDate: now,
      dueDate: now.add(const Duration(days: 30)),
      clientName: '',
      clientEmail: '',
      businessName: business.name,
      businessEmail: business.email,
      businessPhone: business.phone,
      businessAddress: business.address,
      businessCity: business.city,
      businessState: business.state,
      businessZip: business.zip,
      businessCountry: business.country,
      businessLogoUrl: business.logoUrl,
      businessWebsite: business.website,
      items: const [],
      notes: business.defaultNotes ?? '',
      terms: business.defaultPaymentTerms,
      template: 'modern',
      taxRate: business.defaultTaxRate,
      currency: business.currency,
      createdAt: now,
    );
    notifyListeners();
  }

  void updateDraftClient({
    String? name,
    String? company,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? country,
  }) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(
      clientName: name,
      clientCompany: company,
      clientEmail: email,
      clientPhone: phone,
      clientAddress: address,
      clientCity: city,
      clientState: state,
      clientZip: zip,
      clientCountry: country,
    );
    notifyListeners();
  }

  void updateDraftTemplate(String template) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(template: template);
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
    String? terms,
    double? taxRate,
    DateTime? issueDate,
    DateTime? dueDate,
    String? currency,
  }) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(
      notes: notes,
      terms: terms,
      taxRate: taxRate,
      issueDate: issueDate,
      dueDate: dueDate,
      currency: currency,
    );
    notifyListeners();
  }

  InvoiceItem createItem({
    String? name,
    String? description,
    double quantity = 1,
    double unitPrice = 0,
    String unit = 'item',
    String? productId,
  }) =>
      InvoiceItem(
        id: _uuid.v4(),
        name: name ?? '',
        description: description ?? '',
        quantity: quantity,
        unitPrice: unitPrice,
        unit: unit,
        productId: productId,
      );

  Future<Invoice> saveDraft() async {
    if (_userId == null || _draft == null) throw Exception('No draft or user');

    final invoiceNumber = await _firestore.incrementAndGetInvoiceNumber(_userId!);
    final formattedNumber = 'INV-${invoiceNumber.toString().padLeft(4, '0')}';

    final invoice = Invoice(
      id: '',
      invoiceNumber: formattedNumber,
      issueDate: _draft!.issueDate,
      dueDate: _draft!.dueDate,
      clientName: _draft!.clientName,
      clientCompany: _draft!.clientCompany,
      clientEmail: _draft!.clientEmail,
      clientPhone: _draft!.clientPhone,
      clientAddress: _draft!.clientAddress,
      clientCity: _draft!.clientCity,
      clientState: _draft!.clientState,
      clientZip: _draft!.clientZip,
      clientCountry: _draft!.clientCountry,
      businessName: _draft!.businessName,
      businessEmail: _draft!.businessEmail,
      businessPhone: _draft!.businessPhone,
      businessAddress: _draft!.businessAddress,
      businessCity: _draft!.businessCity,
      businessState: _draft!.businessState,
      businessZip: _draft!.businessZip,
      businessCountry: _draft!.businessCountry,
      businessLogoUrl: _draft!.businessLogoUrl,
      businessWebsite: _draft!.businessWebsite,
      items: _draft!.items,
      notes: _draft!.notes,
      terms: _draft!.terms,
      template: _draft!.template,
      status: 'draft',
      taxRate: _draft!.taxRate,
      currency: _draft!.currency,
      createdAt: DateTime.now(),
    );

    final savedId = await _firestore.saveInvoice(_userId!, invoice);
    final savedInvoice = Invoice(
      id: savedId,
      invoiceNumber: invoice.invoiceNumber,
      issueDate: invoice.issueDate,
      dueDate: invoice.dueDate,
      clientName: invoice.clientName,
      clientCompany: invoice.clientCompany,
      clientEmail: invoice.clientEmail,
      clientPhone: invoice.clientPhone,
      clientAddress: invoice.clientAddress,
      clientCity: invoice.clientCity,
      clientState: invoice.clientState,
      clientZip: invoice.clientZip,
      clientCountry: invoice.clientCountry,
      businessName: invoice.businessName,
      businessEmail: invoice.businessEmail,
      businessPhone: invoice.businessPhone,
      businessAddress: invoice.businessAddress,
      businessCity: invoice.businessCity,
      businessState: invoice.businessState,
      businessZip: invoice.businessZip,
      businessCountry: invoice.businessCountry,
      businessLogoUrl: invoice.businessLogoUrl,
      businessWebsite: invoice.businessWebsite,
      items: invoice.items,
      notes: invoice.notes,
      terms: invoice.terms,
      template: invoice.template,
      status: invoice.status,
      taxRate: invoice.taxRate,
      currency: invoice.currency,
      createdAt: invoice.createdAt,
    );

    _draft = null;
    notifyListeners();
    return savedInvoice;
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
