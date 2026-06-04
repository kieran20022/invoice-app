import 'dart:io';
import 'package:flutter/foundation.dart';
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
  late final TextEditingController _paymentTerms;
  late final TextEditingController _notes;
  late final TextEditingController _startingNumber;

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
    _currency = TextEditingController(text: '\$');
    _taxRate = TextEditingController(text: '0');
    _invoicePrefix = TextEditingController(text: 'INV');
    _paymentTerms = TextEditingController(text: 'Net 30');
    _notes = TextEditingController();
    _startingNumber = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _website, _address, _city, _state,
      _zip, _country, _currency, _taxRate, _invoicePrefix,
      _paymentTerms, _notes, _startingNumber,
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
    _paymentTerms.text = info.defaultPaymentTerms;
    _notes.text = info.defaultNotes ?? '';
    _startingNumber.text = info.nextInvoiceNumber.toString();
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
      logoUrl: existing?.logoUrl,
      currency: _currency.text.trim().isEmpty ? '\$' : _currency.text.trim(),
      defaultTaxRate: double.tryParse(_taxRate.text) ?? 0.0,
      invoicePrefix: _invoicePrefix.text.trim().isEmpty ? 'INV' : _invoicePrefix.text.trim(),
      defaultPaymentTerms: _paymentTerms.text.trim(),
      defaultNotes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      nextInvoiceNumber: int.tryParse(_startingNumber.text) ?? 1,
    );

    await business.saveBusinessInfo(info);

    if (mounted) {
      if (widget.isFirstTime) {
        // Navigate to home — the AuthWrapper will rebuild
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business info saved'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickLogo() async {
    final business = context.read<BusinessProvider>();
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    try {
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        await business.uploadLogo(bytes);
      } else {
        await business.uploadLogo(File(file.path));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo uploaded'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
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

    return Scaffold(
      appBar: widget.isFirstTime
          ? AppBar(
              title: const Text('Set Up Your Business'),
              automaticallyImplyLeading: false,
            )
          : AppBar(title: const Text('Business Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.isFirstTime) ...[
              const Text(
                'Welcome! Let\'s set up your business profile.',
                style: TextStyle(
                    fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
            ],

            // Logo section
            _SectionHeader(title: 'Business Logo'),
            const SizedBox(height: 12),
            Center(
              child: GestureDetector(
                onTap: business.isSaving ? null : _pickLogo,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border, width: 2),
                  ),
                  child: business.isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : business.businessInfo?.logoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(
                                business.businessInfo!.logoUrl!,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) => progress == null
                                    ? child
                                    : const Center(child: CircularProgressIndicator()),
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    color: AppTheme.textSecondary, size: 32),
                                SizedBox(height: 4),
                                Text('Add Logo',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary, fontSize: 12)),
                              ],
                            ),
                ),
              ),
            ),
            if (business.businessInfo?.logoUrl != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: business.removeLogo,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Remove Logo'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                ),
              ),
            ],

            const SizedBox(height: 20),

            _SectionHeader(title: 'Business Details'),
            const SizedBox(height: 12),
            _field(_name, 'Business Name *', required: true),
            _field(_email, 'Business Email *',
                keyboardType: TextInputType.emailAddress, required: true),
            _field(_phone, 'Phone Number',
                keyboardType: TextInputType.phone),
            _field(_website, 'Website', keyboardType: TextInputType.url),

            const SizedBox(height: 20),
            _SectionHeader(title: 'Address'),
            const SizedBox(height: 12),
            _field(_address, 'Street Address'),
            Row(children: [
              Expanded(child: _field(_city, 'City')),
              const SizedBox(width: 12),
              Expanded(child: _field(_state, 'State / Province')),
            ]),
            Row(children: [
              Expanded(child: _field(_zip, 'Postal Code')),
              const SizedBox(width: 12),
              Expanded(child: _field(_country, 'Country')),
            ]),

            const SizedBox(height: 20),
            _SectionHeader(title: 'Invoice Settings'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(_currency, 'Currency Symbol',
                  hint: 'e.g. \$, €, £')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_taxRate, 'Default Tax Rate (%)',
                    keyboardType: TextInputType.number),
              ),
            ]),
            Row(children: [
              Expanded(child: _field(_invoicePrefix, 'Invoice Prefix',
                  hint: 'e.g. INV, #')),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_startingNumber, 'Starting Invoice #',
                    keyboardType: TextInputType.number),
              ),
            ]),
            _field(_paymentTerms, 'Default Payment Terms',
                hint: 'e.g. Net 30'),
            _field(_notes, 'Default Invoice Notes',
                maxLines: 3,
                hint: 'e.g. Thank you for your business!'),

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
                  : Text(widget.isFirstTime ? 'Save & Continue' : 'Save Changes'),
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
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
          ),
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? 'Required' : null
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
