import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/download_service.dart';
import '../../services/email_service.dart';
import '../../services/price_list_service.dart';
import '../../utils/price.dart';
import '../../widgets/category_selector.dart';
import '../../widgets/parts_sheet.dart';
import '../../widgets/reorder_screen.dart';

String _toTitleCase(String s) => toTitleCase(s);

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String? _expandedCategory;

  /// Open sub-category, keyed `'<category>::<sub>'`; `'<category>::'` is that
  /// category's "Overig" bucket. null = none open.
  String? _expandedSub;
  List<String> _orderedCategories = [];

  /// Saved sub-category order, as [subCategoryKey]s.
  List<String> _subOrder = [];

  /// Ids picked in selection mode, all within [_selectionCategory].
  final Set<String> _selected = {};

  /// Category the current selection is scoped to; null = not selecting.
  String? _selectionCategory;
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _query = '';

  /// A prijslijst is being built and handed over; its buttons wait meanwhile.
  bool _busy = false;

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
    final business = context.read<BusinessProvider>();
    _subOrder = business.subCategoryOrder;
    final savedOrder = business.categoryOrder;
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

  bool _matchesText(Product p, String q) =>
      p.name.toLowerCase().contains(q) ||
      p.description.toLowerCase().contains(q);

  /// One group per (category, sub-category) pair that has hits. A matching
  /// category or sub-category name shows everything filed under it.
  List<({String label, List<Product> products})> _searchGroups(
    List<Product> allProducts,
  ) {
    final q = _query;
    final results = <({String label, List<Product> products})>[];
    for (final cat in _orderedCategories) {
      final catMatches = cat.toLowerCase().contains(q);
      // Sub-categories first, then the products filed directly under the
      // category — the same order the accordion uses.
      for (final sub in [
        ...orderedSubCategoriesIn(allProducts, cat, _subOrder),
        '',
      ]) {
        final group = productsIn(allProducts, cat, sub);
        if (group.isEmpty) continue;
        final subMatches = sub.isNotEmpty && sub.toLowerCase().contains(q);
        final matched = catMatches || subMatches
            ? group
            : group.where((p) => _matchesText(p, q)).toList();
        if (matched.isEmpty) continue;
        results.add((
          label: sub.isEmpty
              ? _toTitleCase(cat)
              : '${_toTitleCase(cat)} › ${_toTitleCase(sub)}',
          products: matched,
        ));
      }
    }
    final matchedUncat =
        _uncategorized(allProducts).where((p) => _matchesText(p, q)).toList();
    if (matchedUncat.isNotEmpty) {
      results.add((label: 'Overig', products: matchedUncat));
    }
    return results;
  }

  // ── Prijslijst ────────────────────────────────────────────────────────────

  /// The products as the prijslijst lists them: in the tab's own order, one
  /// section per (category, sub-category). [only] limits it to those ids.
  List<({String category, String subCategory, List<Product> products})>
      _priceListSections(
    List<Product> allProducts, {
    Set<String>? only,
  }) {
    List<Product> pick(List<Product> list) =>
        (only == null ? list : list.where((p) => only.contains(p.id)).toList())
          ..sort(compareProducts);
    final sections =
        <({String category, String subCategory, List<Product> products})>[];
    for (final cat in _orderedCategories) {
      for (final sub in [
        ...orderedSubCategoriesIn(allProducts, cat, _subOrder),
        '',
      ]) {
        final products = pick(productsIn(allProducts, cat, sub));
        if (products.isEmpty) continue;
        sections.add((
          category: _toTitleCase(cat),
          subCategory: _toTitleCase(sub),
          products: products,
        ));
      }
    }
    final uncategorized = pick(_uncategorized(allProducts));
    if (uncategorized.isNotEmpty) {
      sections.add((category: '', subCategory: '', products: uncategorized));
    }
    return sections;
  }

  /// Builds the prijslijst — of the selection when one is active, otherwise
  /// of every product — and shares it or saves it to Downloads.
  Future<void> _exportPriceList({required bool share}) async {
    if (_busy) return;
    final business = context.read<BusinessProvider>();
    final allProducts = context.read<ProductProvider>().products;
    final selection = _isSelecting ? Set<String>.from(_selected) : null;
    final sections = _priceListSections(allProducts, only: selection);
    if (sections.isEmpty) return;

    final info = business.businessInfo;
    final scope = selection != null
        ? _toTitleCase(_selectionCategory ?? '')
        : info?.name ?? '';
    final title = [
      'Prijslijst',
      scope.replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim(),
    ].where((p) => p.isNotEmpty).join(' - ');
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _busy = true);
    try {
      final bytes = utf8.encode(PriceListService.buildCsv(
        sections: sections,
        taxRate: info?.defaultTaxRate ?? 21.0,
        currency: info?.currency ?? '€',
      ));
      if (share) {
        await EmailService.shareFile(
          bytes: bytes,
          filename: '$title.csv',
          mimeType: 'text/csv',
          subject: title,
        );
      } else {
        final location = await DownloadService.save(
          bytes: bytes,
          filename: '$title.csv',
          mimeType: 'text/csv',
        );
        messenger.showSnackBar(
          SnackBar(content: Text('Opgeslagen in $location')),
        );
      }
      if (mounted && selection != null) _exitSelection();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            share ? 'Delen mislukt: $e' : 'Downloaden mislukt: $e',
          ),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _priceListMenu() => PopupMenuButton<bool>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Prijslijst',
        enabled: !_busy,
        onSelected: (share) => _exportPriceList(share: share),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: true,
            child: ListTile(
              leading: Icon(Icons.share_outlined),
              title: Text('Prijslijst delen'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: false,
            child: ListTile(
              leading: Icon(Icons.download_outlined),
              title: Text('Prijslijst downloaden'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      );

  // ── Selection mode ────────────────────────────────────────────────────────

  bool get _isSelecting => _selectionCategory != null;

  void _exitSelection() => setState(() {
        _selectionCategory = null;
        _selected.clear();
      });

  /// Long-press starts a selection scoped to the product's category, since a
  /// sub-category only exists inside one.
  void _startSelection(Product p) {
    if (p.category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Geef dit product eerst een categorie — '
            'sub-categorieën bestaan alleen binnen een categorie.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _selectionCategory = p.category;
      _selected
        ..clear()
        ..add(p.id);
    });
  }

  void _toggleSelected(Product p) {
    setState(() {
      if (!_selected.remove(p.id)) _selected.add(p.id);
      if (_selected.isEmpty) _selectionCategory = null;
    });
  }

  Future<void> _assignSubCategory(List<Product> allProducts) async {
    final cat = _selectionCategory;
    if (cat == null || _selected.isEmpty) return;
    final ids = _selected.toList();
    final anyFiled =
        allProducts.any((p) => _selected.contains(p.id) && p.subCategory.isNotEmpty);

    final result = await showDialog<String>(
      context: context,
      builder: (_) => _SubCategoryDialog(
        count: ids.length,
        category: cat,
        existing: orderedSubCategoriesIn(allProducts, cat, _subOrder),
        allowClear: anyFiled,
      ),
    );
    if (result == null || !mounted) return;

    await context.read<ProductProvider>().assignSubCategory(ids, result);
    if (!mounted) return;
    setState(() {
      _selectionCategory = null;
      _selected.clear();
      // Open the sub-category the products just landed in.
      _expandedCategory = cat;
      _expandedSub = subCategoryKey(cat, result);
    });
    if (result.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${ids.length} product${ids.length == 1 ? '' : 'en'} '
            'in "${_toTitleCase(result)}" geplaatst.',
          ),
        ),
      );
    }
  }

  Widget _selectionBar() {
    return Material(
      color: AppTheme.primary.withAlpha(20),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 6),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Selectie annuleren',
                onPressed: _exitSelection,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_selected.length} geselecteerd',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _toTitleCase(_selectionCategory ?? ''),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Prijslijst delen',
                onPressed: _busy ? null : () => _exportPriceList(share: true),
              ),
              IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'Prijslijst downloaden',
                onPressed: _busy ? null : () => _exportPriceList(share: false),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: () => _assignSubCategory(
                  context.read<ProductProvider>().products,
                ),
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                label: const Text('Sub-categorie'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Renaming ──────────────────────────────────────────────────────────────

  /// Renames a category on all its products and follows it through the saved
  /// orders. Renaming onto an existing category merges the two.
  Future<void> _renameCategory(String cat) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(
        title: 'Categorie hernoemen',
        label: 'Naam categorie',
        initial: cat,
        existing: _orderedCategories.where((c) => c != cat).toList(),
      ),
    );
    if (name == null || !mounted) return;

    final products = context.read<ProductProvider>();
    final business = context.read<BusinessProvider>();
    await products.renameCategory(cat, name);
    await business.renameCategory(cat, name);
    if (!mounted) return;
    setState(() {
      if (_expandedCategory == cat) _expandedCategory = name;
      // The open sub-category is keyed by its category, so it moves too.
      final sub = _openSubName(cat);
      if (sub != null) _expandedSub = subCategoryKey(name, sub);
      if (_selectionCategory == cat) _selectionCategory = name;
    });
  }

  /// Renames a sub-category within [cat]. Renaming onto an existing
  /// sub-category merges the two.
  Future<void> _renameSubCategory(String cat, String sub) async {
    final all = context.read<ProductProvider>().products;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(
        title: 'Sub-categorie hernoemen',
        label: 'Naam sub-categorie',
        initial: sub,
        existing: orderedSubCategoriesIn(all, cat, _subOrder)
            .where((s) => s != sub)
            .toList(),
      ),
    );
    if (name == null || !mounted) return;

    final products = context.read<ProductProvider>();
    final business = context.read<BusinessProvider>();
    await products.renameSubCategory(cat, sub, name);
    await business.renameSubCategory(cat, sub, name);
    if (!mounted) return;
    setState(() => _expandedSub = subCategoryKey(cat, name));
  }

  /// The sub-category open inside [cat], or null if none is.
  String? _openSubName(String cat) {
    final prefix = subCategoryKey(cat, '');
    final key = _expandedSub;
    if (key == null || !key.startsWith(prefix)) return null;
    return key.substring(prefix.length);
  }

  // ── Accordion body ────────────────────────────────────────────────────────

  Widget _productSliver(List<Product> products, double taxRate) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => _buildRow(products[i], taxRate),
        childCount: products.length,
      ),
    );
  }

  Widget _buildRow(Product p, double taxRate) => _ProductRow(
        product: p,
        taxRate: taxRate,
        selecting: _isSelecting,
        selected: _selected.contains(p.id),
        selectable: !_isSelecting || p.category == _selectionCategory,
        onSelectToggle: () => _toggleSelected(p),
        onLongPress: () => _startSelection(p),
        onEdit: () => _showForm(context, p),
        onDelete: () => _confirmDelete(context, p),
      );

  /// Slivers for the contents of an open category: its sub-category headers
  /// (each its own accordion) followed by the products filed directly under it.
  /// A category without sub-categories just lists its products, as before.
  List<Widget> _categoryBody(
    List<Product> allProducts,
    String cat,
    double taxRate,
  ) {
    final subs = orderedSubCategoriesIn(allProducts, cat, _subOrder);
    final loose = productsIn(allProducts, cat, '');
    if (subs.isEmpty) return [_productSliver(loose, taxRate)];

    final slivers = <Widget>[];
    for (final sub in [...subs, '']) {
      final products = sub.isEmpty ? loose : productsIn(allProducts, cat, sub);
      if (products.isEmpty) continue;
      final key = subCategoryKey(cat, sub);
      slivers.add(
        SliverToBoxAdapter(
          child: SubCategoryHeader(
            label: sub.isEmpty ? 'Overig' : _toTitleCase(sub),
            count: products.length,
            isExpanded: _expandedSub == key,
            onTap: () => setState(
              () => _expandedSub = _expandedSub == key ? null : key,
            ),
            // "Overig" is not a real sub-category, so it has no name to change.
            onRename:
                sub.isEmpty ? null : () => _renameSubCategory(cat, sub),
          ),
        ),
      );
      if (_expandedSub == key) slivers.add(_productSliver(products, taxRate));
    }
    return slivers;
  }

  Widget _searchField({bool showSort = false, VoidCallback? onSort}) {
    return Builder(
      builder: (context) => Container(
        color: AppTheme.surf(context),
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
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
            _priceListMenu(),
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
          subCategoryOrder: List<String>.from(_subOrder),
          products: allProducts,
          onSaveCategories: (ordered) {
            context.read<BusinessProvider>().saveCategoryOrder(ordered);
            setState(() => _orderedCategories = ordered);
          },
          onSaveSubCategories: (ordered) {
            context.read<BusinessProvider>().saveSubCategoryOrder(ordered);
            setState(() => _subOrder = ordered);
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
            if (_isSelecting) _selectionBar() else _searchField(),
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
                              return _buildRow(
                                group.products[index - cursor],
                                taxRate,
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
        floatingActionButton: _isSelecting
            ? null
            : _buildFabs(onAdd: () => _showForm(context, null)),
      );
    }

    // ── No categories: flat list ──────────────────────────────────────────
    if (!hasCategories) {
      return Scaffold(
        body: Column(
          children: [
            if (_isSelecting)
              _selectionBar()
            else
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
                  itemBuilder: (ctx, i) =>
                      _buildRow(uncategorized[i], taxRate),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _isSelecting
            ? null
            : _buildFabs(onAdd: () => _showForm(context, null)),
      );
    }

    // ── Accordion view ────────────────────────────────────────────────────
    return Scaffold(
      body: Column(
        children: [
          if (_isSelecting)
            _selectionBar()
          else
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
                      child: CategoryHeader(
                        label: _toTitleCase(cat),
                        count: _productsFor(allProducts, cat).length,
                        isExpanded: _expandedCategory == cat,
                        onTap: () => setState(() {
                          _expandedCategory =
                              _expandedCategory == cat ? null : cat;
                          _expandedSub = null;
                        }),
                        onRename: () => _renameCategory(cat),
                      ),
                    ),
                    if (_expandedCategory == cat)
                      ..._categoryBody(allProducts, cat, taxRate),
                  ],
                  if (uncategorized.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: CategoryHeader(
                        label: 'Overig',
                        count: uncategorized.length,
                        isExpanded: _expandedCategory == '',
                        onTap: () => setState(() {
                          _expandedCategory =
                              _expandedCategory == '' ? null : '';
                          _expandedSub = null;
                        }),
                      ),
                    ),
                    if (_expandedCategory == '')
                      _productSliver(uncategorized, taxRate),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              )),
          ),
        ],
      ),
      floatingActionButton: _isSelecting
          ? null
          : _buildFabs(
              onAdd: () => _showForm(
                context,
                null,
                initialCategory: (_expandedCategory?.isNotEmpty ?? false)
                    ? _expandedCategory
                    : null,
                // Only prefill the sub-category if it belongs to the open one.
                initialSubCategory:
                    _expandedSub != null && _expandedCategory != null &&
                            _expandedSub!.startsWith('$_expandedCategory::')
                        ? _expandedSub!.split('::').last
                        : null,
              ),
            ),
    );
  }

  void _showForm(
    BuildContext context,
    Product? product, {
    String? initialCategory,
    String? initialSubCategory,
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
        initialSubCategory: product == null ? initialSubCategory : null,
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

  /// Selection mode swaps edit/delete for a checkbox; rows outside the
  /// selection's category are dimmed and inert.
  final bool selecting;
  final bool selected;
  final bool selectable;
  final VoidCallback onSelectToggle;
  final VoidCallback onLongPress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductRow({
    required this.product,
    required this.taxRate,
    this.selecting = false,
    this.selected = false,
    this.selectable = true,
    required this.onSelectToggle,
    required this.onLongPress,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inclPrice = product.price * (1 + taxRate / 100);
    final dimmed = selecting && !selectable;
    return ListTile(
      enabled: !dimmed,
      selected: selected,
      selectedTileColor: AppTheme.primary.withAlpha(18),
      onTap: selecting && selectable ? onSelectToggle : null,
      onLongPress: selecting ? null : onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: selecting
          ? Checkbox(
              value: selected,
              onChanged: selectable ? (_) => onSelectToggle() : null,
            )
          : null,
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
            '${formatMoney(inclPrice, currency: '€')} incl.',
            style: TextStyle(
              color: dimmed ? AppTheme.textSecondary : AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (!selecting) ...[
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
        ],
      ),
    );
  }
}

// ── Rename dialog ────────────────────────────────────────────────────────────

/// Renames a category or sub-category. Pops the new name (lowercased, as
/// categories are stored) or null on cancel. Typing a name that already exists
/// is allowed — it merges — but says so first.
class _RenameDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initial;

  /// The other names at the same level, to warn about a merge.
  final List<String> existing;

  const _RenameDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.existing,
  });

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _toTitleCase(widget.initial))
      ..addListener(() => setState(() {}));
    // Preselected, so typing replaces the old name instead of appending to it.
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _value => _ctrl.text.trim().toLowerCase();
  bool get _merges => widget.existing.contains(_value);
  bool get _canSave => _value.isNotEmpty && _value != widget.initial;

  void _submit() {
    if (_canSave) Navigator.pop(context, _value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(labelText: widget.label),
          ),
          if (_merges) ...[
            const SizedBox(height: 12),
            Text(
              '"${_toTitleCase(_value)}" bestaat al. De producten worden '
              'samengevoegd.',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed: _canSave ? _submit : null,
          child: Text(_merges ? 'Samenvoegen' : 'Opslaan'),
        ),
      ],
    );
  }
}

