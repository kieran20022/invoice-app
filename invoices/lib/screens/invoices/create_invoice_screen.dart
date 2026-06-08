import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/business_info.dart';
import '../../models/invoice.dart';
import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/product_provider.dart';
import 'invoice_preview_screen.dart';

enum Caps { none, first, words, all }

String _toTitleCase(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class CreateInvoiceScreen extends StatefulWidget {
  final Invoice? editInvoice;
  final int initialStep;
  const CreateInvoiceScreen({
    super.key,
    this.editInvoice,
    this.initialStep = 0,
  });

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  late int _step;
  final _clientFormKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _initialized = false;

  // Client fields
  final _naam = TextEditingController();
  final _kenteken = TextEditingController();
  final _kmstand = TextEditingController();
  final _datumCtrl = TextEditingController();
  final _adres = TextEditingController();
  final _telefoonnummer = TextEditingController();
  final _productType = TextEditingController();
  DateTime _datum = DateTime.now();

  // Details fields
  final _notes = TextEditingController();
  final _taxRate = TextEditingController();
  final _currency = TextEditingController();

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep;
    _datumCtrl.text = DateFormat('dd-MM-yyyy').format(_datum);
    _taxRate.text = '21';
    _currency.text = '€';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final inv = widget.editInvoice;
    if (inv != null) {
      _naam.text = inv.clientNaam;
      _kenteken.text = inv.clientKenteken;
      _productType.text = inv.clientProductType;
      _kmstand.text = inv.clientKmstand;
      _adres.text = inv.clientAdres;
      _telefoonnummer.text = inv.clientTelefoonnummer;
      _notes.text = inv.notes;
      _taxRate.text = inv.taxRate.toStringAsFixed(0);
      _currency.text = inv.currency;
      if (inv.clientDatum.isNotEmpty) {
        try {
          _datum = DateFormat('dd-MM-yyyy').parse(inv.clientDatum);
        } catch (_) {}
        _datumCtrl.text = inv.clientDatum;
      }
      context.read<InvoiceProvider>().startEditDraft(inv);
      return;
    }

    final business = context.read<BusinessProvider>().businessInfo;
    if (business != null) {
      context.read<InvoiceProvider>().startNewDraft(business);
      _notes.text = business.defaultNotes ?? '';
      _taxRate.text = business.defaultTaxRate.toString();
      _currency.text = business.currency;
    } else {
      context.read<InvoiceProvider>().startNewDraft(
        BusinessInfo(id: '', name: '', kvk: '', iban: ''),
      );
      _taxRate.text = '21';
      _currency.text = '€';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _naam,
      _kenteken,
      _kmstand,
      _datumCtrl,
      _adres,
      _telefoonnummer,
      _productType,
      _notes,
      _taxRate,
      _currency,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (!_clientFormKey.currentState!.validate()) return;
      context.read<InvoiceProvider>().updateDraftClient(
        naam: _naam.text.trim(),
        kenteken: _kenteken.text.trim(),
        productType: _productType.text.trim(),
        kmstand: _kmstand.text.trim(),
        datum: _datumCtrl.text.trim(),
        adres: _adres.text.trim(),
        telefoonnummer: _telefoonnummer.text.trim(),
      );
      setState(() => _step++);
    } else if (_step == 1) {
      final draft = context.read<InvoiceProvider>().draft;
      if (draft == null || draft.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voeg minimaal één Product toe'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() => _step++);
    } else if (_step == 2) {
      context.read<InvoiceProvider>().updateDraftDetails(
        notes: _notes.text.trim(),
        taxRate: double.tryParse(_taxRate.text) ?? 21.0,
        issueDate: _datum,
        currency: _currency.text.trim().isEmpty ? '€' : _currency.text.trim(),
      );
      _saveAndPreview();
    }
  }

  Future<void> _saveAndPreview() async {
    setState(() => _saving = true);
    try {
      final saved = await context.read<InvoiceProvider>().saveDraft();
      if (!mounted) return;
      if (widget.editInvoice != null) {
        Navigator.of(context).pop(saved);
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => InvoicePreviewScreen(invoice: saved),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij opslaan: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _saving = false);
    }
  }

  void _showProductPicker() {
    final products = context.read<ProductProvider>().products;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Geen opgeslagen producten. Voeg ze toe via het Producten tabblad.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(products: products),
    );
  }

  void _showItemForm({InvoiceItem? item}) {
    final draft = context.read<InvoiceProvider>().draft;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ItemFormSheet(
        item: item,
        taxRate: draft?.taxRate ?? 21.0,
        currency: draft?.currency ?? '€',
      ),
    );
  }

  static const _stepLabels = ['Klantgegevens', 'Producten', 'Details'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editInvoice != null ? 'Factuur bewerken' : 'Nieuwe factuur',
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.read<InvoiceProvider>().clearDraft();
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          _StepHeader(
            current: _step,
            labels: _stepLabels,
            onTap: (s) {
              if (s < _step) setState(() => _step = s);
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: _buildStepContent(),
              ),
            ),
          ),
          _buildNavBar(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _ClientStep(
          formKey: _clientFormKey,
          naam: _naam,
          kenteken: _kenteken,
          productType: _productType,
          kmstand: _kmstand,
          datumCtrl: _datumCtrl,
          adres: _adres,
          telefoonnummer: _telefoonnummer,
          datum: _datum,
          onDatumChanged: (d) {
            setState(() {
              _datum = d;
              _datumCtrl.text = DateFormat('dd-MM-yyyy').format(d);
            });
          },
        );
      case 1:
        return _ItemsStep(onEditItem: (item) => _showItemForm(item: item));
      case 2:
        return _DetailsStep(
          notes: _notes,
          taxRate: _taxRate,
          currency: _currency,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavBar() {
    final isLast = _step == 2;
    final isItems = _step == 1;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        border: Border(top: BorderSide(color: AppTheme.borderOf(context))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: isItems
              ? Row(
                  children: [
                    Expanded(
                      child: _navIconBtn(
                        icon: Icons.arrow_back,
                        onPressed: _saving
                            ? null
                            : () => setState(() => _step--),
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _navIconBtn(
                        icon: Icons.inventory_2_outlined,
                        onPressed: _saving ? null : _showProductPicker,
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _navIconBtn(
                        icon: Icons.add,
                        onPressed: _saving ? null : () => _showItemForm(),
                        filled: false,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _navIconBtn(
                        icon: Icons.arrow_forward,
                        onPressed: _saving ? null : _next,
                        filled: true,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: _step > 0
                          ? OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _step--),
                              child: const Text('Terug'),
                            )
                          : const SizedBox(height: 48),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _next,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                isLast
                                    ? Icons.visibility_outlined
                                    : Icons.arrow_forward,
                                size: 18,
                              ),
                        label: Text(
                          _saving
                              ? 'Bezig...'
                              : isLast
                              ? 'Naar Factuur'
                              : 'Volgende',
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _navIconBtn({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool filled,
  }) {
    const size = Size(double.infinity, 48);
    return filled
        ? ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: size,
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: 20),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              padding: EdgeInsets.zero,
            ),
            child: Icon(icon, size: 20),
          );
  }
}

// ── Step header ────────────────────────────────────────────────────────────

class _StepHeader extends StatelessWidget {
  final int current;
  final List<String> labels;
  final ValueChanged<int> onTap;

  const _StepHeader({
    required this.current,
    required this.labels,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surf(context),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (index) {
          // Even indices = step chip, odd indices = connector line
          if (index.isOdd) {
            final i = index ~/ 2;
            return Expanded(
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: i < current ? AppTheme.primary : AppTheme.borderOf(context),
              ),
            );
          }

          final i = index ~/ 2;
          final done = i < current;
          final active = i == current;

          return GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done || active
                        ? AppTheme.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: done || active
                          ? AppTheme.primary
                          : AppTheme.onSurfaceVariant(context),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : AppTheme.onSurfaceVariant(context),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  labels[i],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.normal,
                    color: active
                        ? AppTheme.primary
                        : done
                        ? AppTheme.onSurface(context)
                        : AppTheme.onSurfaceVariant(context),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Stap 1: Klantgegevens ──────────────────────────────────────────────────

class _ClientStep extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController naam,
      kenteken,
      kmstand,
      datumCtrl,
      adres,
      telefoonnummer,
      productType;
  final DateTime datum;
  final ValueChanged<DateTime> onDatumChanged;

  const _ClientStep({
    required this.formKey,
    required this.naam,
    required this.kenteken,
    required this.kmstand,
    required this.datumCtrl,
    required this.adres,
    required this.telefoonnummer,
    required this.productType,
    required this.datum,
    required this.onDatumChanged,
  });

  @override
  State<_ClientStep> createState() => _ClientStepState();
}

class _ClientStepState extends State<_ClientStep> {
  final _naamFocus = FocusNode();
  final _kenterkenFocus = FocusNode();
  final _productTypeFocus = FocusNode();
  final _kmstandFocus = FocusNode();
  final _adresFocus = FocusNode();
  final _telefoonnummerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _naamFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _naamFocus.dispose();
    _kenterkenFocus.dispose();
    _productTypeFocus.dispose();
    _kmstandFocus.dispose();
    _adresFocus.dispose();
    _telefoonnummerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        children: [
          _tf(
            widget.naam,
            'Naam *',
            required: true,
            focusNode: _naamFocus,
            nextFocus: _kenterkenFocus,
            caps: Caps.words,
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: Listenable.merge([widget.kenteken, widget.productType]),
            builder: (context, _) {
              final hasKenteken = widget.kenteken.text.trim().isNotEmpty;
              final hasProductType = widget.productType.text.trim().isNotEmpty;
              return Column(
                children: [
                  _tf(
                    widget.kenteken,
                    'Kenteken',
                    required: false,
                    focusNode: _kenterkenFocus,
                    nextFocus: _productTypeFocus,
                    caps: Caps.all,
                    enabled: !hasProductType,
                  ),
                  const SizedBox(height: 12),
                  _tf(
                    widget.productType,
                    'Product Type',
                    required: false,
                    focusNode: _productTypeFocus,
                    nextFocus: _kmstandFocus,
                    caps: Caps.first,
                    enabled: !hasKenteken,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          _tf(
            widget.kmstand,
            'Km-stand',
            required: false,
            type: TextInputType.number,
            focusNode: _kmstandFocus,
            nextFocus: _adresFocus,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.datum,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) widget.onDatumChanged(picked);
            },
            child: AbsorbPointer(
              child: TextFormField(
                controller: widget.datumCtrl,
                decoration: const InputDecoration(
                  labelText: 'Datum *',
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Verplicht' : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _tf(
            widget.adres,
            'Adres (optioneel)',
            focusNode: _adresFocus,
            nextFocus: _telefoonnummerFocus,
            caps: Caps.first,
          ),
          const SizedBox(height: 12),
          _tf(
            widget.telefoonnummer,
            'Telefoonnummer (optioneel)',
            type: TextInputType.phone,
            focusNode: _telefoonnummerFocus,
          ),
        ],
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool required = false,
    bool enabled = true,
    TextInputType? type,
    FocusNode? focusNode,
    FocusNode? nextFocus,
    Caps caps = Caps.none,
  }) => TextFormField(
    controller: c,
    enabled: enabled,
    keyboardType: type,
    focusNode: focusNode,
    textCapitalization: switch (caps) {
      Caps.none => TextCapitalization.none,
      Caps.first => TextCapitalization.sentences,
      Caps.words => TextCapitalization.words,
      Caps.all => TextCapitalization.characters,
    },
    textInputAction: nextFocus != null
        ? TextInputAction.next
        : TextInputAction.done,
    onFieldSubmitted: nextFocus != null
        ? (_) => FocusScope.of(context).requestFocus(nextFocus)
        : null,
    decoration: InputDecoration(labelText: label),
    validator: required
        ? (v) => v == null || v.trim().isEmpty ? 'Verplicht' : null
        : null,
  );
}

// ── Stap 2: Producten ─────────────────────────────────────────────────────────

class _ItemsStep extends StatelessWidget {
  final ValueChanged<InvoiceItem> onEditItem;

  const _ItemsStep({required this.onEditItem});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoiceProvider>();
    final items = provider.draft?.items ?? [];
    final currency = provider.draft?.currency ?? '€';
    final taxRate = provider.draft?.taxRate ?? 21.0;

    return Column(
      children: [
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.bg(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderOf(context)),
            ),
            child: const Center(
              child: Text(
                'Nog geen Producten. Voeg producten toe of maak een aangepaste Product aan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          ...items.map(
            (item) => _ItemRow(
              item: item,
              currency: currency,
              taxRate: taxRate,
              onEdit: () => onEditItem(item),
              onDelete: () =>
                  context.read<InvoiceProvider>().removeDraftItem(item.id),
              onQtyChanged: (qty) => context
                  .read<InvoiceProvider>()
                  .updateDraftItem(item.copyWith(aantal: qty)),
            ),
          ),

        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(AppTheme.isDark(context) ? 38 : 13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotaal incl. BTW',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface(context),
                  ),
                ),
                Text(
                  '$currency${provider.draft!.totaalInclBtw.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InvoiceItem item;
  final String currency;
  final double taxRate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<double> onQtyChanged;

  const _ItemRow({
    required this.item,
    required this.currency,
    required this.taxRate,
    required this.onEdit,
    required this.onDelete,
    required this.onQtyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surf(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.omschrijving,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$currency${item.prijsExBtw.toStringAsFixed(2)} ex. BTW → '
                  '$currency${item.prijsInclBtw(taxRate).toStringAsFixed(2)} incl.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _QtyBtn(
                    icon: Icons.remove,
                    onTap: item.aantal > 1
                        ? () => onQtyChanged(item.aantal - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      _fmtQty(item.aantal),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  _QtyBtn(
                    icon: Icons.add,
                    onTap: () => onQtyChanged(item.aantal + 1),
                  ),
                ],
              ),
              Text(
                '$currency${item.totalInclBtw(taxRate).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),

          const SizedBox(width: 4),
          Column(
            children: [
              GestureDetector(
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmtQty(double qty) =>
      qty == qty.truncateToDouble() ? qty.toInt().toString() : qty.toString();
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: onTap != null
              ? AppTheme.primary.withAlpha(20)
              : AppTheme.border.withAlpha(80),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? AppTheme.primary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Product> products;
  const _ProductPickerSheet({required this.products});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String? _selectedCategory;

  List<String> get _categories {
    final cats =
        widget.products
            .map((p) => p.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return cats;
  }

  /// Returns the raw category filter string from `#text` (lowercased, no `#`),
  /// or null if the search doesn't start with `#`.
  String? get _hashFilter {
    final raw = _searchCtrl.text.trim();
    if (!raw.startsWith('#')) return null;
    final part = raw.substring(1).split(' ').first.toLowerCase();
    return part.isEmpty ? null : part;
  }

  List<Product> get _filtered {
    final raw = _searchCtrl.text.trim();

    if (raw.startsWith('#')) {
      final spaceIdx = raw.indexOf(' ');
      final categoryPart = raw.substring(1, spaceIdx == -1 ? raw.length : spaceIdx).toLowerCase();
      final searchPart = spaceIdx == -1 ? '' : raw.substring(spaceIdx + 1).toLowerCase().trim();

      var list = categoryPart.isEmpty
          ? widget.products
          : widget.products.where((p) => p.category.contains(categoryPart)).toList();

      if (searchPart.isNotEmpty) {
        list = list
            .where((p) =>
                p.name.toLowerCase().contains(searchPart) ||
                p.description.toLowerCase().contains(searchPart))
            .toList();
      }
      return list;
    }

    var list = widget.products;
    if (_selectedCategory != null) {
      list = list.where((p) => p.category == _selectedCategory).toList();
    }
    final q = raw.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<InvoiceProvider>().draft?.currency ?? '€';
    final categories = _categories;
    final filtered = _filtered;
    final favorites = context.watch<BusinessProvider>().favoriteCategories;
    final favCategories = categories
        .where((c) => favorites.contains(c))
        .toList();
    final hashFilter = _hashFilter;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                const Text(
                  'Product selecteren',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Zoeken... of #categorie product',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchCtrl.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    if (!_searchCtrl.text.startsWith('#')) {
                      _searchCtrl.value = TextEditingValue(
                        text: '#${_searchCtrl.text}',
                        selection: const TextSelection.collapsed(offset: 1),
                      );
                    }
                    _searchFocus.requestFocus();
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    padding: EdgeInsets.zero,
                    side: BorderSide(color: AppTheme.primary.withAlpha(80)),
                  ),
                  child: const Text(
                    '#',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Category chips
          if (categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _CategoryChip(
                    label: 'Alle',
                    selected: hashFilter == null && _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                  ),
                  ...categories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _CategoryChip(
                        label: _toTitleCase(cat),
                        selected: hashFilter != null
                            ? cat.contains(hashFilter)
                            : _selectedCategory == cat,
                        isFavorite: favorites.contains(cat),
                        onTap: () => setState(() => _selectedCategory = cat),
                        onLongPress: () => context
                            .read<BusinessProvider>()
                            .toggleFavoriteCategory(cat),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (favCategories.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: favCategories
                      .map(
                        (cat) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CategoryChip(
                            label: _toTitleCase(cat),
                            selected: hashFilter != null
                                ? cat.contains(hashFilter)
                                : _selectedCategory == cat,
                            isFavorite: true,
                            onTap: () =>
                                setState(() => _selectedCategory = cat),
                            onLongPress: () => context
                                .read<BusinessProvider>()
                                .toggleFavoriteCategory(cat),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
          const Divider(height: 16),
          // Product list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Geen producten gevonden.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final p = filtered[i];
                      return ListTile(
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: p.description.isNotEmpty
                            ? Text(p.description)
                            : null,
                        trailing: Text(
                          '$currency${p.price.toStringAsFixed(2)} ex. BTW',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          final item = context
                              .read<InvoiceProvider>()
                              .createItem(
                                omschrijving: p.name,
                                aantal: 1,
                                prijsExBtw: p.price,
                                productId: p.id,
                              );
                          context.read<InvoiceProvider>().addDraftItem(item);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryChip({
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
        selectedColor: AppTheme.primary,
        backgroundColor: isFavorite
            ? Colors.amber.withAlpha(45)
            : AppTheme.primary.withAlpha(15),
        side: BorderSide(
          color: selected
              ? AppTheme.primary
              : isFavorite
                  ? Colors.amber.withAlpha(130)
                  : AppTheme.primary.withAlpha(50),
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

class _ItemFormSheet extends StatefulWidget {
  final InvoiceItem? item;
  final double taxRate;
  final String currency;
  const _ItemFormSheet({
    this.item,
    required this.taxRate,
    required this.currency,
  });

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _omschrijving;
  late final TextEditingController _aantal;
  late final TextEditingController _prijsExcl;
  late final TextEditingController _prijsIncl;
  bool _updatingPrice = false;

  final _omschrijvingFocus = FocusNode();
  final _aantalFocus = FocusNode();
  final _prijsExclFocus = FocusNode();
  final _prijsInclFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _omschrijving = TextEditingController(
      text: widget.item?.omschrijving ?? '',
    );
    _aantal = TextEditingController(
      text: widget.item?.aantal.toString() ?? '1',
    );

    final excl = widget.item?.prijsExBtw;
    _prijsExcl = TextEditingController(
      text: excl != null ? excl.toStringAsFixed(2) : '',
    );
    _prijsIncl = TextEditingController(
      text: excl != null
          ? (excl * (1 + widget.taxRate / 100)).toStringAsFixed(2)
          : '',
    );

    _prijsExcl.addListener(_onExclChanged);
    _prijsIncl.addListener(_onInclChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _omschrijvingFocus.requestFocus();
    });
  }

  void _onExclChanged() {
    if (_updatingPrice) return;
    _updatingPrice = true;
    final excl = double.tryParse(_prijsExcl.text);
    if (excl != null) {
      _prijsIncl.text = (excl * (1 + widget.taxRate / 100)).toStringAsFixed(2);
    } else if (_prijsExcl.text.isEmpty) {
      _prijsIncl.text = '';
    }
    _updatingPrice = false;
  }

  void _onInclChanged() {
    if (_updatingPrice) return;
    _updatingPrice = true;
    final incl = double.tryParse(_prijsIncl.text);
    if (incl != null) {
      _prijsExcl.text = (incl / (1 + widget.taxRate / 100)).toStringAsFixed(2);
    } else if (_prijsIncl.text.isEmpty) {
      _prijsExcl.text = '';
    }
    _updatingPrice = false;
  }

  @override
  void dispose() {
    _omschrijving.dispose();
    _aantal.dispose();
    _prijsExcl.dispose();
    _prijsIncl.dispose();
    _omschrijvingFocus.dispose();
    _aantalFocus.dispose();
    _prijsExclFocus.dispose();
    _prijsInclFocus.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InvoiceProvider>();
    if (widget.item != null) {
      provider.updateDraftItem(
        widget.item!.copyWith(
          omschrijving: _omschrijving.text.trim(),
          aantal: double.tryParse(_aantal.text) ?? 1,
          prijsExBtw: double.tryParse(_prijsExcl.text) ?? 0,
        ),
      );
    } else {
      provider.addDraftItem(
        provider.createItem(
          omschrijving: _omschrijving.text.trim(),
          aantal: double.tryParse(_aantal.text) ?? 1,
          prijsExBtw: double.tryParse(_prijsExcl.text) ?? 0,
        ),
      );
    }
    Navigator.pop(context);
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                  widget.item == null
                      ? 'Product toevoegen'
                      : 'Product bewerken',
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
            TextFormField(
              controller: _omschrijving,
              focusNode: _omschrijvingFocus,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.sentences,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_aantalFocus),
              decoration: const InputDecoration(labelText: 'Omschrijving *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aantal,
              focusNode: _aantalFocus,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_prijsExclFocus),
              decoration: const InputDecoration(labelText: 'Aantal *'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Verplicht';
                if (double.tryParse(v) == null) return 'Ongeldig';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prijsExcl,
                    focusNode: _prijsExclFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_prijsInclFocus),
                    decoration: InputDecoration(
                      labelText: 'Prijs ex. BTW *',
                      prefixText: '${widget.currency} ',
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
                    controller: _prijsIncl,
                    focusNode: _prijsInclFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: 'Prijs incl. BTW *',
                      prefixText: '${widget.currency} ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(widget.item == null ? 'Toevoegen' : 'Opslaan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stap 3: Details ────────────────────────────────────────────────────────

class _DetailsStep extends StatelessWidget {
  final TextEditingController notes, taxRate, currency;

  const _DetailsStep({
    required this.notes,
    required this.taxRate,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: currency,
                decoration: const InputDecoration(
                  labelText: 'Valutasymbool',
                  hintText: '€',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: taxRate,
                decoration: const InputDecoration(labelText: 'BTW (%)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notes,
          decoration: const InputDecoration(
            labelText: 'Opmerkingen',
            hintText: 'Eventuele opmerkingen bij de factuur',
          ),
          maxLines: 4,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
