class BusinessInfo {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String country;
  final String phone;
  final String kvk;
  final String iban;
  final String website;
  final String? logoBase64;
  final int nextInvoiceNumber;
  final String currency;
  final double defaultTaxRate;
  final String invoicePrefix;
  final String? defaultNotes;
  final String emailTemplate;
  final List<String> favoriteCategories;
  final List<String> categoryOrder;
  final String themeMode;

  const BusinessInfo({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.country = '',
    this.phone = '',
    this.kvk = '',
    this.iban = '',
    this.website = '',
    this.logoBase64,
    this.nextInvoiceNumber = 1,
    this.currency = '€',
    this.defaultTaxRate = 21.0,
    this.invoicePrefix = 'F',
    this.defaultNotes,
    this.emailTemplate = kDefaultEmailTemplate,
    this.favoriteCategories = const [],
    this.categoryOrder = const [],
    this.themeMode = 'system',
  });

  static const kDefaultEmailTemplate =
      'Beste {naam},\n\n'
      'Bijgevoegd vindt u factuur {factuur_nummer} {voertuig_info}.\n\n'
      'Heeft u vragen over deze factuur? Neem dan gerust contact met ons op.\n\n'
      'Met vriendelijke groet,\n'
      '{bedrijfsnaam}';

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
        'kvk': kvk,
        'iban': iban,
        'website': website,
        'logoBase64': logoBase64,
        'nextInvoiceNumber': nextInvoiceNumber,
        'currency': currency,
        'defaultTaxRate': defaultTaxRate,
        'invoicePrefix': invoicePrefix,
        'defaultNotes': defaultNotes,
        'emailTemplate': emailTemplate,
        'favoriteCategories': favoriteCategories,
        'categoryOrder': categoryOrder,
        'themeMode': themeMode,
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
        kvk: map['kvk'] ?? map['email'] ?? '',
        iban: map['iban'] ?? '',
        website: map['website'] ?? '',
        logoBase64: map['logoBase64'],
        nextInvoiceNumber: map['nextInvoiceNumber'] ?? 1,
        currency: map['currency'] ?? '€',
        defaultTaxRate: (map['defaultTaxRate'] ?? 21.0).toDouble(),
        invoicePrefix: map['invoicePrefix'] ?? 'F',
        defaultNotes: map['defaultNotes'],
        emailTemplate: map['emailTemplate'] ?? kDefaultEmailTemplate,
        favoriteCategories: List<String>.from(map['favoriteCategories'] ?? []),
        categoryOrder: List<String>.from(map['categoryOrder'] ?? []),
        themeMode: map['themeMode'] ?? 'system',
      );

  BusinessInfo copyWith({
    String? name,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? country,
    String? phone,
    String? kvk,
    String? iban,
    String? website,
    String? logoBase64,
    bool clearLogo = false,
    int? nextInvoiceNumber,
    String? currency,
    double? defaultTaxRate,
    String? invoicePrefix,
    String? defaultNotes,
    String? emailTemplate,
    List<String>? favoriteCategories,
    List<String>? categoryOrder,
    String? themeMode,
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
        kvk: kvk ?? this.kvk,
        iban: iban ?? this.iban,
        website: website ?? this.website,
        logoBase64: clearLogo ? null : (logoBase64 ?? this.logoBase64),
        nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
        currency: currency ?? this.currency,
        defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
        invoicePrefix: invoicePrefix ?? this.invoicePrefix,
        defaultNotes: defaultNotes ?? this.defaultNotes,
        emailTemplate: emailTemplate ?? this.emailTemplate,
        favoriteCategories: favoriteCategories ?? this.favoriteCategories,
        categoryOrder: categoryOrder ?? this.categoryOrder,
        themeMode: themeMode ?? this.themeMode,
      );
}
