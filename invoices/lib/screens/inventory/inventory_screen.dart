import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import '../../services/purchase_import_service.dart';
import '../../utils/price.dart';
import '../../widgets/category_selector.dart';
import 'purchase_import_screen.dart';

/// The inventory: the products picked from Producten to be counted, and the
/// parts open invoices have taken off the shelf ("Gereserveerd"). A part on a
/// deleted invoice waits in Gereserveerd to be put back or written off.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _showReserved = false;

  /// A purchase invoice is being read; its button waits meanwhile.
  bool _importing = false;

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>();
    final inventory = context.watch<InventoryProvider>();
    final invoices = context.watch<InvoiceProvider>();
    final stock = products.stockProducts;

    // Until the invoices are in, every hold would look orphaned.
    final liveIds = {for (final i in invoices.allInvoices) i.id};
    bool isCancelled(StockHold h) =>
        invoices.isLoaded && !liveIds.contains(h.invoiceId);
    final cancelledCount = inventory.holds.where(isCancelled).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.warehouse_outlined, size: 18),
                    label: Text('Voorraad (${stock.length})'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Badge(
                      isLabelVisible: cancelledCount > 0,
                      label: Text('$cancelledCount'),
                      child: const Icon(Icons.hourglass_empty, size: 18),
                    ),
                    label: Text('Gereserveerd (${inventory.holds.length})'),
                  ),
                ],
                selected: {_showReserved},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    setState(() => _showReserved = s.first),
              ),
            ),
          ),
          Expanded(
            child: !products.isLoaded || !inventory.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : _showReserved
                    ? _ReservedList(
                        holds: inventory.holds,
                        products: products.products,
                        isCancelled: isCancelled,
                      )
                    : _StockList(products: stock, inventory: inventory),
          ),
        ],
      ),
      floatingActionButton: _showReserved
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'inventory_import',
                  tooltip: 'Inkoopfactuur inlezen',
                  onPressed: _importing ? null : _importPurchase,
                  backgroundColor: AppTheme.primary,
                  child: _importing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long, color: Colors.white),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'inventory_add',
                  onPressed: _addProducts,
                  backgroundColor: AppTheme.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Producten toevoegen',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// Asks for a supplier's invoice (PDF), reads its product lines and opens
  /// them for review against the Voorraad.
  Future<void> _importPurchase() async {
    final stock = context.read<ProductProvider>().stockProducts;
    if (stock.isEmpty) {
      _snack('Voeg eerst producten toe aan de voorraad.');
      return;
    }
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(
        label: 'PDF',
        extensions: ['pdf'],
        mimeTypes: ['application/pdf'],
        uniformTypeIdentifiers: ['com.adobe.pdf'],
      ),
    ]);
    if (file == null || !mounted) return;

    setState(() => _importing = true);
    List<PurchaseLine> lines;
    try {
      final bytes = await file.readAsBytes();
      lines = parsePurchaseRows(await compute(pdfRows, bytes));
    } catch (_) {
      if (mounted) {
        setState(() => _importing = false);
        _snack('Deze PDF kon niet gelezen worden.');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _importing = false);
    if (lines.isEmpty) {
      _snack('Geen productregels gevonden in deze PDF. Een gescande factuur '
          '(een foto) bevat geen tekst om te lezen.');
      return;
    }

    final booked = await Navigator.of(context).push<double>(
      MaterialPageRoute(
        builder: (_) => PurchaseImportScreen(
          fileName: file.name,
          lines: lines,
          products: stock,
        ),
      ),
    );
    if (booked != null && booked > 0 && mounted) {
      _snack('${formatStock(booked)} stuks bijgeboekt.');
    }
  }

  Future<void> _addProducts() async {
    final provider = context.read<ProductProvider>();
    final candidates = provider.products.where((p) => !p.trackStock).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alle producten staan al in de voorraad.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final picked = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _TrackProductsScreen(products: candidates),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    await provider.setTracking(picked, true);
  }
}

// ── Voorraad ────────────────────────────────────────────────────────────────

class _StockList extends StatelessWidget {
  final List<Product> products;
  final InventoryProvider inventory;

