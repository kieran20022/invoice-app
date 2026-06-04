class Client {
  final String id;
  final String name;
  final String company;
  final String email;
  final String phone;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String country;

  const Client({
    required this.id,
    required this.name,
    this.company = '',
    required this.email,
    this.phone = '',
    this.address = '',
    this.city = '',
    this.state = '',
    this.zip = '',
    this.country = '',
  });

  String get displayName => company.isNotEmpty ? '$name ($company)' : name;

  String get formattedAddress {
    final parts = [address, city, state, zip, country].where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'country': country,
      };

  factory Client.fromMap(String id, Map<String, dynamic> map) => Client(
        id: id,
        name: map['name'] ?? '',
        company: map['company'] ?? '',
        email: map['email'] ?? '',
        phone: map['phone'] ?? '',
        address: map['address'] ?? '',
        city: map['city'] ?? '',
        state: map['state'] ?? '',
        zip: map['zip'] ?? '',
        country: map['country'] ?? '',
      );

  Client copyWith({
    String? name,
    String? company,
    String? email,
    String? phone,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? country,
  }) =>
      Client(
        id: id,
        name: name ?? this.name,
        company: company ?? this.company,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        city: city ?? this.city,
        state: state ?? this.state,
        zip: zip ?? this.zip,
        country: country ?? this.country,
      );
}
