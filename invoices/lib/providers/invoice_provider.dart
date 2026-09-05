import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/business_info.dart';
import '../services/firestore_service.dart';

class InvoiceProvider extends ChangeNotifier {
  /// Status of an invoice still being built up for a vehicle in the shop.
  /// These are held back from the Facturen tab until the vehicle leaves the
  /// workshop, so a job in progress does not sit among finished invoices.
  static const workshopStatus = 'werkplaats';

  final FirestoreService _firestore = FirestoreService();
  final _uuid = const Uuid();

  List<Invoice> _all = [];
  List<Invoice> _visible = [];
  bool _isLoaded = false;
  String? _userId;
  StreamSubscription<List<Invoice>>? _sub;

  Invoice? _draft;

  /// Invoices the Facturen tab shows — everything outside the workshop buffer.
  List<Invoice> get invoices => _visible;

  /// Every invoice, buffer included. The Voertuigen tab needs this to find a
  /// vehicle's invoice by id while it is still buffered.
  List<Invoice> get allInvoices => _all;

  bool get isLoaded => _isLoaded;
  Invoice? get draft => _draft;

  void setUserId(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _sub?.cancel();
    _all = [];
    _visible = [];
    _isLoaded = false;

    if (userId == null) {
      notifyListeners();
      return;
    }

    _sub = _firestore.invoicesStream(userId).listen(
      (invoices) {
        _all = invoices;
        _visible =
            invoices.where((i) => i.status != workshopStatus).toList();
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

  /// [isQuote] starts an offerte instead of an invoice: it numbers from the
  /// quote sequence and carries no payment state.
  void startNewDraft(BusinessInfo business, {bool isQuote = false}) {
    final now = DateTime.now();
    _draft = Invoice(
      id: '',
      invoiceNumber: '',
      issueDate: now,
      clientNaam: '',
      businessName: business.name,
      // The draft carries the prefix its own sequence uses, so numbering only
      // has to pick the right counter.
      businessInvoicePrefix:
          isQuote ? business.quotePrefix : business.invoicePrefix,
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
      isQuote: isQuote,
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
    bool? isDamageReport,
  }) {
    if (_draft == null) return;
    _draft = _draft!.copyWith(
      notes: notes,
      taxRate: taxRate,
      issueDate: issueDate,
      currency: currency,
      isDamageReport: isDamageReport,
    );
    notifyListeners();
  }

  InvoiceItem createItem({
    String? omschrijving,
    double aantal = 1,
    double? aantalTot,
    double prijsExBtw = 0,
    String? productId,
  }) =>
      InvoiceItem(
        id: _uuid.v4(),
        omschrijving: omschrijving ?? '',
        aantal: aantal,
        aantalTot: aantalTot,
        prijsExBtw: prijsExBtw,
        productId: productId,
      );

  /// Saves the draft. [status] applies only to a newly created invoice — an
  /// existing one keeps the status it already carries.
  Future<Invoice> saveDraft({String status = 'concept'}) async {
    if (_userId == null || _draft == null) throw Exception('Geen concept of gebruiker');

    if (_draft!.id.isNotEmpty) {
      await _firestore.saveInvoice(_userId!, _draft!);
      final saved = _draft!;
      _draft = null;
      notifyListeners();
      return saved;
    }

    // A workshop invoice does not take a number yet: it only becomes a real
    // invoice — and consumes the next number — when the vehicle leaves the
    // shop. Numbering it here would burn numbers on jobs that may sit in the
    // buffer for days, leaving gaps in the Facturen tab's sequence.
    final formattedNumber = status == workshopStatus
        ? ''
        : _draft!.isQuote
            ? await _nextQuoteNumber(_draft!.businessInvoicePrefix)
            : await _nextInvoiceNumber(_draft!.businessInvoicePrefix);

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
      status: status,
      taxRate: _draft!.taxRate,
      currency: _draft!.currency,
      createdAt: DateTime.now(),
      isQuote: _draft!.isQuote,
      isDamageReport: _draft!.isDamageReport,
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
      isQuote: invoice.isQuote,
      isDamageReport: invoice.isDamageReport,
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

  /// Formats and consumes the next invoice number for [prefix].
  Future<String> _nextInvoiceNumber(String businessInvoicePrefix) async {
    final number = await _firestore.incrementAndGetInvoiceNumber(_userId!);
    return _format(businessInvoicePrefix, number, 'F');
  }

  /// Formats and consumes the next quote number, which runs its own sequence.
  Future<String> _nextQuoteNumber(String quotePrefix) async {
    final number = await _firestore.incrementAndGetQuoteNumber(_userId!);
    return _format(quotePrefix, number, 'OFF');
  }

  String _format(String prefix, int number, String fallback) =>
      '${prefix.isEmpty ? fallback : prefix}-'
      '${number.toString().padLeft(4, '0')}';

  /// Releases a vehicle's invoice from the workshop buffer into the Facturen
  /// tab, assigning its invoice number at that moment. Returns the numbered
  /// invoice — callers that share it straight away need the new number.
  Future<Invoice> releaseFromWorkshop(Invoice invoice) async {
    if (_userId == null || invoice.status != workshopStatus) return invoice;

    final released = invoice.copyWith(
      status: 'concept',
      invoiceNumber: invoice.invoiceNumber.isEmpty
          ? await _nextInvoiceNumber(invoice.businessInvoicePrefix)
          : invoice.invoiceNumber,
    );
    await _firestore.saveInvoice(_userId!, released);
    return released;
  }

  /// Turns a quote into a real invoice: it takes the next invoice number and
  /// drops its quote wording. [quantities] gives the settled amount per item
  /// id — an invoice bills an exact quantity, so every estimated range has to
  /// be pinned down before the document can be billed.
  Future<Invoice> convertToInvoice(
    Invoice quote, {
    required String invoicePrefix,
    Map<String, double> quantities = const {},
  }) async {
    if (_userId == null || !quote.isQuote) return quote;

    final items = quote.items.map((item) {
      final settled = quantities[item.id] ?? item.aantal;
      return item.copyWith(aantal: settled, clearAantalTot: true);
    }).toList();

    final invoice = quote.copyWith(
      items: items,
      isQuote: false,
      // The snapshot carried the quote sequence's prefix; it now belongs to
      // the invoice sequence.
      businessInvoicePrefix: invoicePrefix,
      isDamageReport: false,
      status: 'concept',
      invoiceNumber: await _nextInvoiceNumber(invoicePrefix),
    );
    await _firestore.saveInvoice(_userId!, invoice);
    return invoice;
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
