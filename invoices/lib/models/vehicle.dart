/// A vehicle currently in the shop, tied to the invoice being built for it.
class Vehicle {
  final String id;

  /// Owner's phone number as typed — mirrors the invoice's
  /// `clientTelefoonnummer`, and is what the direct WhatsApp send targets.
  final String phone;

  /// Owner's name — optional, mirrors the invoice's `clientNaam`. Empty when
  /// the vehicle was booked in on a phone number alone.
  final String name;

  /// Licence plate — mirrors the invoice's `clientKenteken`.
  final String plate;

  /// The invoice this vehicle's work is billed on. Tapping the vehicle opens
  /// it straight at the Producten step.
  final String invoiceId;

  final DateTime createdAt;

  const Vehicle({
    required this.id,
    required this.phone,
    this.name = '',
    required this.plate,
    required this.invoiceId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'phone': phone,
        'name': name,
        'plate': plate,
        'invoiceId': invoiceId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Vehicle.fromMap(String id, Map<String, dynamic> map) => Vehicle(
        id: id,
        phone: map['phone'] ?? '',
        // 'ownerName' is what the name was stored under before the phone
        // number became the primary field.
        name: map['name'] ?? map['ownerName'] ?? '',
        plate: map['plate'] ?? '',
        invoiceId: map['invoiceId'] ?? '',
        createdAt:
            DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      );

  Vehicle copyWith({
    String? phone,
    String? name,
    String? plate,
    String? invoiceId,
  }) =>
      Vehicle(
        id: id,
        phone: phone ?? this.phone,
        name: name ?? this.name,
        plate: plate ?? this.plate,
        invoiceId: invoiceId ?? this.invoiceId,
        createdAt: createdAt,
      );
}
