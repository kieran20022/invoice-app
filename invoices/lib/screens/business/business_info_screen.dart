import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/business_info.dart';
import '../../providers/auth_provider.dart';
import '../../providers/business_provider.dart';

class BusinessInfoScreen extends StatefulWidget {
  final bool isFirstTime;
  const BusinessInfoScreen({super.key, required this.isFirstTime});

  @override
  State<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends State<BusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _website;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zip;
  late final TextEditingController _country;
  late final TextEditingController _currency;
  late final TextEditingController _taxRate;
  late final TextEditingController _invoicePrefix;
  late final TextEditingController _notes;
  late final TextEditingController _startingNumber;
  late final TextEditingController _emailTemplate;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _email = TextEditingController();
    _phone = TextEditingController();
    _website = TextEditingController();
    _address = TextEditingController();
    _city = TextEditingController();
    _state = TextEditingController();
    _zip = TextEditingController();
    _country = TextEditingController();
    _currency = TextEditingController(text: '€');
    _taxRate = TextEditingController(text: '21');
    _invoicePrefix = TextEditingController(text: 'F');
    _notes = TextEditingController();
    _startingNumber = TextEditingController(text: '1');
    _emailTemplate = TextEditingController(text: BusinessInfo.kDefaultEmailTemplate);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _website, _address, _city, _state,
      _zip, _country, _currency, _taxRate, _invoicePrefix,
      _notes, _startingNumber, _emailTemplate,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(BusinessInfo info) {
    if (_initialized) return;
    _initialized = true;
    _name.text = info.name;
    _email.text = info.email;
    _phone.text = info.phone;
    _website.text = info.website;
    _address.text = info.address;
    _city.text = info.city;
    _state.text = info.state;
    _zip.text = info.zip;
    _country.text = info.country;
    _currency.text = info.currency;
    _taxRate.text = info.defaultTaxRate.toString();
    _invoicePrefix.text = info.invoicePrefix;
    _notes.text = info.defaultNotes ?? '';
    _startingNumber.text = info.nextInvoiceNumber.toString();
    _emailTemplate.text = info.emailTemplate;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final business = context.read<BusinessProvider>();
    final auth = context.read<AuthProvider>();
    final existing = business.businessInfo;

    final info = BusinessInfo(
      id: existing?.id ?? auth.user!.uid,
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      website: _website.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      zip: _zip.text.trim(),
      country: _country.text.trim(),
      logoBase64: existing?.logoBase64,
      currency: _currency.text.trim().isEmpty ? '€' : _currency.text.trim(),
      defaultTaxRate: double.tryParse(_taxRate.text) ?? 21.0,
      invoicePrefix: _invoicePrefix.text.trim().isEmpty ? 'F' : _invoicePrefix.text.trim(),
      defaultNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      nextInvoiceNumber: int.tryParse(_startingNumber.text) ?? 1,
      emailTemplate: _emailTemplate.text.trim().isEmpty
          ? BusinessInfo.kDefaultEmailTemplate
          : _emailTemplate.text.trim(),
    );

    await business.saveBusinessInfo(info);

    if (!mounted) return;
    if (!widget.isFirstTime) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Instellingen opgeslagen'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickLogo() async {
    final business = context.read<BusinessProvider>();
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 600,
      maxHeight: 300,
    );
    if (file == null) return;

    try {
      await business.uploadLogo(file);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo opgeslagen'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fout bij uploaden: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>();
    if (business.businessInfo != null) _prefill(business.businessInfo!);

    final logoBytes = business.logoBytes;

    return Scaffold(
      appBar: widget.isFirstTime
          ? AppBar(
              title: const Text('Bedrijfsinstellingen'),
              automaticallyImplyLeading: false,
            )
          : AppBar(title: const Text('Instellingen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.isFirstTime) ...[
              const Text(
                'Welkom! Stel je bedrijfsprofiel in om te beginnen.',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
            ],

            // Logo
            _SectionHeader(title: 'Bedrijfslogo'),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: business.isSaving ? null : _pickLogo,
                child: Container(
                  width: 140,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border, width: 2),
                  ),
                  child: business.isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : logoBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(logoBytes, fit: BoxFit.contain),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: AppTheme.textSecondary, size: 28),
                                SizedBox(height: 4),
                                Text('Logo toevoegen',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary, fontSize: 11)),
                              ],
                            ),
                ),
              ),
            ),
            if (logoBytes != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: business.removeLogo,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Logo verwijderen'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
              ),
            ],

            const SizedBox(height: 20),
            _SectionHeader(title: 'Bedrijfsgegevens'),
            const SizedBox(height: 12),
            _field(_name, 'Bedrijfsnaam *', required: true),
            _field(_email, 'E-mailadres *',
                keyboardType: TextInputType.emailAddress, required: true),
            _field(_phone, 'Telefoonnummer', keyboardType: TextInputType.phone),
            _field(_website, 'Website', keyboardType: TextInputType.url),

            const SizedBox(height: 20),
            _SectionHeader(title: 'Adres'),
            const SizedBox(height: 12),
            _field(_address, 'Straat en huisnummer'),
            Row(children: [
              Expanded(child: _field(_city, 'Stad')),
              const SizedBox(width: 12),
              Expanded(child: _field(_state, 'Provincie')),
            ]),
            Row(children: [
              Expanded(child: _field(_zip, 'Postcode')),
              const SizedBox(width: 12),
              Expanded(child: _field(_country, 'Land')),
            ]),

            const SizedBox(height: 20),
            _SectionHeader(title: 'Factuurinstellingen'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_currency, 'Valutasymbool', hint: '€')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_taxRate, 'Standaard BTW (%)',
                    keyboardType: TextInputType.number),
              ),
            ]),
            Row(children: [
              Expanded(child: _field(_invoicePrefix, 'Factuurnummer prefix',
                  hint: 'F')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_startingNumber, 'Beginnnummer',
                    keyboardType: TextInputType.number),
              ),
            ]),
            _field(_notes, 'Standaard opmerkingen',
                maxLines: 3,
                hint: 'Standaard tekst op elke factuur'),

            const SizedBox(height: 20),
            _SectionHeader(title: 'E-mail sjabloon'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Text(
                'Beschikbare variabelen:\n'
                '{naam} · {kenteken} · {kmstand} · {factuur_nummer} · {bedrijfsnaam} · {datum} · {totaal}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ),
            const SizedBox(height: 8),
            _field(_emailTemplate, 'Sjabloon', maxLines: 8),

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: business.isSaving ? null : _save,
              child: business.isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text(widget.isFirstTime ? 'Opslaan en verder' : 'Wijzigingen opslaan'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Verplicht veld' : null
              : null,
        ),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
          letterSpacing: 0.5,
        ),
      );
}