// ── Bulk sub-category dialog ─────────────────────────────────────────────────

/// Names the sub-category for a batch of selected products: pick one that
/// already exists in the category, or type a new one. Pops the chosen name
/// (lowercased, as categories are stored), '' to unfile, or null on cancel.
class _SubCategoryDialog extends StatefulWidget {
  final int count;
  final String category;
  final List<String> existing;
  final bool allowClear;

  const _SubCategoryDialog({
    required this.count,
    required this.category,
    required this.existing,
    required this.allowClear,
  });

  @override
  State<_SubCategoryDialog> createState() => _SubCategoryDialogState();
}

class _SubCategoryDialogState extends State<_SubCategoryDialog> {
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _value => _ctrl.text.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sub-categorie maken'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.count} product${widget.count == 1 ? '' : 'en'} uit '
            '"${_toTitleCase(widget.category)}".',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_value.isNotEmpty) Navigator.pop(context, _value);
            },
            decoration: const InputDecoration(
              labelText: 'Naam sub-categorie',
              hintText: 'Bijv. onderdelen',
            ),
          ),
          if (widget.existing.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Of kies een bestaande:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final sub in widget.existing)
                  ActionChip(
                    label: Text(_toTitleCase(sub)),
                    onPressed: () => Navigator.pop(context, sub),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        if (widget.allowClear)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Uit sub-categorie halen'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(
          onPressed:
              _value.isEmpty ? null : () => Navigator.pop(context, _value),
          child: const Text('Opslaan'),
        ),
      ],
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
  final String? initialSubCategory;
  const _ProductForm({
    this.product,
    required this.taxRate,
    this.initialCategory,
    this.initialSubCategory,
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
  String? _selectedSubCategory;
  bool _updatingPrice = false;
  double? _preciseExclFromIncl;
  late bool _trackStock;
  late final TextEditingController _stock;
  late List<String> _components;

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
    _trackStock = widget.product?.trackStock ?? false;
    _components = [...?widget.product?.components];
    _stock = TextEditingController(
      text: formatStock(widget.product?.stock ?? 0),
    );

    final raw = widget.product?.category ?? widget.initialCategory ?? '';
    _selectedCategory = raw.isEmpty ? null : raw;
    final rawSub =
        widget.product?.subCategory ?? widget.initialSubCategory ?? '';
    _selectedSubCategory =
        rawSub.isEmpty || _selectedCategory == null ? null : rawSub;

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
    final excl = parseDecimalInput(_priceExcl.text);
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
    final incl = parseDecimalInput(_priceIncl.text);
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
    _stock.dispose();
    _nameFocus.dispose();
    _descriptionFocus.dispose();
    _priceExclFocus.dispose();
    _priceInclFocus.dispose();
    _unitFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<ProductProvider>();
    // The count may have moved since the form opened (an invoice took parts
    // meanwhile). Unless it was retyped here, write back the latest one
    // rather than the count the form was opened with.
    final initialStock = formatStock(widget.product?.stock ?? 0);
    final latest = provider.products
        .where((p) => p.id == widget.product?.id)
        .firstOrNull;
    final stock = _stock.text.trim() != initialStock
        ? parseDecimalInput(_stock.text) ?? 0.0
        : latest?.stock ?? widget.product?.stock ?? 0.0;
    final product = Product(
      id: widget.product?.id ?? const Uuid().v4(),
      name: _name.text.trim(),
      description: _description.text.trim(),
      price: _preciseExclFromIncl ??
          roundPrice(parseDecimalInput(_priceExcl.text) ?? 0),
      unit: _unit.text.trim().isEmpty ? 'stuk' : _unit.text.trim(),
      category: _selectedCategory ?? '',
      subCategory: _selectedCategory == null ? '' : (_selectedSubCategory ?? ''),
      // Keep the manual position when editing; new products go last.
      sortOrder: widget.product?.sortOrder ?? Product.unordered,
      trackStock: _trackStock,
      stock: stock,
      components: _components,
    );
    await provider.saveProduct(product);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickComponents(List<Product> candidates) async {
    final picked = await showComponentPicker(
      context,
      candidates: candidates,
      selected: _components,
    );
    if (picked != null && mounted) setState(() => _components = picked);
  }

  @override
  Widget build(BuildContext context) {
    final productProvider = context.watch<ProductProvider>();
    final categories = productProvider.categories;
    // A product can be made of Voorraad products, never of itself.
    final candidates = productProvider.products
        .where((p) => p.trackStock && p.id != widget.product?.id)
        .toList()
      ..sort(compareProducts);
    final componentNames = [
      for (final id in _components)
        ...candidates.where((p) => p.id == id).map((p) => p.name),
    ];
    final subCategories = _selectedCategory == null
        ? const <String>[]
        : productProvider.subCategoriesFor(_selectedCategory!);

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
              textCapitalization: TextCapitalization.words,
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
                      if (parseDecimalInput(v) == null) return 'Ongeldig';
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
              onChanged: (cat) => setState(() {
                _selectedCategory = cat;
                // Sub-categories live inside one category, so a switch clears it.
                _selectedSubCategory = null;
              }),
            ),
            const SizedBox(height: 12),
            CategorySelectorField.sub(
              selected: _selectedSubCategory,
              categories: subCategories,
              enabled: _selectedCategory != null,
              onChanged: (sub) => setState(() => _selectedSubCategory = sub),
            ),
            if (_selectedCategory == null)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  'Kies eerst een categorie.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unit,
              focusNode: _unitFocus,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(labelText: 'Eenheid'),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _trackStock,
              onChanged: (v) => setState(() => _trackStock = v),
              title: const Text('Voorraad bijhouden'),
              subtitle: const Text(
                'Gaat van de voorraad af als hij op een factuur komt',
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_trackStock)
              TextFormField(
                controller: _stock,
                decoration: InputDecoration(
                  labelText: 'Op voorraad',
                  suffixText: _unit.text.trim(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                validator: (v) => v != null &&
                        v.trim().isNotEmpty &&
                        parseDecimalInput(v) == null
                    ? 'Ongeldig'
                    : null,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_tree_outlined),
              title: const Text('Bestaat uit'),
              subtitle: Text(
                componentNames.isEmpty
                    ? 'Kies voorraadproducten waaruit dit kan bestaan, '
                        'zoals olie en bougies voor onderhoud'
                    : componentNames.join(', '),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickComponents(candidates),
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
