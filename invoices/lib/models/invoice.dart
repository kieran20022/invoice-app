class InvoiceItem {
  final String id;
  final String omschrijving;
  final double aantal;

  /// Upper bound of an estimated quantity ("1-4 uur"). Only quotes set this;
  /// `null` means the quantity is exact, so [aantal] is both bounds.
  final double? aantalTot;
  final double prijsExBtw;
  final String? productId;

  const InvoiceItem({
    required this.id,
    required this.omschrijving,
    required this.aantal,
    this.aantalTot,
    required this.prijsExBtw,
    this.productId,
  });

  /// A range only counts as one when its upper bound is actually higher.
  bool get isRange => aantalTot != null && aantalTot! > aantal;
  double get aantalMax => isRange ? aantalTot! : aantal;

  String get aantalLabel =>
      isRange ? '${_fmtQty(aantal)}-${_fmtQty(aantalMax)}' : _fmtQty(aantal);

  double prijsInclBtw(double taxRate) => prijsExBtw * (1 + taxRate / 100);
  double totalExBtw() => aantal * prijsExBtw;
  double totalInclBtw(double taxRate) => aantal * prijsInclBtw(taxRate);
  double totalExBtwMax() => aantalMax * prijsExBtw;
  double totalInclBtwMax(double taxRate) => aantalMax * prijsInclBtw(taxRate);

  static String _fmtQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();

  Map<String, dynamic> toMap() => {
        'id': id,
        'omschrijving': omschrijving,
        'aantal': aantal,
        'aantalTot': aantalTot,
        'prijsExBtw': prijsExBtw,
        'productId': productId,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] ?? '',
        omschrijving: map['omschrijving'] ?? map['name'] ?? '',
        aantal: (map['aantal'] ?? map['quantity'] ?? 1.0).toDouble(),
        aantalTot: (map['aantalTot'] as num?)?.toDouble(),
        prijsExBtw: (map['prijsExBtw'] ?? map['unitPrice'] ?? 0.0).toDouble(),
        productId: map['productId'],
      );

  InvoiceItem copyWith({
    String? omschrijving,
    double? aantal,
    double? aantalTot,
    bool clearAantalTot = false,
    double? prijsExBtw,
  }) =>
      InvoiceItem(
        id: id,
        omschrijving: omschrijving ?? this.omschrijving,
        aantal: aantal ?? this.aantal,
        aantalTot: clearAantalTot ? null : (aantalTot ?? this.aantalTot),
        prijsExBtw: prijsExBtw ?? this.prijsExBtw,
        productId: productId,
      );
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final DateTime issueDate;

  // Client snapshot
  final String clientNaam;
  final String clientKenteken;
  final String clientProductType;
  final String clientKmstand;
  final String clientDatum;
  final String clientAdres;
  final String clientTelefoonnummer;

  // Business snapshot
  final String businessName;
  final String businessInvoicePrefix;
  final String businessKvk;
  final String businessIban;
  final String businessPhone;
  final String businessAddress;
  final String businessCity;
  final String businessState;
  final String businessZip;
  final String businessCountry;
  final String businessWebsite;

  final List<InvoiceItem> items;
  final String notes;
  final String template;
  final String status;
  final double taxRate;
  final String currency;
  final DateTime createdAt;

  /// A quote ("offerte") rather than an invoice: same document, but it is not
  /// owed yet — it carries no payment state and its items may be estimated as
  /// ranges.
  final bool isQuote;

  /// A quote issued as a damage report. Only the wording differs — the
  /// document is built, numbered and shared exactly like any other offerte.
  final bool isDamageReport;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.clientNaam,
    this.clientKenteken = '',
    this.clientProductType = '',
    this.clientKmstand = '',
    this.clientDatum = '',
    this.clientAdres = '',
    this.clientTelefoonnummer = '',
    required this.businessName,
    this.businessInvoicePrefix = 'F',
    this.businessKvk = '',
    this.businessIban = '',
    this.businessPhone = '',
    this.businessAddress = '',
    this.businessCity = '',
    this.businessState = '',
    this.businessZip = '',
    this.businessCountry = '',
    this.businessWebsite = '',
    required this.items,
    this.notes = '',
    this.template = 'classic',
    this.status = 'concept',
    this.taxRate = 21.0,
    this.currency = '€',
    required this.createdAt,
    this.isQuote = false,
    this.isDamageReport = false,
  });

  double get subtotaalExBtw => items.fold(0, (s, i) => s + i.totalExBtw());
  double get btwBedrag => subtotaalExBtw * (taxRate / 100);
  double get totaalInclBtw => subtotaalExBtw + btwBedrag;

  /// Upper bound of the totals. Equal to the plain totals unless an item was
  /// estimated as a range, in which case the document quotes a span.
  double get subtotaalExBtwMax => items.fold(0, (s, i) => s + i.totalExBtwMax());
  double get btwBedragMax => subtotaalExBtwMax * (taxRate / 100);
  double get totaalInclBtwMax => subtotaalExBtwMax + btwBedragMax;

  bool get hasRange => items.any((i) => i.isRange);

  /// What this document is called — used in titles, dialogs, the PDF and the
  /// shared filename.
  String get documentLabel => !isQuote
      ? 'Factuur'
      : isDamageReport
          ? 'Schaderapport'
          : 'Offerte';

  /// Same, shortened for the tight badge on an invoice card, where
  /// "Schaderapport" runs past the row.
  String get shortDocumentLabel =>
      isQuote && isDamageReport ? 'Rapport' : documentLabel;

  // Legacy alias used in PDF/email formatting
  double get total => totaalInclBtw;

  /// Invoice number for display. A vehicle still in the workshop has no number
  /// yet — it only gets one when it leaves the shop.
  String get numberLabel => invoiceNumber.isEmpty ? 'Concept' : invoiceNumber;

  /// Filename of the shared PDF. An invoice leads with its number; a quote
  /// leads with what it is, since a customer recognises
  /// "Offerte - Jan - AB-12-CD" more readily than a sequence number.
  String get pdfFilename {
    final ref = clientKenteken.isNotEmpty ? clientKenteken : clientProductType;
    final parts = isQuote
        ? [documentLabel, clientNaam, ref]
        : [numberLabel, ref];
    return '${parts.map(_sanitizeFilenamePart).where((p) => p.isNotEmpty).join(' - ')}.pdf';
  }

  /// Strips what a file name cannot carry, so a client reference with a slash
  /// in it does not produce a path.
  static String _sanitizeFilenamePart(String part) => part
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Map<String, dynamic> toMap() => {
        'invoiceNumber': invoiceNumber,
        'issueDate': issueDate.toIso8601String(),
        'clientNaam': clientNaam,
        'clientKenteken': clientKenteken,
        'clientProductType': clientProductType,
        'clientKmstand': clientKmstand,
        'clientDatum': clientDatum,
        'clientAdres': clientAdres,
        'clientTelefoonnummer': clientTelefoonnummer,
        'businessName': businessName,
        'businessInvoicePrefix': businessInvoicePrefix,
        'businessKvk': businessKvk,
        'businessIban': businessIban,
        'businessPhone': businessPhone,
        'businessAddress': businessAddress,
        'businessCity': businessCity,
        'businessState': businessState,
        'businessZip': businessZip,
        'businessCountry': businessCountry,
        'businessWebsite': businessWebsite,
        'items': items.map((i) => i.toMap()).toList(),
        'notes': notes,
        'template': template,
        'status': status,
        'taxRate': taxRate,
        'currency': currency,
        'createdAt': createdAt.toIso8601String(),
        'isQuote': isQuote,
        'isDamageReport': isDamageReport,
      };

  factory Invoice.fromMap(String id, Map<String, dynamic> map) => Invoice(
        id: id,
        invoiceNumber: map['invoiceNumber'] ?? '',
        issueDate: DateTime.parse(map['issueDate'] ?? DateTime.now().toIso8601String()),
        clientNaam: map['clientNaam'] ?? map['clientName'] ?? '',
        clientKenteken: map['clientKenteken'] ?? '',
        clientProductType: map['clientProductType'] ?? '',
        clientKmstand: map['clientKmstand'] ?? '',
        clientDatum: map['clientDatum'] ?? '',
        clientAdres: map['clientAdres'] ?? map['clientAddress'] ?? '',
        clientTelefoonnummer: map['clientTelefoonnummer'] ?? map['clientPhone'] ?? '',
        businessName: map['businessName'] ?? '',
        businessInvoicePrefix: map['businessInvoicePrefix'] ?? 'F',
        businessKvk: map['businessKvk'] ?? map['businessEmail'] ?? '',
        businessIban: map['businessIban'] ?? '',
        businessPhone: map['businessPhone'] ?? '',
        businessAddress: map['businessAddress'] ?? '',
        businessCity: map['businessCity'] ?? '',
        businessState: map['businessState'] ?? '',
        businessZip: map['businessZip'] ?? '',
        businessCountry: map['businessCountry'] ?? '',
        businessWebsite: map['businessWebsite'] ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) => InvoiceItem.fromMap(i as Map<String, dynamic>))
            .toList(),
        notes: map['notes'] ?? '',
        template: map['template'] ?? 'classic',
        status: map['status'] ?? 'concept',
        taxRate: (map['taxRate'] ?? 21.0).toDouble(),
        currency: map['currency'] ?? '€',
        createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
        isQuote: map['isQuote'] == true,
        isDamageReport: map['isDamageReport'] == true,
      );

  Invoice copyWith({
    String? invoiceNumber,
    DateTime? issueDate,
    String? clientNaam,
    String? clientKenteken,
    String? clientProductType,
    String? clientKmstand,
    String? clientDatum,
    String? clientAdres,
    String? clientTelefoonnummer,
    String? businessInvoicePrefix,
    List<InvoiceItem>? items,
    String? notes,
    String? template,
    String? status,
    double? taxRate,
    String? currency,
    bool? isQuote,
    bool? isDamageReport,
  }) =>
      Invoice(
        id: id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        issueDate: issueDate ?? this.issueDate,
        clientNaam: clientNaam ?? this.clientNaam,
        clientKenteken: clientKenteken ?? this.clientKenteken,
        clientProductType: clientProductType ?? this.clientProductType,
        clientKmstand: clientKmstand ?? this.clientKmstand,
        clientDatum: clientDatum ?? this.clientDatum,
        clientAdres: clientAdres ?? this.clientAdres,
        clientTelefoonnummer: clientTelefoonnummer ?? this.clientTelefoonnummer,
        businessName: businessName,
        businessInvoicePrefix:
            businessInvoicePrefix ?? this.businessInvoicePrefix,
        businessKvk: businessKvk,
        businessIban: businessIban,
        businessPhone: businessPhone,
        businessAddress: businessAddress,
        businessCity: businessCity,
        businessState: businessState,
        businessZip: businessZip,
        businessCountry: businessCountry,
        businessWebsite: businessWebsite,
        items: items ?? this.items,
        notes: notes ?? this.notes,
        template: template ?? this.template,
        status: status ?? this.status,
        taxRate: taxRate ?? this.taxRate,
        currency: currency ?? this.currency,
        createdAt: createdAt,
        isQuote: isQuote ?? this.isQuote,
        isDamageReport: isDamageReport ?? this.isDamageReport,
      );
}
