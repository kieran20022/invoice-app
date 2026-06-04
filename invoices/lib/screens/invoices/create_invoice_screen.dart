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

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  int _step = 0;
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
  DateTime _datum = DateTime.now();

  // Details fields
  final _notes = TextEditingController();
  final _taxRate = TextEditingController();
  final _currency = TextEditingController();

  @override
  void initState() {
    super.initState();
    _datumCtrl.text = DateFormat('dd-MM-yyyy').format(_datum);
    _taxRate.text = '21';
    _currency.text = '€';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final business = context.read<BusinessProvider>().businessInfo;
    if (business != null) {
      context.read<InvoiceProvider>().startNewDraft(business);
      _notes.text = business.defaultNotes ?? '';
      _taxRate.text = business.defaultTaxRate.toString();
      _currency.text = business.currency;
    } else {
      context.read<InvoiceProvider>().startNewDraft(
        BusinessInfo(id: '', name: '', email: ''),
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InvoicePreviewScreen(invoice: saved)),
      );
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

  static const _stepLabels = ['Klantgegevens', 'Producten', 'Details'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuwe factuur'),
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
              child: _buildStepContent(),
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
        return const _ItemsStep();
      case 2:
        return _DetailsStep(
          notes: _notes,
          taxRate: _taxRate,
          currency: _currency,
          onSubmit: _next,
          saving: _saving,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNavBar() {
    // On step 2 the continue button lives inside _DetailsStep itself,
    // so the nav bar only shows the back button.
    if (_step == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => setState(() => _step--),
            child: const Text('Terug'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Terug'),
            ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: _saving ? null : _next,
                child: const Text('Volgende'),
              ),
            ),
          ),
        ],
      ),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(labels.length, (i) {
          final done = i < current;
          final active = i == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Row(
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
                            : AppTheme.textSecondary,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: done
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : AppTheme.textSecondary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.normal,
                        color: active
                            ? AppTheme.primary
                            : done
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (i < labels.length - 1) ...[
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 1.5,
                        color: i < current ? AppTheme.primary : AppTheme.border,
                      ),
                    ),
                  ],
                ],
              ),
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
      telefoonnummer;
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
    required this.datum,
    required this.onDatumChanged,
  });

  @override
  State<_ClientStep> createState() => _ClientStepState();
}

