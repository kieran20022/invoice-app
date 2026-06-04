class InvoiceItem {
  final String id;
  final String name;
  final String description;
  final double quantity;
  final double unitPrice;
  final String unit;
  final String? productId;

  const InvoiceItem({
    required this.id,
    required this.name,
    this.description = '',
    required this.quantity,
    required this.unitPrice,
    this.unit = 'item',
    this.productId,
  });

  double get total => quantity * unitPrice;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'unit': unit,
        'productId': productId,
      };

  factory InvoiceItem.fromMap(Map<String, dynamic> map) => InvoiceItem(
        id: map['id'] ?? '',
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        quantity: (map['quantity'] ?? 1.0).toDouble(),
        unitPrice: (map['unitPrice'] ?? 0.0).toDouble(),
        unit: map['unit'] ?? 'item',
        productId: map['productId'],
      );

  InvoiceItem copyWith({
    String? name,
    String? description,
    double? quantity,
    double? unitPrice,
    String? unit,
  }) =>
      InvoiceItem(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        unit: unit ?? this.unit,
        productId: productId,
      );
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;

  // Client snapshot
  final String clientName;
  final String clientCompany;
  final String clientEmail;
  final String clientPhone;
  final String clientAddress;
  final String clientCity;
  final String clientState;
  final String clientZip;
  final String clientCountry;

  // Business snapshot
  final String businessName;
  final String businessEmail;
  final String businessPhone;
  final String businessAddress;
  final String businessCity;
  final String businessState;
  final String businessZip;
  final String businessCountry;
  final String? businessLogoUrl;
  final String businessWebsite;

  final List<InvoiceItem> items;
  final String notes;
  final String terms;
  final String template;
  final String status;
  final double taxRate;
  final String currency;
  final DateTime createdAt;

  const Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.clientName,
    this.clientCompany = '',
    required this.clientEmail,
    this.clientPhone = '',
    this.clientAddress = '',
    this.clientCity = '',
    this.clientState = '',
    this.clientZip = '',
    this.clientCountry = '',
    required this.businessName,
    required this.businessEmail,
    this.businessPhone = '',
    this.businessAddress = '',
    this.businessCity = '',
    this.businessState = '',
    this.businessZip = '',
    this.businessCountry = '',
    this.businessLogoUrl,
    this.businessWebsite = '',
    required this.items,
    this.notes = '',
    this.terms = 'Net 30',
    this.template = 'modern',
    this.status = 'draft',
    this.taxRate = 0.0,
    this.currency = '\$',
    required this.createdAt,
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  double get taxAmount => subtotal * (taxRate / 100);
  double get total => subtotal + taxAmount;

  String get clientFormattedAddress {
    final parts = [clientAddress, clientCity, clientState, clientZip, clientCountry]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  String get businessFormattedAddress {
    final parts = [businessAddress, businessCity, businessState, businessZip, businessCountry]
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
        'invoiceNumber': invoiceNumber,
        'issueDate': issueDate.toIso8601String(),
        'dueDate': dueDate.toIso8601String(),
        'clientName': clientName,
        'clientCompany': clientCompany,
        'clientEmail': clientEmail,
        'clientPhone': clientPhone,
        'clientAddress': clientAddress,
        'clientCity': clientCity,
        'clientState': clientState,
        'clientZip': clientZip,
        'clientCountry': clientCountry,
        'businessName': businessName,
        'businessEmail': businessEmail,
        'businessPhone': businessPhone,
        'businessAddress': businessAddress,
        'businessCity': businessCity,
        'businessState': businessState,
        'businessZip': businessZip,
        'businessCountry': businessCountry,
        'businessLogoUrl': businessLogoUrl,
        'businessWebsite': businessWebsite,
        'items': items.map((i) => i.toMap()).toList(),
        'notes': notes,
        'terms': terms,
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
        dueDate: DateTime.parse(map['dueDate'] ?? DateTime.now().toIso8601String()),
        clientName: map['clientName'] ?? '',
        clientCompany: map['clientCompany'] ?? '',
        clientEmail: map['clientEmail'] ?? '',
        clientPhone: map['clientPhone'] ?? '',
        clientAddress: map['clientAddress'] ?? '',
        clientCity: map['clientCity'] ?? '',
        clientState: map['clientState'] ?? '',
        clientZip: map['clientZip'] ?? '',
        clientCountry: map['clientCountry'] ?? '',
        businessName: map['businessName'] ?? '',
        businessEmail: map['businessEmail'] ?? '',
        businessPhone: map['businessPhone'] ?? '',
        businessAddress: map['businessAddress'] ?? '',
        businessCity: map['businessCity'] ?? '',
        businessState: map['businessState'] ?? '',
        businessZip: map['businessZip'] ?? '',
        businessCountry: map['businessCountry'] ?? '',
        businessLogoUrl: map['businessLogoUrl'],
        businessWebsite: map['businessWebsite'] ?? '',
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) => InvoiceItem.fromMap(i as Map<String, dynamic>))
            .toList(),
        notes: map['notes'] ?? '',
        terms: map['terms'] ?? 'Net 30',
        template: map['template'] ?? 'modern',
        status: map['status'] ?? 'draft',
        taxRate: (map['taxRate'] ?? 0.0).toDouble(),
        currency: map['currency'] ?? '\$',
        createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      );

  Invoice copyWith({
    String? invoiceNumber,
    DateTime? issueDate,
    DateTime? dueDate,
    String? clientName,
    String? clientCompany,
    String? clientEmail,
    String? clientPhone,
    String? clientAddress,
    String? clientCity,
    String? clientState,
    String? clientZip,
    String? clientCountry,
    List<InvoiceItem>? items,
    String? notes,
    String? terms,
    String? template,
    String? status,
    double? taxRate,
    String? currency,
  }) =>
      Invoice(
        id: id,
        invoiceNumber: invoiceNumber ?? this.invoiceNumber,
        issueDate: issueDate ?? this.issueDate,
        dueDate: dueDate ?? this.dueDate,
        clientName: clientName ?? this.clientName,
        clientCompany: clientCompany ?? this.clientCompany,
        clientEmail: clientEmail ?? this.clientEmail,
        clientPhone: clientPhone ?? this.clientPhone,
        clientAddress: clientAddress ?? this.clientAddress,
        clientCity: clientCity ?? this.clientCity,
        clientState: clientState ?? this.clientState,
        clientZip: clientZip ?? this.clientZip,
        clientCountry: clientCountry ?? this.clientCountry,
        businessName: businessName,
        businessEmail: businessEmail,
        businessPhone: businessPhone,
        businessAddress: businessAddress,
        businessCity: businessCity,
        businessState: businessState,
        businessZip: businessZip,
        businessCountry: businessCountry,
        businessLogoUrl: businessLogoUrl,
        businessWebsite: businessWebsite,
        items: items ?? this.items,
        notes: notes ?? this.notes,
        terms: terms ?? this.terms,
        template: template ?? this.template,
        status: status ?? this.status,
        taxRate: taxRate ?? this.taxRate,
        currency: currency ?? this.currency,
        createdAt: createdAt,
      );
}
