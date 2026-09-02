import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/invoice.dart';
import '../../models/vehicle.dart';
import '../../providers/business_provider.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/email_service.dart';
import '../../services/pdf_service.dart';
import '../../services/whatsapp_service.dart';
import '../../utils/phone_format.dart';
import '../invoices/create_invoice_screen.dart';

/// Vehicles currently in the shop. Each one carries the invoice its work is
/// billed on; tapping it opens that invoice straight at the Producten step.
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>();
    final invoices = context.watch<InvoiceProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: !vehicles.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : vehicles.vehicles.isEmpty
              ? const _EmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: vehicles.vehicles.length,
                  itemBuilder: (_, i) {
                    final vehicle = vehicles.vehicles[i];
                    return _VehicleCard(
                      vehicle: vehicle,
                      invoice: _invoiceFor(invoices.allInvoices, vehicle),
                      onTap: () => _openInvoice(vehicle),
                      onShare: () => _shareInvoice(vehicle),
                      onFinish: () => _confirmFinish(vehicle),
                      onFinishAndShare: () => _finishAndShare(vehicle),
                      onDelete: () => _confirmDelete(vehicle),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vehicles_add',
        onPressed: _busy ? null : () => _showVehicleForm(),
        backgroundColor: AppTheme.primary,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Voertuig toevoegen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Invoice? _invoiceFor(List<Invoice> invoices, Vehicle vehicle) {
    for (final inv in invoices) {
      if (inv.id == vehicle.invoiceId) return inv;
    }
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Opens the vehicle's invoice at the Producten step. If the invoice is gone
  /// (deleted from the Facturen tab), a fresh one is started for the vehicle.
  Future<void> _openInvoice(Vehicle vehicle) async {
    final vehicleProvider = context.read<VehicleProvider>();
    var invoice =
        _invoiceFor(context.read<InvoiceProvider>().allInvoices, vehicle);

    if (invoice == null) {
      final created = await _createInvoiceFor(
        vehicle.phone,
        vehicle.name,
        vehicle.plate,
        vehicle.kmstand,
      );
      if (created == null || !mounted) return;
      await vehicleProvider.saveVehicle(vehicle.copyWith(invoiceId: created.id));
      invoice = created;
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateInvoiceScreen(
          editInvoice: invoice,
          initialStep: 1,
          saveOnClose: true,
        ),
      ),
    );
  }

  /// Creates and saves an empty invoice carrying the vehicle's phone number,
  /// name, plate and km stand. It is saved into the workshop buffer, so it
  /// stays out of the Facturen tab until the vehicle is taken out of the shop.
  Future<Invoice?> _createInvoiceFor(
    String phone,
    String name,
    String plate,
    String kmstand,
  ) async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final business = context.read<BusinessProvider>().businessInfo;
    if (business == null) {
      _snack('Vul eerst je bedrijfsgegevens in');
      return null;
    }

    setState(() => _busy = true);
    try {
      invoiceProvider.startNewDraft(business);
      invoiceProvider.updateDraftClient(
        telefoonnummer: phone,
        naam: name,
        kenteken: plate,
        kmstand: kmstand,
        datum: DateFormat('dd-MM-yyyy').format(DateTime.now()),
      );
      return await invoiceProvider.saveDraft(
        status: InvoiceProvider.workshopStatus,
      );
    } catch (e) {
      invoiceProvider.clearDraft();
      _snack('Fout bij aanmaken factuur: $e');
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showVehicleForm({Vehicle? vehicle}) async {
    final result = await showModalBottomSheet<_VehicleFormResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VehicleFormSheet(vehicle: vehicle),
    );
    if (result == null || !mounted) return;

    final vehicleProvider = context.read<VehicleProvider>();

    if (vehicle != null) {
      await vehicleProvider.saveVehicle(
        vehicle.copyWith(
          phone: result.phone,
          name: result.name,
          plate: result.plate,
          kmstand: result.kmstand,
        ),
      );
      return;
    }

    final invoice = await _createInvoiceFor(
      result.phone,
      result.name,
      result.plate,
      result.kmstand,
    );
    if (invoice == null) return;
    await vehicleProvider.saveVehicle(
      Vehicle(
        id: '',
        phone: result.phone,
        name: result.name,
        plate: result.plate,
        kmstand: result.kmstand,
        invoiceId: invoice.id,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Shares the vehicle's invoice PDF through the native share sheet.
  Future<void> _shareInvoice(Vehicle vehicle) async {
    final invoice =
        _invoiceFor(context.read<InvoiceProvider>().allInvoices, vehicle);
    if (invoice == null) {
      _snack('Deze factuur bestaat niet meer');
      return;
    }

    setState(() => _busy = true);
    try {
      await _openShareSheet(invoice);
    } catch (e) {
      _snack('Delen mislukt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Renders [invoice] and hands it to the native share sheet.
  Future<void> _openShareSheet(Invoice invoice) async {
    final businessProvider = context.read<BusinessProvider>();
    final template = businessProvider.businessInfo?.emailTemplate ?? '';
    final subject = EmailService.buildDefaultSubject(invoice);
    final body = EmailService.renderTemplate(template, invoice);
    final pdfBytes = await PdfService.generatePdf(
      invoice,
      logoBytes: businessProvider.logoBytes,
    );

    // WhatsApp drops the text when a document is attached, so the message
    // goes to the clipboard for the user to paste — same as the send flows.
    await Clipboard.setData(ClipboardData(text: '$subject\n\n$body'));

    await EmailService.shareInvoice(
      invoice: invoice,
      pdfBytes: pdfBytes,
      subject: subject,
      message: body,
    );
    _snack('Bericht gekopieerd — plak het in WhatsApp');
  }

  /// Finishes the job and opens the share sheet straight away: the invoice
  /// gets its number here, so what is shared is the real invoice rather than
  /// the unnumbered concept.
  Future<void> _finishAndShare(Vehicle vehicle) async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final vehicleProvider = context.read<VehicleProvider>();

    final invoice = _invoiceFor(invoiceProvider.allInvoices, vehicle);
    if (invoice == null) {
      _snack('Deze factuur bestaat niet meer');
      return;
    }

    setState(() => _busy = true);
    try {
      // Number and release first: a vehicle deleted while its invoice is still
      // buffered would leave that invoice unreachable from either tab.
      final released = await invoiceProvider.releaseFromWorkshop(invoice);
      await vehicleProvider.deleteVehicle(vehicle.id);
      if (!mounted) return;
      await _openShareSheet(released);
    } catch (e) {
      _snack('Afronden en delen mislukt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Finishes the job: the invoice leaves the workshop buffer — getting its
  /// number — and moves to the Facturen tab, and the vehicle leaves the shop.
  Future<void> _confirmFinish(Vehicle vehicle) async {
    final confirmed = await _confirm(
      title: 'Voertuig afronden',
      message:
          '${vehicle.plate} afronden? De factuur krijgt een nummer en '
          'verschijnt in het Facturen tabblad.',
      action: 'Afronden',
    );
    if (confirmed != true || !mounted) return;

    final invoiceProvider = context.read<InvoiceProvider>();
    final vehicleProvider = context.read<VehicleProvider>();

    // Leaving the workshop is what releases the invoice from the buffer into
    // the Facturen tab. Do that first: a vehicle deleted while its invoice is
    // still buffered would leave the invoice unreachable from either tab.
    final invoice = _invoiceFor(invoiceProvider.allInvoices, vehicle);
    if (invoice != null) {
      await invoiceProvider.releaseFromWorkshop(invoice);
    }
    await vehicleProvider.deleteVehicle(vehicle.id);
    _snack('${vehicle.plate} staat nu in het Facturen tabblad');
  }

  /// Throws the whole record away — the vehicle *and* its invoice. Nothing
  /// reaches the Facturen tab, and no invoice number is used.
  Future<void> _confirmDelete(Vehicle vehicle) async {
    final confirmed = await _confirm(
      title: 'Voertuig verwijderen',
      message:
          '${vehicle.plate} en de bijbehorende factuur definitief '
          'verwijderen? Dit kan niet ongedaan worden gemaakt.',
      action: 'Verwijderen',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;

    final invoiceProvider = context.read<InvoiceProvider>();
    final vehicleProvider = context.read<VehicleProvider>();

    // Delete the vehicle last: if the invoice delete fails, the vehicle is
    // still there to reach it by.
    final invoice = _invoiceFor(invoiceProvider.allInvoices, vehicle);
    if (invoice != null) {
      await invoiceProvider.deleteInvoice(invoice.id);
    }
    await vehicleProvider.deleteVehicle(vehicle.id);
    _snack('${vehicle.plate} is verwijderd');
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuleren'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: AppTheme.error)
                : null,
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;

  /// The vehicle's invoice, or null when it no longer exists.
  final Invoice? invoice;
  final VoidCallback onTap;
  final VoidCallback onShare;
  final VoidCallback onFinish;
  final VoidCallback onFinishAndShare;
  final VoidCallback onDelete;

  const _VehicleCard({
    required this.vehicle,
    required this.invoice,
    required this.onTap,
    required this.onShare,
    required this.onFinish,
    required this.onFinishAndShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final inv = invoice;
    final itemCount = inv?.items.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.moped,
                  color: AppTheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            // The name is optional; without one the number is
                            // all we have to identify the owner by.
                            vehicle.name.isNotEmpty
                                ? vehicle.name
                                : PhonePairFormatter.format(vehicle.phone),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PlateBadge(plate: vehicle.plate),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      inv == null
                          ? 'Factuur verwijderd — tik om opnieuw te beginnen'
                          : '${inv.numberLabel} · $itemCount '
                              '${itemCount == 1 ? 'product' : 'producten'} · '
                              '${inv.currency}${inv.totaalInclBtw.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppTheme.textSecondary,
                ),
                onSelected: (value) {
                  if (value == 'share') onShare();
                  if (value == 'finish') onFinish();
                  if (value == 'finish_share') onFinishAndShare();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'share', child: Text('Concept delen')),
                  PopupMenuItem(value: 'finish', child: Text('Afronden')),
                  PopupMenuItem(
                    value: 'finish_share',
                    child: Text('Afronden en delen'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Verwijderen',
                      style: TextStyle(color: AppTheme.error),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Licence plate, styled after a Dutch number plate.
class _PlateBadge extends StatelessWidget {
  final String plate;
  const _PlateBadge({required this.plate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Text(
        plate,
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

// ── Form ─────────────────────────────────────────────────────────────────────

class _VehicleFormResult {
  final String phone;
  final String name;
  final String plate;
  final String kmstand;
  const _VehicleFormResult(this.phone, this.name, this.plate, this.kmstand);
}

class _VehicleFormSheet extends StatefulWidget {
  final Vehicle? vehicle;
  const _VehicleFormSheet({this.vehicle});

  @override
  State<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends State<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _plate = TextEditingController();
  final _kmstand = TextEditingController();
  final _name = TextEditingController();

  // Enter walks the fields in order and submits from the last one.
  final _plateFocus = FocusNode();
  final _kmstandFocus = FocusNode();
  final _nameFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    if (v != null) {
      _phone.text = PhonePairFormatter.format(v.phone);
      _plate.text = v.plate;
      _kmstand.text = v.kmstand;
      _name.text = v.name;
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _plate.dispose();
    _kmstand.dispose();
    _name.dispose();
    _plateFocus.dispose();
    _kmstandFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _VehicleFormResult(
        // The grouping spaces are for reading only — strip them before saving.
        _phone.text.replaceAll(' ', '').trim(),
        _name.text.trim(),
        _plate.text.trim().toUpperCase(),
        _kmstand.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Voertuig bewerken' : 'Voertuig toevoegen',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (!isEdit) ...[
              const SizedBox(height: 4),
              const Text(
                'Er wordt meteen een factuur voor dit voertuig aangemaakt.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              autofocus: !isEdit,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: const [PhonePairFormatter()],
              decoration: const InputDecoration(
                labelText: 'Telefoonnummer',
                hintText: '06 12 34 56 78',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Vul een telefoonnummer in';
                }
                // Same check the WhatsApp send does, so a number that would
                // fail there is rejected while it can still be corrected.
                return WhatsappService.normalizePhone(v) == null
                    ? 'Geen geldig telefoonnummer'
                    : null;
              },
              onFieldSubmitted: (_) => _plateFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              focusNode: _plateFocus,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Kenteken',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Vul een kenteken in' : null,
              onFieldSubmitted: (_) => _kmstandFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kmstand,
              focusNode: _kmstandFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'KM stand (optioneel)',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              onFieldSubmitted: (_) => _nameFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Naam eigenaar (optioneel)',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(isEdit ? 'Opslaan' : 'Toevoegen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.moped_outlined,
              size: 64,
              color: AppTheme.borderOf(context),
            ),
            const SizedBox(height: 16),
            const Text(
              'Geen voertuigen in de werkplaats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tik op "Voertuig toevoegen" om een voertuig '
              'met een lopende factuur bij te houden',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