  const _StockList({required this.products, required this.inventory});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const _Empty(
        icon: Icons.warehouse_outlined,
        title: 'Nog niets in de voorraad',
        message: 'Voeg producten toe die je op voorraad hebt. Komen ze op een '
            'factuur, dan gaan ze vanzelf van de voorraad af. Arbeid en '
            'andere diensten laat je er gewoon buiten.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _StockRow(
        product: products[i],
        reserved: inventory.reservedFor(products[i].id),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final Product product;
  final double reserved;

  const _StockRow({required this.product, required this.reserved});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ProductProvider>();
    final stock = product.stock;
    final color = stock < 0
        ? AppTheme.error
        : stock == 0
            ? const Color(0xFFF59E0B)
            : AppTheme.onSurface(context);
    final details = [
      if (product.category.isNotEmpty)
        product.subCategory.isEmpty
            ? product.category
            : '${product.category} › ${product.subCategory}',
      if (reserved > 0) '${formatStock(reserved)} gereserveerd',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: AppTheme.textSecondary,
              visualDensity: VisualDensity.compact,
              onPressed: () => provider.adjustStock(product.id, -1),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _editCount(context),
              child: Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                alignment: Alignment.center,
                child: Text(
                  formatStock(stock),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: AppTheme.primary,
              visualDensity: VisualDensity.compact,
              onPressed: () => provider.adjustStock(product.id, 1),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (v) {
                if (v == 'count') _editCount(context);
                if (v == 'untrack') _confirmUntrack(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'count', child: Text('Aantal invoeren')),
                PopupMenuItem(
                  value: 'untrack',
                  child: Text('Uit voorraad halen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCount(BuildContext context) async {
    final provider = context.read<ProductProvider>();
    final value = await showDialog<double>(
      context: context,
      builder: (_) => _CountDialog(product: product),
    );
    if (value != null) await provider.setStock(product.id, value);
  }

  Future<void> _confirmUntrack(BuildContext context) async {
    final provider = context.read<ProductProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Uit voorraad halen?'),
        content: Text(
          '"${product.name}" blijft in Producten staan, maar wordt niet meer '
          'geteld als hij op een factuur komt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Uit voorraad halen'),
          ),
        ],
      ),
    );
    if (ok == true) await provider.setTracking([product.id], false);
  }
}

class _CountDialog extends StatefulWidget {
  final Product product;
  const _CountDialog({required this.product});

  @override
  State<_CountDialog> createState() => _CountDialogState();
}

class _CountDialogState extends State<_CountDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: formatStock(widget.product.stock));
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseDecimalInput(_ctrl.text);
    if (value == null) {
      setState(() => _error = 'Ongeldig aantal');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onTap: () => _ctrl.selection =
            TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Op voorraad',
          suffixText: widget.product.unit,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuleren'),
        ),
        TextButton(onPressed: _submit, child: const Text('Opslaan')),
      ],
    );
  }
}

// ── Gereserveerd ────────────────────────────────────────────────────────────

class _ReservedList extends StatelessWidget {
  final List<StockHold> holds;
  final List<Product> products;
  final bool Function(StockHold) isCancelled;

  const _ReservedList({
    required this.holds,
    required this.products,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    if (holds.isEmpty) {
      return const _Empty(
        icon: Icons.hourglass_empty,
        title: 'Niets gereserveerd',
        message: 'Onderdelen op een concept- of werkplaatsfactuur staan hier '
            'tot de factuur betaald is. Wordt de factuur verwijderd, dan '
            'wachten ze hier om terug in de voorraad te gaan.',
      );
    }
    // Cancelled invoices first: those are the ones asking for something.
    final sorted = [...holds]..sort((a, b) {
        final ca = isCancelled(a) ? 0 : 1;
        final cb = isCancelled(b) ? 0 : 1;
        return ca != cb ? ca - cb : b.updatedAt.compareTo(a.updatedAt);
      });
    final names = {for (final p in products) p.id: p.name};

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _HoldCard(
        hold: sorted[i],
        cancelled: isCancelled(sorted[i]),
        productNames: names,
      ),
    );
  }
}

class _HoldCard extends StatelessWidget {
  final StockHold hold;
  final bool cancelled;
  final Map<String, String> productNames;

  const _HoldCard({
    required this.hold,
    required this.cancelled,
    required this.productNames,
  });

  String _nameOf(String id) =>
      productNames[id] ?? hold.names[id] ?? 'Verwijderd product';

