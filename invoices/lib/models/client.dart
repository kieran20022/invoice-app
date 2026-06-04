class Client {
  final String id;
  final String naam;
  final String kenteken;
  final String kmstand;
  final String datum;
  final String adres;
  final String telefoonnummer;

  const Client({
    required this.id,
    required this.naam,
    required this.kenteken,
    required this.kmstand,
    required this.datum,
    this.adres = '',
    this.telefoonnummer = '',
  });

  Map<String, dynamic> toMap() => {
        'naam': naam,
        'kenteken': kenteken,
        'kmstand': kmstand,
        'datum': datum,
        'adres': adres,
        'telefoonnummer': telefoonnummer,
      };

  factory Client.fromMap(String id, Map<String, dynamic> map) => Client(
        id: id,
        naam: map['naam'] ?? '',
        kenteken: map['kenteken'] ?? '',
        kmstand: map['kmstand'] ?? '',
        datum: map['datum'] ?? '',
        adres: map['adres'] ?? '',
        telefoonnummer: map['telefoonnummer'] ?? '',
      );

  Client copyWith({
    String? naam,
    String? kenteken,
    String? kmstand,
    String? datum,
    String? adres,
    String? telefoonnummer,
  }) =>
      Client(
        id: id,
        naam: naam ?? this.naam,
        kenteken: kenteken ?? this.kenteken,
        kmstand: kmstand ?? this.kmstand,
        datum: datum ?? this.datum,
        adres: adres ?? this.adres,
        telefoonnummer: telefoonnummer ?? this.telefoonnummer,
      );
}
