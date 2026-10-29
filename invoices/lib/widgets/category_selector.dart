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

  /// Field label, sheet title, "nothing selected" text and search hint. The
  /// defaults describe categories; the sub-category field overrides them.
  final String label;
  final String title;
  final String noneLabel;
  final String hintText;

  /// A disabled field still renders (greyed) but does not open the picker —
  /// used for the sub-category field while no category is chosen.
  final bool enabled;

  const CategorySelectorField({
    super.key,
    required this.selected,
    required this.categories,
    required this.onChanged,
    this.label = 'Categorie (optioneel)',
    this.title = 'Categorie',
    this.noneLabel = 'Geen categorie',
    this.hintText = 'Zoeken of nieuwe categorie...',
    this.enabled = true,
  });

  /// Pre-configured for picking a sub-category inside a category.
  const CategorySelectorField.sub({
    super.key,
    required this.selected,
    required this.categories,
    required this.onChanged,
    this.enabled = true,
  })  : label = 'Sub-categorie (optioneel)',
        title = 'Sub-categorie',
        noneLabel = 'Geen sub-categorie',
        hintText = 'Zoeken of nieuwe sub-categorie...';

  @override
  Widget build(BuildContext context) {
    final hasValue = selected != null && selected!.isNotEmpty;
    return InkWell(
      onTap: enabled ? () => _showPicker(context) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          hasValue ? toTitleCase(selected!) : noneLabel,
          style: TextStyle(
            fontSize: 16,
            color: hasValue && enabled ? null : AppTheme.textSecondary,
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
        title: title,
        noneLabel: noneLabel,
        hintText: hintText,
        onSelected: (cat) {
          onChanged(cat);
          Navigator.pop(context);
        },
      ),
    );
  }
}

/// Tick box on an accordion header that selects everything under it: ticked
/// when all of it is selected, a dash when only part is ([selected] null).
/// Tapping it selects the lot, or clears it when all was already selected.
class _GroupCheckbox extends StatelessWidget {
  final bool? selected;
  final ValueChanged<bool> onSelect;

  const _GroupCheckbox({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: selected,
      tristate: true,
      visualDensity: VisualDensity.compact,
      onChanged: (_) => onSelect(selected != true),
    );
  }
}

/// Accordion header for a category. Shared by the products screen, the invoice
/// product picker and the inventory's product picker.
class CategoryHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  /// Shows a rename button while the header is open. Null for the "Overig"
  /// bucket, which is not a real category, and where the list is only there
  /// to pick from.
  final VoidCallback? onRename;

  /// Puts a tick box before the label that selects the whole category. See
  /// [_GroupCheckbox] for [selected].
  final ValueChanged<bool>? onSelect;
  final bool? selected;

  const CategoryHeader({
    super.key,
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onTap,
    this.onRename,
    this.onSelect,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surf(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: EdgeInsets.only(left: onSelect != null ? 4 : 16, right: 16),
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
              if (onSelect != null) ...[
                _GroupCheckbox(selected: selected, onSelect: onSelect!),
                const SizedBox(width: 4),
              ],
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
              if (isExpanded && onRename != null)
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline, size: 19),
                  tooltip: 'Hernoemen',
                  onPressed: onRename,
                  color: AppTheme.primary,
                  visualDensity: VisualDensity.compact,
                ),
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

/// Accordion header for a sub-category. Indented and lighter than the category
/// header it nests under. Shared by the products screen and the invoice product
/// picker so both levels look identical in either place.
class SubCategoryHeader extends StatelessWidget {
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  /// Shows a rename button while the header is open. Null where the list is
  /// only there to pick from, such as the invoice product picker.
  final VoidCallback? onRename;

  /// Puts a tick box in place of the arrow that selects the whole
  /// sub-category. See [_GroupCheckbox] for [selected].
  final ValueChanged<bool>? onSelect;
  final bool? selected;

  const SubCategoryHeader({
    super.key,
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onTap,
    this.onRename,
    this.onSelect,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg(context),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: EdgeInsets.only(left: onSelect != null ? 20 : 32, right: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.borderOf(context)),
            ),
          ),
          child: Row(
            children: [
              if (onSelect != null)
                _GroupCheckbox(selected: selected, onSelect: onSelect!)
              else
                Icon(
                  Icons.subdirectory_arrow_right,
                  size: 15,
                  color: isExpanded
                      ? AppTheme.primary
                      : AppTheme.onSurfaceVariant(context),
                ),
              const SizedBox(width: 8),
              // The label and its count share one flexible box so the chevron
              // keeps the same position whatever the label's length.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: isExpanded
                              ? AppTheme.primary
                              : AppTheme.onSurface(context),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isExpanded && onRename != null)
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline, size: 17),
                  tooltip: 'Hernoemen',
                  onPressed: onRename,
                  color: AppTheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.expand_more,
                  size: 20,
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

class CategoryPickerSheet extends StatefulWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String title;
  final String noneLabel;
  final String hintText;

  const CategoryPickerSheet({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.title = 'Categorie',
    this.noneLabel = 'Geen categorie',
    this.hintText = 'Zoeken of nieuwe categorie...',
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
              Text(
                widget.title,
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
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            autofocus: true,
            // Doubles as the "new category" field, so names start capitalised.
            // Matching and storage lowercase anyway.
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: widget.hintText,
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
                  title: Text(widget.noneLabel),
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
