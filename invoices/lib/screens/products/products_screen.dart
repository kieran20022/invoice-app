import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';

String _toTitleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final allProducts = provider.products;
    final categories = provider.categories;
    final favorites = context.watch<BusinessProvider>().favoriteCategories;

    final filtered = _selectedCategory == null
        ? allProducts
        : allProducts.where((p) => p.category == _selectedCategory).toList();

    return Scaffold(
      body: allProducts.isEmpty
          ? _EmptyState(onAdd: () => _showForm(context, null))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (categories.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Alle',
                            selected: _selectedCategory == null,
                            onTap: () =>
                                setState(() => _selectedCategory = null),
                          ),
                          ...categories.map(
                            (cat) => Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _FilterChip(
                                label: _toTitleCase(cat),
                                selected: _selectedCategory == cat,
                                isFavorite: favorites.contains(cat),
                                onTap: () =>
                                    setState(() => _selectedCategory = cat),
                                onLongPress: () => _toggleFavorite(cat),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 48,
                                  color: AppTheme.textSecondary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Geen producten in ${_toTitleCase(_selectedCategory!)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: 200,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showForm(
                                      context,
                                      null,
                                      initialCategory: _selectedCategory,
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Product toevoegen'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: filtered.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  '${filtered.length} product${filtered.length == 1 ? '' : 'en'}',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              );
                            }
                            final p = filtered[i - 1];
                            return _ProductCard(
                              product: p,
                              onEdit: () => _showForm(context, p),
                              onDelete: () => _confirmDelete(context, p),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: allProducts.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () =>
                  _showForm(context, null, initialCategory: _selectedCategory),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Product toevoegen',
                style: TextStyle(color: Colors.white),
              ),
            ),
    );
  }

  void _toggleFavorite(String category) {
    context.read<BusinessProvider>().toggleFavoriteCategory(category);
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

class _ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _toTitleCase(product.category),
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
            if (product.description.isNotEmpty)
              Text(
                product.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            Text(
              '€${product.price.toStringAsFixed(2)} ex. BTW / ${product.unit}',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
              color: AppTheme.textSecondary,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: onDelete,
              color: AppTheme.error,
            ),
          ],
        ),
      ),
    );
  }
}

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
    _priceExcl = TextEditingController(
      text: excl != null ? excl.toStringAsFixed(2) : '',
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
      _priceExcl.text = (incl / (1 + widget.taxRate / 100)).toStringAsFixed(2);
    } else if (_priceIncl.text.isEmpty) {
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
      price: double.tryParse(_priceExcl.text) ?? 0,
      unit: _unit.text.trim().isEmpty ? 'stuk' : _unit.text.trim(),
      category: _selectedCategory ?? '',
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
            _CategorySelectorField(
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

class _CategorySelectorField extends StatelessWidget {
  final String? selected;
  final List<String> categories;
  final ValueChanged<String?> onChanged;

  const _CategorySelectorField({
    required this.selected,
    required this.categories,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = selected != null && selected!.isNotEmpty;
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Categorie (optioneel)',
          suffixIcon: Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          hasValue ? _toTitleCase(selected!) : 'Geen categorie',
          style: TextStyle(
            fontSize: 16,
            color: hasValue ? null : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CategoryPickerSheet(
        categories: categories,
        selected: selected,
        onSelected: (cat) {
          onChanged(cat);
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.categories);
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(widget.categories)
          : widget.categories.where((c) => c.contains(q)).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final canAdd = query.isNotEmpty && !widget.categories.contains(query);
    final noneSelected = widget.selected == null || widget.selected!.isEmpty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Categorie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: 'Zoeken of nieuwe categorie...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(
                          () => _filtered = List.from(widget.categories),
                        );
                      },
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.label_off_outlined,
                    color: noneSelected ? AppTheme.primary : null,
                  ),
                  title: const Text('Geen categorie'),
                  selected: noneSelected,
                  selectedColor: AppTheme.primary,
                  onTap: () => widget.onSelected(null),
                ),
                if (canAdd)
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: AppTheme.primary,
                    ),
                    title: Text(
                      'Toevoegen: "${_toTitleCase(query)}"',
                      style: const TextStyle(color: AppTheme.primary),
                    ),
                    onTap: () => widget.onSelected(query),
                  ),
                ..._filtered.map(
                  (cat) => ListTile(
                    dense: true,
                    leading: Icon(
                      widget.selected == cat
                          ? Icons.label
                          : Icons.label_outline,
                      color: widget.selected == cat ? AppTheme.primary : null,
                    ),
                    title: Text(_toTitleCase(cat)),
                    selected: widget.selected == cat,
                    selectedColor: AppTheme.primary,
                    onTap: () => widget.onSelected(cat),
                  ),
                ),
                if (_filtered.isEmpty && !canAdd && query.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Geen categorieën gevonden.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.isFavorite = false,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        avatar: isFavorite
            ? const Icon(Icons.star, size: 14, color: Colors.amber)
            : null,
        selectedColor: AppTheme.primary,
        backgroundColor: AppTheme.primary.withAlpha(15),
        side: BorderSide(
          color: selected ? AppTheme.primary : AppTheme.primary.withAlpha(50),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

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