class _ClientStepState extends State<_ClientStep> {
  final _naamFocus = FocusNode();
  final _kenterkenFocus = FocusNode();
  final _kmstandFocus = FocusNode();
  final _adresFocus = FocusNode();
  final _telefoonnummerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) { if (mounted) _naamFocus.requestFocus(); },
    );
  }

  @override
  void dispose() {
    _naamFocus.dispose();
    _kenterkenFocus.dispose();
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
          _tf(widget.naam, 'Naam *',
              required: true,
              focusNode: _naamFocus,
              nextFocus: _kenterkenFocus),
          const SizedBox(height: 12),
          _tf(widget.kenteken, 'Kenteken *',
              required: true,
              focusNode: _kenterkenFocus,
              nextFocus: _kmstandFocus),
          const SizedBox(height: 12),
          _tf(widget.kmstand, 'Km-stand *',
              required: true,
              type: TextInputType.number,
              focusNode: _kmstandFocus,
              nextFocus: _adresFocus),
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
          _tf(widget.adres, 'Adres (optioneel)',
              focusNode: _adresFocus,
              nextFocus: _telefoonnummerFocus),
          const SizedBox(height: 12),
          _tf(widget.telefoonnummer, 'Telefoonnummer (optioneel)',
              type: TextInputType.phone,
              focusNode: _telefoonnummerFocus),
        ],
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? type,
    FocusNode? focusNode,
    FocusNode? nextFocus,
  }) => TextFormField(
    controller: c,
    keyboardType: type,
    focusNode: focusNode,
    textInputAction:
        nextFocus != null ? TextInputAction.next : TextInputAction.done,
    onFieldSubmitted:
        nextFocus != null
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
  const _ItemsStep();

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
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
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
              onEdit: () => _showItemForm(context, item: item),
              onDelete: () =>
                  context.read<InvoiceProvider>().removeDraftItem(item.id),
              onQtyChanged: (qty) => context
                  .read<InvoiceProvider>()
                  .updateDraftItem(item.copyWith(aantal: qty)),
            ),
          ),

        const SizedBox(height: 12),

        if (items.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withAlpha(13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Subtotaal incl. BTW',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
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
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showProductPicker(context),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Uit producten'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showItemForm(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Aangepaste Product'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showProductPicker(BuildContext context) {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(products: products),
    );
  }

  void _showItemForm(BuildContext context, {InvoiceItem? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ItemFormSheet(item: item),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
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

class _ProductPickerSheet extends StatelessWidget {
  final List<Product> products;
  const _ProductPickerSheet({required this.products});

  @override
  Widget build(BuildContext context) {
    final currency = context.read<InvoiceProvider>().draft?.currency ?? '€';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
        const Divider(),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: products.length,
            itemBuilder: (ctx, i) {
              final p = products[i];
              return ListTile(
                title: Text(
                  p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: p.description.isNotEmpty ? Text(p.description) : null,
                trailing: Text(
                  '$currency${p.price.toStringAsFixed(2)} ex. BTW',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  final item = context.read<InvoiceProvider>().createItem(
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
    );
  }
}

class _ItemFormSheet extends StatefulWidget {
  final InvoiceItem? item;
  const _ItemFormSheet({this.item});

  @override
  State<_ItemFormSheet> createState() => _ItemFormSheetState();
}

class _ItemFormSheetState extends State<_ItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _omschrijving;
  late final TextEditingController _aantal;
  late final TextEditingController _prijs;

  final _omschrijvingFocus = FocusNode();
  final _aantalFocus = FocusNode();
  final _prijsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _omschrijving = TextEditingController(
      text: widget.item?.omschrijving ?? '',
    );
    _aantal = TextEditingController(
      text: widget.item?.aantal.toString() ?? '1',
    );
    _prijs = TextEditingController(
      text: widget.item?.prijsExBtw.toStringAsFixed(2) ?? '',
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) { if (mounted) _omschrijvingFocus.requestFocus(); },
    );
  }

  @override
  void dispose() {
    _omschrijving.dispose();
    _aantal.dispose();
    _prijs.dispose();
    _omschrijvingFocus.dispose();
    _aantalFocus.dispose();
    _prijsFocus.dispose();
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
          prijsExBtw: double.tryParse(_prijs.text) ?? 0,
        ),
      );
    } else {
      provider.addDraftItem(
        provider.createItem(
          omschrijving: _omschrijving.text.trim(),
          aantal: double.tryParse(_aantal.text) ?? 1,
          prijsExBtw: double.tryParse(_prijs.text) ?? 0,
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.read<InvoiceProvider>().draft?.currency ?? '€';
    final taxRate = context.read<InvoiceProvider>().draft?.taxRate ?? 21.0;

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
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_aantalFocus),
              decoration: const InputDecoration(labelText: 'Omschrijving *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Verplicht' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _aantal,
                    focusNode: _aantalFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_prijsFocus),
                    decoration: const InputDecoration(labelText: 'Aantal *'),
                    keyboardType: TextInputType.number,
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
                    controller: _prijs,
                    focusNode: _prijsFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: InputDecoration(
                      labelText: 'Prijs ex. BTW *',
                      prefixText: '$currency ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Verplicht';
                      if (double.tryParse(v) == null) return 'Ongeldig';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _prijs,
              builder: (context, value, _) {
                final ex = double.tryParse(value.text) ?? 0;
                final incl = ex * (1 + taxRate / 100);
                return Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Incl. BTW: $currency${incl.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                );
              },
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
  final VoidCallback onSubmit;
  final bool saving;

  const _DetailsStep({
    required this.notes,
    required this.taxRate,
    required this.currency,
    required this.onSubmit,
    required this.saving,
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
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: saving ? null : onSubmit,
            icon: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.visibility_outlined, size: 18),
            label: Text(saving ? 'Bezig...' : 'Factuur bekijken'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