  @override
  Widget build(BuildContext context) {
    const warn = Color(0xFFF59E0B);
    final who = [hold.clientNaam, hold.clientKenteken]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      shape: cancelled
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: warn),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hold.invoiceLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (who.isNotEmpty)
                        Text(
                          who,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant(context),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (cancelled ? warn : AppTheme.primary).withAlpha(26),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cancelled ? 'Factuur verwijderd' : 'Op factuur',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cancelled ? warn : AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 6),
            for (final e in hold.quantities.entries)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${formatStock(e.value)} × ${_nameOf(e.key)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  if (cancelled)
                    IconButton(
                      tooltip: 'Terug in voorraad',
                      icon: const Icon(Icons.undo, size: 18),
                      color: AppTheme.primary,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _run(
                        context,
                        (inv) => inv.restock(hold.invoiceId, productIds: [e.key]),
                        '${_nameOf(e.key)} terug in voorraad',
                      ),
                    )
                  else
                    const SizedBox(height: 32),
                ],
              ),
            if (cancelled)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _confirmWriteOff(context),
                    child: const Text(
                      'Afschrijven',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () => _run(
                      context,
                      (inv) => inv.restock(hold.invoiceId),
                      'Terug in voorraad gezet',
                    ),
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Alles terugzetten'),
                  ),
                ],
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Verkocht zodra de factuur betaald is.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant(context),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWriteOff(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Afschrijven?'),
        content: const Text(
          'Deze onderdelen gaan niet terug in de voorraad — bijvoorbeeld '
          'omdat ze toch gebruikt of kapot zijn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Afschrijven',
              style: TextStyle(color: AppTheme.error),
            ),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, (inv) => inv.writeOff(hold.invoiceId), 'Afgeschreven');
    }
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function(InventoryProvider) action,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action(context.read<InventoryProvider>());
      messenger.showSnackBar(
        SnackBar(content: Text(done), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e is StateError ? e.message : 'Mislukt: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Adding products ─────────────────────────────────────────────────────────

/// Picks products from Producten to start counting. Pops the chosen ids.
///
/// Laid out as the Producten tab's own accordion — categories, then their
/// sub-categories — and each of those headers ticks everything under it.
class _TrackProductsScreen extends StatefulWidget {
  final List<Product> products;
  const _TrackProductsScreen({required this.products});

  @override
  State<_TrackProductsScreen> createState() => _TrackProductsScreenState();
}

class _TrackProductsScreenState extends State<_TrackProductsScreen> {
  final _selected = <String>{};
  String _query = '';

  /// Open category ('' = "Overig") and open sub-category, keyed with
  /// [subCategoryKey] — one of each at a time, as in Producten.
  String? _expandedCategory;
  String? _expandedSub;

  late final List<String> _categories;
  late final List<String> _subOrder;

  @override
  void initState() {
    super.initState();
    final business = context.read<BusinessProvider>();
    _subOrder = business.subCategoryOrder;
    final all = widget.products
        .map((p) => p.category)
        .where((c) => c.isNotEmpty)
        .toSet();
    _categories = business.categoryOrder.where(all.contains).toList();
    _categories.addAll(all.difference(_categories.toSet()).toList()..sort());
  }

  List<Product> get _uncategorized =>
      widget.products.where((p) => p.category.isEmpty).toList();

  /// true = all of [group] picked, false = none, null = some.
  bool? _stateOf(List<Product> group) {
    final n = group.where((p) => _selected.contains(p.id)).length;
    return n == 0 ? false : (n == group.length ? true : null);
  }

  void _selectGroup(List<Product> group, bool select) => setState(() {
        final ids = group.map((p) => p.id);
        select ? _selected.addAll(ids) : _selected.removeAll(ids);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Naar voorraad'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(context, _selected.toList()),
            child: Text(
              _selected.isEmpty ? 'Toevoegen' : 'Toevoegen (${_selected.length})',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Zoeken…',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CustomScrollView(
              slivers: _query.isNotEmpty
                  ? _searchSlivers()
                  : _categories.isEmpty
                      ? [_productSliver(_uncategorized)]
                      : _accordionSlivers(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _accordionSlivers() {
    final uncategorized = _uncategorized;
    return [
      for (final cat in _categories) ...[
        _categoryHeader(
          cat,
          widget.products.where((p) => p.category == cat).toList(),
        ),
        if (_expandedCategory == cat) ..._categoryBody(cat),
      ],
      if (uncategorized.isNotEmpty) ...[
        _categoryHeader('', uncategorized),
        if (_expandedCategory == '') _productSliver(uncategorized),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ];
  }

  Widget _categoryHeader(String cat, List<Product> products) {
    return SliverToBoxAdapter(
      child: CategoryHeader(
        label: cat.isEmpty ? 'Overig' : toTitleCase(cat),
        count: products.length,
        isExpanded: _expandedCategory == cat,
        onTap: () => setState(() {
          _expandedCategory = _expandedCategory == cat ? null : cat;
          _expandedSub = null;
        }),
        selected: _stateOf(products),
        onSelect: (v) => _selectGroup(products, v),
      ),
    );
  }

  /// A category's sub-category headers, then its "Overig" bucket — or just
  /// its products when it has no sub-categories.
  List<Widget> _categoryBody(String cat) {
    final subs = orderedSubCategoriesIn(widget.products, cat, _subOrder);
    final loose = productsIn(widget.products, cat, '');
    if (subs.isEmpty) return [_productSliver(loose)];

    final slivers = <Widget>[];
    for (final sub in [...subs, '']) {
      final products =
          sub.isEmpty ? loose : productsIn(widget.products, cat, sub);
      if (products.isEmpty) continue;
      final key = subCategoryKey(cat, sub);
      slivers.add(SliverToBoxAdapter(
        child: SubCategoryHeader(
          label: sub.isEmpty ? 'Overig' : toTitleCase(sub),
          count: products.length,
          isExpanded: _expandedSub == key,
          onTap: () => setState(
            () => _expandedSub = _expandedSub == key ? null : key,
          ),
          selected: _stateOf(products),
          onSelect: (v) => _selectGroup(products, v),
        ),
      ));
      if (_expandedSub == key) {
        slivers.add(_productSliver(products, indent: 20));
      }
    }
    return slivers;
  }

  /// While searching: one labelled group per (category, sub-category) with
  /// hits, as Producten shows them. A matching category or sub-category name
  /// shows everything filed under it.
  List<Widget> _searchSlivers() {
    final q = _query;
    bool matches(Product p) =>
        p.name.toLowerCase().contains(q) ||
        p.description.toLowerCase().contains(q);

    final slivers = <Widget>[];
    void addGroup(String label, List<Product> group) {
      if (group.isEmpty) return;
      slivers
        ..add(SliverToBoxAdapter(child: _SearchGroupHeader(label: label)))
        ..add(_productSliver(group));
    }

    for (final cat in _categories) {
      final catMatches = cat.toLowerCase().contains(q);
      for (final sub in [
        ...orderedSubCategoriesIn(widget.products, cat, _subOrder),
        '',
      ]) {
        final group = productsIn(widget.products, cat, sub);
        final subMatches = sub.isNotEmpty && sub.toLowerCase().contains(q);
        addGroup(
          sub.isEmpty
              ? toTitleCase(cat)
              : '${toTitleCase(cat)} › ${toTitleCase(sub)}',
          catMatches || subMatches ? group : group.where(matches).toList(),
        );
      }
    }
    addGroup('Overig', _uncategorized.where(matches).toList());

    if (slivers.isEmpty) {
      slivers.add(SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Text(
            'Geen resultaten voor "$_query".',
            style: TextStyle(color: AppTheme.onSurfaceVariant(context)),
          ),
        ),
      ));
    }
    return slivers;
  }

  Widget _productSliver(List<Product> products, {double indent = 4}) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) {
          final p = products[i];
          return CheckboxListTile(
            value: _selected.contains(p.id),
            onChanged: (v) => setState(() =>
                v == true ? _selected.add(p.id) : _selected.remove(p.id)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.only(left: indent, right: 16),
            visualDensity: VisualDensity.compact,
            title: Text(
              p.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: p.description.isEmpty
                ? null
                : Text(
                    p.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          );
        },
        childCount: products.length,
      ),
    );
  }
}

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

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.onSurfaceVariant(context)),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.onSurfaceVariant(context)),
            ),
          ],
        ),
      ),
    );
  }
}
