import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/invoice.dart';
import '../models/product.dart';
import '../utils/price.dart';

/// The components of [product] that still exist and are kept in the Voorraad,
/// in the order they were set on the product.
List<Product> componentsOf(Product product, List<Product> all) {
  final byId = {for (final p in all) p.id: p};
  return [
    for (final id in product.components)
      if (byId[id] != null && byId[id]!.trackStock && id != product.id)
        byId[id]!,
  ];
}

/// Asks which of [product]'s components a job used, and how much of each.
/// [current] fills in what an existing line recorded. Returns null when the
/// sheet is dismissed, otherwise the parts with a quantity above zero.
Future<List<ItemPart>?> showPartsSheet(
  BuildContext context, {
  required String title,
  required List<Product> components,
  List<ItemPart> current = const [],
  String confirmLabel = 'Opslaan',
}) =>
    showModalBottomSheet<List<ItemPart>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PartsSheet(
        title: title,
        components: components,
        current: current,
        confirmLabel: confirmLabel,
      ),
    );

class _PartsSheet extends StatefulWidget {
  final String title;
  final List<Product> components;
  final List<ItemPart> current;
  final String confirmLabel;

  const _PartsSheet({
    required this.title,
    required this.components,
    required this.current,
    required this.confirmLabel,
  });

  @override
  State<_PartsSheet> createState() => _PartsSheetState();
}

class _PartRow {
  final String productId;
  final String naam;
  final Product? product;
  final TextEditingController qty;

  _PartRow(this.productId, this.naam, this.product, double aantal)
      : qty = TextEditingController(text: aantal > 0 ? formatStock(aantal) : '');

  double get aantal => parseDecimalInput(qty.text) ?? 0;
}

class _PartsSheetState extends State<_PartsSheet> {
  late final List<_PartRow> _rows;

  @override
  void initState() {
    super.initState();
    final used = {for (final p in widget.current) p.productId: p};
    _rows = [
      for (final p in widget.components)
        _PartRow(p.id, p.name, p, used[p.id]?.aantal ?? 0),
      // A part recorded earlier whose product has since left the list stays
      // editable, so opening the sheet does not silently drop it.
      for (final p in widget.current)
        if (!widget.components.any((c) => c.id == p.productId))
          _PartRow(p.productId, p.naam, null, p.aantal),
    ];
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.qty.dispose();
    }
    super.dispose();
  }

  void _set(_PartRow row, double value) {
    setState(() {
      row.qty.text = value > 0 ? formatStock(value) : '';
    });
  }

  void _confirm() {
    Navigator.pop(context, [
      for (final r in _rows)
        if (r.aantal > 0)
          ItemPart(productId: r.productId, naam: r.naam, aantal: r.aantal),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'Welke onderdelen zijn gebruikt?',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in _rows) _buildRow(r),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _confirm,
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_PartRow r) {
    final used = r.aantal > 0;
    final p = r.product;
    return InkWell(
      // Tapping the row switches a part on (1) or off, the common case; the
      // field takes any other amount (4,5 liter olie).
      onTap: () => _set(r, used ? 0 : 1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              used ? Icons.check_box : Icons.check_box_outline_blank,
              color: used ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.naam,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    p == null
                        ? 'Niet meer in de voorraad'
                        : 'Op voorraad: ${formatStock(p.stock)} ${p.unit}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: used ? () => _set(r, r.aantal - 1) : null,
            ),
            SizedBox(
              width: 52,
              child: TextField(
                controller: r.qty,
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add, size: 18),
              visualDensity: VisualDensity.compact,
              onPressed: () => _set(r, r.aantal + 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user pick which Voorraad products [product] can be made of.
/// Returns the chosen ids in list order, or null when dismissed.
Future<List<String>?> showComponentPicker(
  BuildContext context, {
  required List<Product> candidates,
  required List<String> selected,
}) =>
    showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComponentPicker(
        candidates: candidates,
        selected: selected,
      ),
    );

class _ComponentPicker extends StatefulWidget {
  final List<Product> candidates;
  final List<String> selected;

  const _ComponentPicker({required this.candidates, required this.selected});

  @override
  State<_ComponentPicker> createState() => _ComponentPickerState();
}

class _ComponentPickerState extends State<_ComponentPicker> {
  late final Set<String> _selected = {...widget.selected};
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = widget.candidates
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            p.subCategory.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Bestaat uit',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Zoek in de voorraad',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.candidates.isEmpty
                  ? const Center(
                      child: Text(
                        'Nog geen producten in de Voorraad.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView(
                      children: [
                        for (final p in shown)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _selected.contains(p.id),
                            title: Text(p.name),
                            subtitle: p.category.isEmpty
                                ? null
                                : Text(
                                    p.subCategory.isEmpty
                                        ? p.category
                                        : '${p.category} › ${p.subCategory}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                            onChanged: (v) => setState(() {
                              v == true
                                  ? _selected.add(p.id)
                                  : _selected.remove(p.id);
                            }),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, [
                // Keep the order already set, newly ticked ones after it.
                for (final id in widget.selected)
                  if (_selected.contains(id)) id,
                for (final p in widget.candidates)
                  if (_selected.contains(p.id) &&
                      !widget.selected.contains(p.id))
                    p.id,
              ]),
              child: Text('Opslaan (${_selected.length})'),
            ),
          ],
        ),
      ),
    );
  }
}
