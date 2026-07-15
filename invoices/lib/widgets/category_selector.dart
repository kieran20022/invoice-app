import 'package:flutter/material.dart';
import '../config/theme.dart';

String toTitleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class CategorySelectorField extends StatelessWidget {
  final String? selected;
  final List<String> categories;
  final ValueChanged<String?> onChanged;

  const CategorySelectorField({
    super.key,
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
          hasValue ? toTitleCase(selected!) : 'Geen categorie',
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
      builder: (_) => CategoryPickerSheet(
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

class CategoryPickerSheet extends StatefulWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
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
                      'Toevoegen: "${toTitleCase(query)}"',
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
                    title: Text(toTitleCase(cat)),
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
