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

  /// Sub-category within [category]. Only meaningful when [category] is set;
  /// empty means the product sits directly under its category.
  final String subCategory;
  final int sortOrder;

  /// Kept in the Voorraad tab: putting it on an invoice takes it off the
  /// shelf. Off for things that are not stock, such as labour.
  final bool trackStock;

  /// How many are on the shelf — already net of what open invoices took.
  /// Only meaningful when [trackStock] is on.
  final double stock;

  /// How supplier invoices have described this product, normalized
  /// (`normalizeSupplierText`). Remembered when a match is confirmed in the
  /// purchase import so the next invoice from that shop matches outright.
  /// Written only by appending (`arrayUnion`), never by [toMap].
  final List<String> supplierNames;

  const Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.unit = 'item',
    this.category = '',
    this.subCategory = '',
    this.sortOrder = unordered,
    this.trackStock = false,
    this.stock = 0,
    this.supplierNames = const [],
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'price': price,
        'unit': unit,
        'category': category,
        'subCategory': subCategory,
        'sortOrder': sortOrder,
        'trackStock': trackStock,
        'stock': stock,
      };

  factory Product.fromMap(String id, Map<String, dynamic> map) => Product(
        id: id,
        name: map['name'] ?? '',
        description: map['description'] ?? '',
        price: (map['price'] ?? 0.0).toDouble(),
        unit: map['unit'] ?? 'item',
        category: map['category'] ?? '',
        // A sub-category without a category would be unreachable in the UI.
        subCategory:
            (map['category'] ?? '').isEmpty ? '' : (map['subCategory'] ?? ''),
        sortOrder: (map['sortOrder'] as num?)?.toInt() ?? unordered,
        trackStock: map['trackStock'] == true,
        stock: (map['stock'] as num?)?.toDouble() ?? 0,
        supplierNames: List<String>.from(map['supplierNames'] ?? const []),
      );

  Product copyWith({
    String? name,
    String? description,
    double? price,
    String? unit,
    String? category,
    String? subCategory,
    int? sortOrder,
    bool? trackStock,
    double? stock,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        price: price ?? this.price,
        unit: unit ?? this.unit,
        category: category ?? this.category,
        subCategory: subCategory ?? this.subCategory,
        sortOrder: sortOrder ?? this.sortOrder,
        trackStock: trackStock ?? this.trackStock,
        stock: stock ?? this.stock,
        supplierNames: supplierNames,
      );
}

/// Sub-categories used by the products of [category], alphabetically.
/// Products without a sub-category are not represented here — they render in
/// the "Overig" bucket that the screens append after these.
List<String> subCategoriesIn(List<Product> all, String category) {
  final subs = all
      .where((p) => p.category == category && p.subCategory.isNotEmpty)
      .map((p) => p.subCategory)
      .toSet()
      .toList();
  subs.sort();
  return subs;
}

/// Key a sub-category's manual position is stored under, and the key the
/// accordions use for their open sub-category. `'<category>::'` is a
/// category's "Overig" bucket.
String subCategoryKey(String category, String subCategory) =>
    '$category::$subCategory';

/// Sub-categories of [category] in display order: the manual order from
/// [savedOrder] (a list of [subCategoryKey]s) first, then any sub-category not
/// listed there, alphabetically.
List<String> orderedSubCategoriesIn(
  List<Product> all,
  String category,
  List<String> savedOrder,
) {
  final remaining = subCategoriesIn(all, category).toSet();
  final prefix = '$category::';
  final ordered = <String>[];
  for (final key in savedOrder) {
    if (!key.startsWith(prefix)) continue;
    final sub = key.substring(prefix.length);
    if (remaining.remove(sub)) ordered.add(sub);
  }
  final rest = remaining.toList()..sort();
  return [...ordered, ...rest];
}

/// Products of [category] filed under [subCategory] ('' = directly under the
/// category), in display order.
List<Product> productsIn(List<Product> all, String category, String subCategory) =>
    all
        .where((p) => p.category == category && p.subCategory == subCategory)
        .toList();

/// Sorts by explicit position first, name second. Used everywhere products are
/// listed so the manual order set in the reorder screens is respected app-wide.
int compareProducts(Product a, Product b) {
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  if (byOrder != 0) return byOrder;
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

/// A stock count without a pointless `.0`: `3`, `2.5`.
String formatStock(double qty) =>
    qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();
