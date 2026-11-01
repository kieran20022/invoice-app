import 'dart:async';
import 'package:flutter/material.dart';

/// Adds up what several deleted invoices put back, per product.
Map<String, double> mergeRestocked(Iterable<Map<String, double>> restocks) {
  final total = <String, double>{};
  for (final r in restocks) {
    r.forEach((id, qty) => total[id] = (total[id] ?? 0) + qty);
  }
  return total;
}

/// "4 producten terug in voorraad". Counts pieces when every quantity is
/// whole (4 bougies are 4 producten); with a fraction among them (1,5 liter
/// olie) it counts the products instead, since "5,5 producten" reads oddly.
String restockLabel(Map<String, double> restocked) {
  final whole = restocked.values.every((q) => q == q.roundToDouble());
  final count = whole
      ? restocked.values.fold<double>(0, (a, b) => a + b).round()
      : restocked.length;
  return count == 1
      ? '1 product terug in voorraad'
      : '$count producten terug in voorraad';
}

/// The toast currently on screen, so a new one replaces it instead of
/// stacking on top.
OverlayEntry? _current;

/// Tells the user a deleted invoice's parts went back on the shelf, with a
/// "Producten Verwijderen" that takes them off again — for parts that were
/// used after all. Once the toast is gone the stock stays as it is;
/// correcting it then is done by hand in Voorraad.
///
/// It is a toast at the top of the screen rather than a snackbar, so it does
/// not cover the bottom navigation or the buttons the user reaches for next.
/// It goes by itself after a few seconds and can be swiped away (up or
/// sideways).
///
/// [overlay] and [messenger] are captured by the caller before
/// its await, so this still works after the calling screen has been popped.
/// [prefix] leads the message ("1 document verwijderd"); with nothing
/// restocked only it is shown, as a plain snackbar.
void showRestockSnack(
  OverlayState overlay,
  ScaffoldMessengerState messenger,
  Map<String, double> restocked, {
  required Future<void> Function() onUndo,
  String? prefix,
}) {
  if (restocked.isEmpty) {
    if (prefix != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(prefix), behavior: SnackBarBehavior.floating),
      );
    }
    return;
  }
  final label = restockLabel(restocked);

  _current?.remove();
  late final OverlayEntry entry;
  void close() {
    if (_current == entry) _current = null;
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _RestockToast(
      message: prefix == null ? label : '$prefix · $label',
      actionLabel: 'Producten Verwijderen',
      onClosed: close,
      onAction: () async {
        try {
          await onUndo();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Uit voorraad halen mislukt: $e'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _RestockToast extends StatefulWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback onClosed;

  const _RestockToast({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onClosed,
  });

  @override
  State<_RestockToast> createState() => _RestockToastState();
}

class _RestockToastState extends State<_RestockToast>
    with SingleTickerProviderStateMixin {
  static const _visibleFor = Duration(seconds: 6);

  late final AnimationController _slide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_visibleFor, _hide);
  }

  /// Slides out, then takes the entry off the overlay.
  Future<void> _hide() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _slide.reverse();
    widget.onClosed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, -1.5), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: _slide, curve: Curves.easeOutCubic),
                ),
            child: Dismissible(
              key: const ValueKey('restock-toast'),
              direction: DismissDirection.up,
              onDismissed: (_) {
                _closing = true;
                _timer?.cancel();
                widget.onClosed();
              },
              child: Dismissible(
                key: const ValueKey('restock-toast-side'),
                direction: DismissDirection.horizontal,
                onDismissed: (_) {
                  _closing = true;
                  _timer?.cancel();
                  widget.onClosed();
                },
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.inverseSurface,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 20,
                          color: scheme.onInverseSurface,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onInverseSurface,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            widget.onAction();
                            _hide();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.inversePrimary,
                          ),
                          child: Text(widget.actionLabel),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
