class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String unit;

  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.unit = 'item',
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'unit': unit,
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        price: (map['price'] ?? 0.0).toDouble(),
        unit: map['unit'] ?? 'item',
      );

  Product copyWith({
    String? name,
    String? description,
    double? price,
    String? unit,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        unit: unit ?? this.unit,
      );
}
