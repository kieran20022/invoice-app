class BusinessInfo {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String phone;
  final String email;
  final String website;
  final String? logoUrl;
  final int nextInvoiceNumber;
  final String currency;
  final double defaultTaxRate;
  final String invoicePrefix;
  final String defaultPaymentTerms;
  final String? defaultNotes;

  const BusinessInfo({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.country = '',
    this.phone = '',
    required this.email,
    this.website = '',
    this.logoUrl,
    this.nextInvoiceNumber = 1,
    this.currency = '\$',
    this.defaultTaxRate = 0.0,
    this.invoicePrefix = 'INV',
    this.defaultPaymentTerms = 'Net 30',
    this.defaultNotes,
  });

  String get formattedAddress {
    final parts = [address, city, state, zip, country].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  String invoiceNumberFormatted(int number) =>
      '$invoicePrefix-${number.toString().padLeft(4, '0')}';

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
        'phone': phone,
        'email': email,
        'website': website,
        'logoUrl': logoUrl,
        'nextInvoiceNumber': nextInvoiceNumber,
        'currency': currency,
        'defaultTaxRate': defaultTaxRate,
        'invoicePrefix': invoicePrefix,
        'defaultPaymentTerms': defaultPaymentTerms,
        'defaultNotes': defaultNotes,
      };

  factory BusinessInfo.fromMap(String id, Map<String, dynamic> map) => BusinessInfo(
        id: id,
        name: map['name'] ?? '',
        address: map['address'] ?? '',
        city: map['city'] ?? '',
        state: map['state'] ?? '',
        zip: map['zip'] ?? '',
        country: map['country'] ?? '',
        phone: map['phone'] ?? '',
        email: map['email'] ?? '',
        website: map['website'] ?? '',
        logoUrl: map['logoUrl'],
        nextInvoiceNumber: map['nextInvoiceNumber'] ?? 1,
        currency: map['currency'] ?? '\$',
        defaultTaxRate: (map['defaultTaxRate'] ?? 0.0).toDouble(),
        invoicePrefix: map['invoicePrefix'] ?? 'INV',
        defaultPaymentTerms: map['defaultPaymentTerms'] ?? 'Net 30',
        defaultNotes: map['defaultNotes'],
      );

  BusinessInfo copyWith({
    String? name,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? country,
    String? phone,
    String? email,
    String? website,
    String? logoUrl,
    int? nextInvoiceNumber,
    String? currency,
    double? defaultTaxRate,
    String? invoicePrefix,
    String? defaultPaymentTerms,
    String? defaultNotes,
  }) =>
      BusinessInfo(
        id: id,
        name: name ?? this.name,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        zip: zip ?? this.zip,
        country: country ?? this.country,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        website: website ?? this.website,
        logoUrl: logoUrl ?? this.logoUrl,
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        currency: currency ?? this.currency,
        defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
        defaultNotes: defaultNotes ?? this.defaultNotes,
      );
}
