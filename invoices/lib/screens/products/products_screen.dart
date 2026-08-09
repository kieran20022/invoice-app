import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../../utils/price.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/reorder_screen.dart';

String _toTitleCase(String s) => toTitleCase(s);

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? _expandedCategory;
  List<String> _orderedCategories = [];
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
    _searchFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _withDismiss(Widget child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _searchFocusNode.unfocus(),
        child: child,
      );

  void _syncOrder(List<Product> products) {
    final savedOrder = context.read<BusinessProvider>().categoryOrder;
    final allCats =
        products.map((p) => p.category).where((c) => c.isNotEmpty).toSet();
    final ordered = savedOrder.where(allCats.contains).toList();
    final remaining = (allCats.difference(ordered.toSet()).toList()..sort());
    ordered.addAll(remaining);
    _orderedCategories = ordered;
  }

  List<Product> _productsFor(List<Product> products, String cat) =>
      products.where((p) => p.category == cat).toList();

  List<Product> _uncategorized(List<Product> products) =>
      products.where((p) => p.category.isEmpty).toList();

  List<({String label, List<Product> products})> _searchGroups(
    List<Product> allProducts,
  ) {
    final q = _query;
    final results = <({String label, List<Product> products})>[];
    for (final cat in _orderedCategories) {
      final catProducts = _productsFor(allProducts, cat);
      final catMatches = cat.toLowerCase().contains(q);
      final matched = catMatches
          ? catProducts
          : catProducts
              .where(
                (p) =>
                    p.name.toLowerCase().contains(q) ||
                    p.description.toLowerCase().contains(q),
              )
              .toList();
      if (matched.isNotEmpty) {
        results.add((label: _toTitleCase(cat), products: matched));
      }
    }
    final matchedUncat = _uncategorized(allProducts)
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q),
        )
        .toList();
    if (matchedUncat.isNotEmpty) {
      results.add((label: 'Overig', products: matchedUncat));
    }
    return results;
  }

  Widget _searchField({bool showSort = false, VoidCallback? onSort}) {
    return Builder(
      builder: (context) => Container(
        color: AppTheme.surf(context),
        padding: EdgeInsets.fromLTRB(16, 12, showSort ? 4 : 16, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Zoeken op categorie of product...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  fillColor: AppTheme.bg(context),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.borderOf(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppTheme.primary,
                      width: 2,
                    ),
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _searchCtrl.clear,
                        )
                      : null,
                ),
              ),
            ),
            if (showSort && onSort != null)
              IconButton(
                icon: const Icon(Icons.sort),
                tooltip: 'Volgorde aanpassen',
                onPressed: onSort,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabs({required VoidCallback onAdd}) {
    final focused = _searchFocusNode.hasFocus;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'search_fab',
          onPressed: () {
            if (_searchFocusNode.hasFocus) {
              _searchFocusNode.unfocus();
            } else {
              _searchFocusNode.requestFocus();
            }
          },
          backgroundColor: focused ? AppTheme.primaryDark : AppTheme.primary,
          child: Icon(
            focused ? Icons.search_off : Icons.search,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(
          heroTag: 'add_fab',
          onPressed: onAdd,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Product toevoegen',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  void _openReorder(List<Product> allProducts) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryReorderScreen(
          categories: List<String>.from(_orderedCategories),
          products: allProducts,
          onSaveCategories: (ordered) {
            context.read<BusinessProvider>().saveCategoryOrder(ordered);
            setState(() => _orderedCategories = ordered);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final allProducts = provider.products;
    final taxRate =
        context.watch<BusinessProvider>().businessInfo?.defaultTaxRate ?? 21.0;

    if (allProducts.isEmpty) {
      return Scaffold(
        body: _EmptyState(onAdd: () => _showForm(context, null)),
      );
    }

    _syncOrder(allProducts);
    final uncategorized = _uncategorized(allProducts);
    final hasCategories = _orderedCategories.isNotEmpty;

    // ── Search results ────────────────────────────────────────────────────
    if (_query.isNotEmpty) {
      final groups = _searchGroups(allProducts);
      return Scaffold(
        body: Column(
          children: [
            _searchField(),
            const Divider(height: 1),
            Expanded(
              child: _withDismiss(
                groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'Geen resultaten voor "$_query".',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: groups.fold<int>(
                          0,
                          (n, g) => n + 1 + g.products.length,
                        ),
                        itemBuilder: (ctx, index) {
                          int cursor = 0;
                          for (final group in groups) {
                            if (index == cursor) {
                              return _SearchGroupHeader(label: group.label);
                            }
                            cursor++;
                            if (index < cursor + group.products.length) {
                              final p = group.products[index - cursor];
                              return _ProductRow(
                                product: p,
                                taxRate: taxRate,
                                onEdit: () => _showForm(context, p),
                                onDelete: () => _confirmDelete(context, p),
                              );
                            }
                            cursor += group.products.length;
                          }
                          return const SizedBox.shrink();
                        },
                      ),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFabs(
          onAdd: () => _showForm(context, null),
        ),
      );
    }

    // ── No categories: flat list ──────────────────────────────────────────
    if (!hasCategories) {
      return Scaffold(
        body: Column(
          children: [
            _searchField(
              showSort: uncategorized.length > 1,
              onSort: () => _openReorder(allProducts),
            ),
            const Divider(height: 1),
            Expanded(
              child: _withDismiss(
                ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: uncategorized.length,
                  itemBuilder: (ctx, i) {
                    final p = uncategorized[i];
                    return _ProductRow(
                      product: p,
                      taxRate: taxRate,
                      onEdit: () => _showForm(context, p),
                      onDelete: () => _confirmDelete(context, p),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFabs(
          onAdd: () => _showForm(context, null),
        ),
      );
    }

    // ── Accordion view ────────────────────────────────────────────────────
    return Scaffold(
      body: Column(
        children: [
          _searchField(
            showSort: true,
            onSort: () => _openReorder(allProducts),
          ),
          const Divider(height: 1),
          Expanded(
            child: _withDismiss(CustomScrollView(
                slivers: [
                  for (final cat in _orderedCategories) ...[
                    SliverToBoxAdapter(
                      child: _CategoryHeader(
                        label: _toTitleCase(cat),
                        count: _productsFor(allProducts, cat).length,
                        isExpanded: _expandedCategory == cat,
                        onTap: () => setState(() {
                          _expandedCategory =
                              _expandedCategory == cat ? null : cat;
                        }),
                      ),
                    ),
                    if (_expandedCategory == cat)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final p = _productsFor(allProducts, cat)[i];
                            return _ProductRow(
                              product: p,
                              taxRate: taxRate,
                              onEdit: () => _showForm(context, p),
                              onDelete: () => _confirmDelete(context, p),
                            );
                          },
                          childCount: _productsFor(allProducts, cat).length,
                        ),
                      ),
                  ],
                  if (uncategorized.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: _CategoryHeader(
                        label: 'Overig',
                        count: uncategorized.length,
                        isExpanded: _expandedCategory == '',
                        onTap: () => setState(() {
                          _expandedCategory =
                              _expandedCategory == '' ? null : '';
                        }),
                      ),
                    ),
                    if (_expandedCategory == '')
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final p = uncategorized[i];
                            return _ProductRow(
                              product: p,
                              taxRate: taxRate,
                              onEdit: () => _showForm(context, p),
                              onDelete: () => _confirmDelete(context, p),
                            );
                          },
                          childCount: uncategorized.length,
                        ),
                      ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              )),
          ),
        ],
      ),
      floatingActionButton: _buildFabs(
        onAdd: () => _showForm(
          context,
          null,
          initialCategory:
              (_expandedCategory?.isNotEmpty ?? false) ? _expandedCategory : null,
        ),
      ),
    );
  }

  void _showForm(
    BuildContext context,
    Product? product, {
    String? initialCategory,
  }) {
    final taxRate =
        context.read<BusinessProvider>().businessInfo?.defaultTaxRate ?? 21.0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ProductForm(
        product: product,
        taxRate: taxRate,
        initialCategory: product == null ? initialCategory : null,
      ),
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Product verwijderen'),
        content: Text(
          'Verwijder "${product.name}"? Dit kan niet ongedaan worden gemaakt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ProductProvider>().deleteProduct(product.id);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
  }
}

// ── Product row (accordion tile with edit/delete) ─────────────────────────────

class _ProductRow extends StatelessWidget {
  final Product product;
  final double taxRate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.product,
    required this.taxRate,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inclPrice = product.price * (1 + taxRate / 100);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        product.name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: product.description.isNotEmpty
          ? Text(
              product.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '€${inclPrice.toStringAsFixed(2)} incl.',
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: onEdit,
            color: AppTheme.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: onDelete,
            color: AppTheme.error,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ── Category accordion header ─────────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  const _CategoryHeader({
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surf(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isExpanded
                    ? AppTheme.primary.withAlpha(80)
                    : AppTheme.borderOf(context),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isExpanded
                      ? AppTheme.primary
                      : AppTheme.onSurface(context),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(isExpanded ? 30 : 18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more,
                  color: isExpanded
                      ? AppTheme.primary
                      : AppTheme.onSurfaceVariant(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search group header ───────────────────────────────────────────────────────

class _SearchGroupHeader extends StatelessWidget {
  final String label;
  const _SearchGroupHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: AppTheme.bg(context),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Product form (add / edit) ─────────────────────────────────────────────────

class _ProductForm extends StatefulWidget {
  final Product? product;
  final double taxRate;
  final String? initialCategory;
  const _ProductForm({
    this.product,
    required this.taxRate,
    this.initialCategory,
  });

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _priceExcl;
  late final TextEditingController _priceIncl;
  late final TextEditingController _unit;
  String? _selectedCategory;
  bool _updatingPrice = false;
  double? _preciseExclFromIncl;

  final _nameFocus = FocusNode();
  final _descriptionFocus = FocusNode();
  final _priceExclFocus = FocusNode();
  final _priceInclFocus = FocusNode();
  final _unitFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.product?.name ?? '');
    _description = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _unit = TextEditingController(text: widget.product?.unit ?? 'stuk');

    final raw = widget.product?.category ?? widget.initialCategory ?? '';
    _selectedCategory = raw.isEmpty ? null : raw;

    final excl = widget.product?.price;
    // Full stored precision, so re-saving an untouched price writes back the
    // same value instead of a 2-decimal rounding of it.
    _priceExcl = TextEditingController(
      text: excl != null ? formatPriceInput(excl) : '',
    );
    _priceIncl = TextEditingController(
      text: excl != null
          ? (excl * (1 + widget.taxRate / 100)).toStringAsFixed(2)
          : '',
    );

    _priceExcl.addListener(_onExclChanged);
    _priceIncl.addListener(_onInclChanged);

    if (widget.product == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  void _onExclChanged() {
    if (_updatingPrice) return;
    _preciseExclFromIncl = null;
    _updatingPrice = true;
    final excl = double.tryParse(_priceExcl.text);
    if (excl != null) {
      _priceIncl.text = (excl * (1 + widget.taxRate / 100)).toStringAsFixed(2);
    } else if (_priceExcl.text.isEmpty) {
      _priceIncl.text = '';
    }
    _updatingPrice = false;
  }

  void _onInclChanged() {
    if (_updatingPrice) return;
    _updatingPrice = true;
    final incl = double.tryParse(_priceIncl.text);
    if (incl != null) {
      final excl = roundPrice(incl / (1 + widget.taxRate / 100));
      _preciseExclFromIncl = excl;
      _priceExcl.text = formatPriceInput(excl);
    } else if (_priceIncl.text.isEmpty) {
      _preciseExclFromIncl = null;
      _priceExcl.text = '';
    }
    _updatingPrice = false;
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _priceExcl.dispose();
    _priceIncl.dispose();
    _unit.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    _priceExclFocus.dispose();
    _priceInclFocus.dispose();
    _unitFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: _preciseExclFromIncl ??
          roundPrice(double.tryParse(_priceExcl.text) ?? 0),
      unit: _unit.text.trim().isEmpty ? 'stuk' : _unit.text.trim(),
      category: _selectedCategory ?? '',
      // Keep the manual position when editing; new products go last.
      sortOrder: widget.product?.sortOrder ?? Product.unordered,
    );
    await context.read<ProductProvider>().saveProduct(product);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductProvider>().categories;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.product == null ? 'Nieuw product' : 'Product bewerken',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_descriptionFocus),
              decoration: const InputDecoration(labelText: 'Naam *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              focusNode: _descriptionFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_priceExclFocus),
              decoration: const InputDecoration(
                labelText: 'Omschrijving (optioneel)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceExcl,
                    focusNode: _priceExclFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_priceInclFocus),
                    decoration: const InputDecoration(
                      labelText: 'Prijs ex. BTW *',
                      prefixText: '€ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Verplicht';
                      if (double.tryParse(v) == null) return 'Ongeldig';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceIncl,
                    focusNode: _priceInclFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_unitFocus),
                    decoration: const InputDecoration(
                      labelText: 'Prijs incl. BTW',
                      prefixText: '€ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CategorySelectorField(
              selected: _selectedCategory,
              categories: categories,
              onChanged: (cat) => setState(() => _selectedCategory = cat),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unit,
              focusNode: _unitFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: 'Eenheid'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: Text(
                widget.product == null
                    ? 'Product toevoegen'
                    : 'Wijzigingen opslaan',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(26),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: AppTheme.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nog geen producten',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Voeg je producten en diensten toe om ze snel aan facturen toe te kunnen voegen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Product toevoegen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
