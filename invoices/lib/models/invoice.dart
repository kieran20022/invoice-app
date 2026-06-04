class InvoiceItem {
  final String id;
  final String omschrijving;
  final double aantal;
  final double prijsExBtw;
  final String? productId;

  const InvoiceItem({
    required this.id,
    required this.omschrijving,
    required this.aantal,
    required this.prijsExBtw,
    this.productId,
  });

  double prijsInclBtw(double taxRate) => prijsExBtw * (1 + taxRate / 100);
  double totalExBtw() => aantal * prijsExBtw;
  double totalInclBtw(double taxRate) => aantal * prijsInclBtw(taxRate);

  Map<String, dynamic> toMap() => {
        'id': id,
        'omschrijving': omschrijving,
        'aantal': aantal,
        'prijsExBtw': prijsExBtw,
        'productId': productId,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] ?? '',
        omschrijving: map['omschrijving'] ?? map['name'] ?? '',
        aantal: (map['aantal'] ?? map['quantity'] ?? 1.0).toDouble(),
        prijsExBtw: (map['prijsExBtw'] ?? map['unitPrice'] ?? 0.0).toDouble(),
        productId: map['productId'],
      );

  InvoiceItem copyWith({
    String? omschrijving,
    double? aantal,
    double? prijsExBtw,
  }) =>
      InvoiceItem(
        id: id,
        omschrijving: omschrijving ?? this.omschrijving,
        aantal: aantal ?? this.aantal,
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
  final String clientKmstand;
  final String clientDatum;
  final String clientAdres;
  final String clientTelefoonnummer;

  // Business snapshot
  final String businessName;
  final String businessEmail;
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

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.clientNaam,
    this.clientKenteken = '',
    this.clientKmstand = '',
    this.clientDatum = '',
    this.clientAdres = '',
    this.clientTelefoonnummer = '',
    required this.businessName,
    required this.businessEmail,
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
  });

  double get subtotaalExBtw => items.fold(0, (s, i) => s + i.totalExBtw());
  double get btwBedrag => subtotaalExBtw * (taxRate / 100);
  double get totaalInclBtw => subtotaalExBtw + btwBedrag;

  // Legacy alias used in PDF/email formatting
  double get total => totaalInclBtw;

  String get pdfFilename =>
      'Factuur $invoiceNumber - $clientKenteken.pdf';

  Map<String, dynamic> toMap() => {
        'invoiceNumber': invoiceNumber,
        'issueDate': issueDate.toIso8601String(),
        'clientNaam': clientNaam,
        'clientKenteken': clientKenteken,
        'clientKmstand': clientKmstand,
        'clientDatum': clientDatum,
        'clientAdres': clientAdres,
        'clientTelefoonnummer': clientTelefoonnummer,
        'businessName': businessName,
        'businessEmail': businessEmail,
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
      };

  factory Invoice.fromMap(String id, Map<String, dynamic> map) => Invoice(
        id: id,
        invoiceNumber: map['invoiceNumber'] ?? '',
        issueDate: DateTime.parse(map['issueDate'] ?? DateTime.now().toIso8601String()),
        clientNaam: map['clientNaam'] ?? map['clientName'] ?? '',
        clientKenteken: map['clientKenteken'] ?? '',
        clientKmstand: map['clientKmstand'] ?? '',
        clientDatum: map['clientDatum'] ?? '',
        clientAdres: map['clientAdres'] ?? map['clientAddress'] ?? '',
        clientTelefoonnummer: map['clientTelefoonnummer'] ?? map['clientPhone'] ?? '',
        businessName: map['businessName'] ?? '',
        businessEmail: map['businessEmail'] ?? '',
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
      );

  Invoice copyWith({
    String? invoiceNumber,
    DateTime? issueDate,
    String? clientNaam,
    String? clientKenteken,
    String? clientKmstand,
    String? clientDatum,
    String? clientAdres,
    String? clientTelefoonnummer,
    List<InvoiceItem>? items,
    String? notes,
    String? template,
    String? status,
    double? taxRate,
    String? currency,
  }) =>
      Invoice(
        id: id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        issueDate: issueDate ?? this.issueDate,
        clientNaam: clientNaam ?? this.clientNaam,
        clientKenteken: clientKenteken ?? this.clientKenteken,
        clientKmstand: clientKmstand ?? this.clientKmstand,
        clientDatum: clientDatum ?? this.clientDatum,
        clientAdres: clientAdres ?? this.clientAdres,
        clientTelefoonnummer: clientTelefoonnummer ?? this.clientTelefoonnummer,
        businessName: businessName,
        businessEmail: businessEmail,
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
      );
}
