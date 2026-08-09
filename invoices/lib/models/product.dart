class Product {
  /// Products that have never been re-ordered sort after ordered ones,
  /// alphabetically among themselves.
  static const int unordered = 1000000;

  final String id;
  final String name;
  final String description;
  final double price;
  final String unit;
  final String category;
  final int sortOrder;

  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.unit = 'item',
    this.category = '',
    this.sortOrder = unordered,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'unit': unit,
        'category': category,
        'sortOrder': sortOrder,
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        price: (map['price'] ?? 0.0).toDouble(),
        unit: map['unit'] ?? 'item',
        category: map['category'] ?? '',
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? unordered,
      );

  Product copyWith({
    String? name,
    String? description,
    double? price,
    String? unit,
    String? category,
    int? sortOrder,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// Sorts by explicit position first, name second. Used everywhere products are
/// listed so the manual order set in the reorder screens is respected app-wide.
int compareProducts(Product a, Product b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  if (byOrder != 0) return byOrder;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
