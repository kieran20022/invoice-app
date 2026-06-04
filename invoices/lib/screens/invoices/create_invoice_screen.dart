import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
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
  final _detailsFormKey = GlobalKey<FormState>();

  // Client fields
  final _clientName = TextEditingController();
  final _clientCompany = TextEditingController();
  final _clientEmail = TextEditingController();
  final _clientPhone = TextEditingController();
  final _clientAddress = TextEditingController();
  final _clientCity = TextEditingController();
  final _clientState = TextEditingController();
  final _clientZip = TextEditingController();
  final _clientCountry = TextEditingController();

  // Details fields
  final _notes = TextEditingController();
  final _terms = TextEditingController();
  final _taxRate = TextEditingController();
  final _currency = TextEditingController();
  DateTime _issueDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final business = context.read<BusinessProvider>().businessInfo;
      if (business != null) {
        context.read<InvoiceProvider>().startNewDraft(business);
        _notes.text = business.defaultNotes ?? '';
        _terms.text = business.defaultPaymentTerms;
        _taxRate.text = business.defaultTaxRate.toString();
        _currency.text = business.currency;
      }
    });
  }

  @override
  void dispose() {
    for (final c in [
      _clientName, _clientCompany, _clientEmail, _clientPhone,
      _clientAddress, _clientCity, _clientState, _clientZip, _clientCountry,
      _notes, _terms, _taxRate, _currency,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _continue() {
    if (_step == 0) {
      if (!_clientFormKey.currentState!.validate()) return;
      context.read<InvoiceProvider>().updateDraftClient(
        name: _clientName.text.trim(),
        company: _clientCompany.text.trim(),
        email: _clientEmail.text.trim(),
        phone: _clientPhone.text.trim(),
        address: _clientAddress.text.trim(),
        city: _clientCity.text.trim(),
        state: _clientState.text.trim(),
        zip: _clientZip.text.trim(),
        country: _clientCountry.text.trim(),
      );
      setState(() => _step++);
    } else if (_step == 1) {
      setState(() => _step++);
    } else if (_step == 2) {
      final draft = context.read<InvoiceProvider>().draft;
      if (draft == null || draft.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please add at least one item'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() => _step++);
    } else if (_step == 3) {
      if (!_detailsFormKey.currentState!.validate()) return;
      context.read<InvoiceProvider>().updateDraftDetails(
        notes: _notes.text.trim(),
        terms: _terms.text.trim(),
        taxRate: double.tryParse(_taxRate.text) ?? 0.0,
        issueDate: _issueDate,
        dueDate: _dueDate,
        currency: _currency.text.trim().isEmpty ? '\$' : _currency.text.trim(),
      );
      _goToPreview();
    }
  }

  void _goToPreview() async {
    final invoiceProvider = context.read<InvoiceProvider>();
    try {
      final saved = await invoiceProvider.saveDraft();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoicePreviewScreen(invoice: saved),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving invoice: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Invoice'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.read<InvoiceProvider>().clearDraft();
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
        ),
      ),
      body: Stepper(
        currentStep: _step,
        physics: const ClampingScrollPhysics(),
        onStepTapped: (s) {
          if (s < _step) setState(() => _step = s);
        },
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _continue,
                  child: Text(_step == 3 ? 'Preview Invoice' : 'Continue'),
                ),
              ),
              const SizedBox(width: 12),
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Back'),
                  ),
                ),
            ],
          ),
        ),
        steps: [
          Step(
            title: const Text('Client Info'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: _ClientStep(
              formKey: _clientFormKey,
              name: _clientName,
              company: _clientCompany,
              email: _clientEmail,
              phone: _clientPhone,
              address: _clientAddress,
              city: _clientCity,
              state: _clientState,
              zip: _clientZip,
              country: _clientCountry,
            ),
          ),
          Step(
            title: const Text('Template'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: const _TemplateStep(),
          ),
          Step(
            title: const Text('Items'),
            isActive: _step >= 2,
            state: _step > 2 ? StepState.complete : StepState.indexed,
            content: const _ItemsStep(),
          ),
          Step(
            title: const Text('Details'),
            isActive: _step >= 3,
            state: StepState.indexed,
            content: _DetailsStep(
              formKey: _detailsFormKey,
              notes: _notes,
              terms: _terms,
              taxRate: _taxRate,
              currency: _currency,
              issueDate: _issueDate,
              dueDate: _dueDate,
              onIssueDateChanged: (d) => setState(() => _issueDate = d),
              onDueDateChanged: (d) => setState(() => _dueDate = d),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Client ─────────────────────────────────────────────────────────

class _ClientStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController name, company, email, phone;
  final TextEditingController address, city, state, zip, country;

  const _ClientStep({
    required this.formKey,
    required this.name,
    required this.company,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.country,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          _tf(name, 'Client Name *', required: true),
          _tf(company, 'Company (optional)'),
          _tf(email, 'Email Address *',
              type: TextInputType.emailAddress, required: true),
          _tf(phone, 'Phone', type: TextInputType.phone),
          _tf(address, 'Street Address'),
          Row(children: [
            Expanded(child: _tf(city, 'City')),
            const SizedBox(width: 12),
            Expanded(child: _tf(state, 'State')),
          ]),
          Row(children: [
            Expanded(child: _tf(zip, 'Postal Code')),
            const SizedBox(width: 12),
            Expanded(child: _tf(country, 'Country')),
          ]),
        ],
      ),
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool required = false,
    TextInputType? type,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label),
          validator:
              required ? (v) => v == null || v.trim().isEmpty ? 'Required' : null : null,
        ),
      );
}

// ── Step 2: Template ───────────────────────────────────────────────────────

class _TemplateStep extends StatelessWidget {
  const _TemplateStep();

  @override
  Widget build(BuildContext context) {
    final draft = context.watch<InvoiceProvider>().draft;
    final selected = draft?.template ?? 'modern';

    return Column(
      children: [
        _TemplateCard(
          id: 'modern',
          title: 'Modern',
          subtitle: 'Bold colored header, clean grid layout',
          selected: selected == 'modern',
          onTap: () =>
              context.read<InvoiceProvider>().updateDraftTemplate('modern'),
          color: AppTheme.primary,
        ),
        const SizedBox(height: 10),
        _TemplateCard(
          id: 'classic',
          title: 'Classic',
          subtitle: 'Traditional bordered invoice, professional look',
          selected: selected == 'classic',
          onTap: () =>
              context.read<InvoiceProvider>().updateDraftTemplate('classic'),
          color: const Color(0xFF374151),
        ),
        const SizedBox(height: 10),
        _TemplateCard(
          id: 'minimal',
          title: 'Minimal',
          subtitle: 'Clean and elegant with subtle lines',
          selected: selected == 'minimal',
          onTap: () =>
              context.read<InvoiceProvider>().updateDraftTemplate('minimal'),
          color: const Color(0xFF10B981),
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final String id, title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _TemplateCard({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? color : AppTheme.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected ? color.withAlpha(13) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 60,
              decoration: BoxDecoration(
                color: color.withAlpha(26),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withAlpha(51)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 8,
                    width: 32,
                    color: color,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                  Container(
                    height: 4,
                    width: 32,
                    color: color.withAlpha(77),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                  Container(
                    height: 4,
                    width: 32,
                    color: color.withAlpha(77),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: selected ? color : AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Items ──────────────────────────────────────────────────────────

class _ItemsStep extends StatelessWidget {
  const _ItemsStep();

  @override
  Widget build(BuildContext context) {
    final invoiceProvider = context.watch<InvoiceProvider>();
    final items = invoiceProvider.draft?.items ?? [];
    final currency = invoiceProvider.draft?.currency ?? '\$';

    return Column(
      children: [
        // Item list
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
                'No items yet. Add products from your list or create custom items.',
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
              onEdit: () => _showItemForm(context, item: item),
              onDelete: () =>
                  context.read<InvoiceProvider>().removeDraftItem(item.id),
            ),
          ),

        const SizedBox(height: 12),

        // Total bar
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
                const Text('Subtotal',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                Text(
                  '$currency${invoiceProvider.draft!.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                      fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Add buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showProductPicker(context),
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('From Products'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showItemForm(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Custom Item'),
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
          content: Text('No saved products. Add products in the Products tab.'),
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ItemRow({
    required this.item,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (item.description.isNotEmpty)
                  Text(item.description,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                Text(
                  '${item.quantity} × $currency${item.unitPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$currency${item.total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onEdit,
                    child: const Icon(Icons.edit_outlined,
                        size: 18, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        size: 18, color: AppTheme.error),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductPickerSheet extends StatelessWidget {
  final List<Product> products;
  const _ProductPickerSheet({required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              const Text('Select Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context)),
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
              final currency =
                  context.read<InvoiceProvider>().draft?.currency ?? '\$';
              return ListTile(
                title: Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: p.description.isNotEmpty ? Text(p.description) : null,
                trailing: Text('$currency${p.price.toStringAsFixed(2)}/${p.unit}',
                    style: const TextStyle(
                        color: AppTheme.primary, fontWeight: FontWeight.w600)),
                onTap: () {
                  final item = context.read<InvoiceProvider>().createItem(
                        name: p.name,
                        description: p.description,
                        quantity: 1,
                        unitPrice: p.price,
                        unit: p.unit,
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
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _unit;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item?.name ?? '');
    _description =
        TextEditingController(text: widget.item?.description ?? '');
    _qty = TextEditingController(
        text: widget.item?.quantity.toString() ?? '1');
    _price = TextEditingController(
        text: widget.item?.unitPrice.toStringAsFixed(2) ?? '');
    _unit = TextEditingController(text: widget.item?.unit ?? 'item');
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _qty.dispose();
    _price.dispose();
    _unit.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final invoiceProvider = context.read<InvoiceProvider>();

    if (widget.item != null) {
      invoiceProvider.updateDraftItem(widget.item!.copyWith(
        name: _name.text.trim(),
        description: _description.text.trim(),
        quantity: double.tryParse(_qty.text) ?? 1,
        unitPrice: double.tryParse(_price.text) ?? 0,
        unit: _unit.text.trim().isEmpty ? 'item' : _unit.text.trim(),
      ));
    } else {
      final item = invoiceProvider.createItem(
        name: _name.text.trim(),
        description: _description.text.trim(),
        quantity: double.tryParse(_qty.text) ?? 1,
        unitPrice: double.tryParse(_price.text) ?? 0,
        unit: _unit.text.trim().isEmpty ? 'item' : _unit.text.trim(),
      );
      invoiceProvider.addDraftItem(item);
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
                  widget.item == null ? 'Add Item' : 'Edit Item',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Item Name *'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qty,
                    decoration: const InputDecoration(labelText: 'Quantity *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Unit Price *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _save,
              child: Text(widget.item == null ? 'Add Item' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 4: Details ────────────────────────────────────────────────────────

class _DetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController notes, terms, taxRate, currency;
  final DateTime issueDate, dueDate;
  final ValueChanged<DateTime> onIssueDateChanged;
  final ValueChanged<DateTime> onDueDateChanged;

  const _DetailsStep({
    required this.formKey,
    required this.notes,
    required this.terms,
    required this.taxRate,
    required this.currency,
    required this.issueDate,
    required this.dueDate,
    required this.onIssueDateChanged,
    required this.onDueDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Issue Date',
                  date: issueDate,
                  onChanged: onIssueDateChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Due Date',
                  date: dueDate,
                  onChanged: onDueDateChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: currency,
                  decoration: const InputDecoration(
                    labelText: 'Currency Symbol',
                    hintText: '\$',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: taxRate,
                  decoration: const InputDecoration(labelText: 'Tax Rate (%)'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: terms,
            decoration: const InputDecoration(
              labelText: 'Payment Terms',
              hintText: 'Net 30',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: notes,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'e.g. Thank you for your business!',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DateField({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onChanged(picked);
      },
      child: AbsorbPointer(
        child: TextFormField(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
          controller: TextEditingController(
            text: '${date.day}/${date.month}/${date.year}',
          ),
        ),
      ),
    );
  }
}
