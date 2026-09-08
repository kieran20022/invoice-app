import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// One of the things a [MovableInvoiceCard] can be swiped into.
class MovableCardAction {
  final String label;
  final IconData icon;
  final Color color;

  /// The state the card's subject is already in — its half of the panel is
  /// drawn filled, so it is clear which way an invoice was paid.
  final bool selected;
  final VoidCallback onPressed;

  const MovableCardAction({
    required this.label,
    required this.icon,
    required this.color,
    this.selected = false,
    required this.onPressed,
  });
}

/// A card that acts on the swipe itself — there is nothing to tap afterwards.
///
/// The direction decides what happens, and the panel uncovered underneath
/// shows which way the swipe is currently reading:
///
/// - **Right and up** runs [swipeUp] (Contant Betaald).
/// - **Right and down** runs [swipeDown] (Pin Betaald).
/// - **Left** runs [onDelete], which asks for confirmation.
///
/// A swipe that is too short, or one to the right with no vertical direction
/// to it, springs back and does nothing.
class MovableInvoiceCard extends StatefulWidget {
  /// The card itself. Its own taps work as usual — the swipe never gets in
  /// the way of opening the invoice.
  final Widget child;

  /// Swiping right and up / right and down. Both null leaves that side inert:
  /// a quote carries no payment state, so it can only be deleted.
  final MovableCardAction? swipeUp;
  final MovableCardAction? swipeDown;

  final VoidCallback onDelete;

  const MovableInvoiceCard({
    super.key,
    required this.child,
    this.swipeUp,
    this.swipeDown,
    required this.onDelete,
  });

  @override
  State<MovableInvoiceCard> createState() => _MovableInvoiceCardState();
}

class _MovableInvoiceCardState extends State<MovableInvoiceCard>
    with SingleTickerProviderStateMixin {
  /// How far right the card travels, and how far it has to go before letting
  /// go acts on it.
  static const double swipeWidth = 132;
  static const double swipeThreshold = 72;

  /// How far left it travels, and the distance that asks to delete.
  static const double deleteWidth = 120;
  static const double deleteThreshold = 72;

  /// The vertical movement that makes a right swipe read as up or down.
  /// Small, so that the diagonal barely has to be aimed — but not zero, or a
  /// dead-straight swipe would pick a payment method by rounding noise.
  static const double verticalThreshold = 8;

  /// Speed past which a flick acts without needing the full distance.
  static const double flickVelocity = 320;

  // Built in initState rather than lazily: a card that is never swiped would
  // otherwise have its controller created by its own dispose().
  late final AnimationController _controller;

  /// How far the card is pushed sideways, in pixels: positive towards the
  /// payment actions, negative over the delete panel.
  double _offset = 0;

  /// How far the finger has travelled vertically since the swipe began. The
  /// card does not move with it — the panel highlights instead — but it is
  /// what decides between the two payment actions.
  double _dy = 0;
  double _startY = 0;

  Animation<double>? _settle;

  bool get _hasPayments => widget.swipeUp != null || widget.swipeDown != null;

  double get _maxRight => _hasPayments ? swipeWidth : 0;

  /// Which payment action the swipe currently reads as, or null while it is
  /// still level (or heading the wrong way).
  MovableCardAction? get _aimed {
    if (_offset <= 0) return null;
    if (_dy <= -verticalThreshold) return widget.swipeUp;
    if (_dy >= verticalThreshold) return widget.swipeDown;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _controller.stop();
    if (_offset == target) return;
    _settle =
        Tween<double>(begin: _offset, end: target).animate(
          CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
        )..addListener(() {
          if (mounted) setState(() => _offset = _settle!.value);
        });
    _controller
      ..reset()
      ..forward();
  }

  void _onDragStart(DragStartDetails d) {
    _controller.stop();
    _startY = d.globalPosition.dy;
    setState(() => _dy = 0);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    setState(() {
      // A horizontal drag reports no vertical delta of its own — which is
      // what keeps the list scrolling normally — so the up/down half of the
      // gesture is read off the finger's position instead.
      _dy = d.globalPosition.dy - _startY;
      _offset = (_offset + d.delta.dx).clamp(-deleteWidth, _maxRight);
    });
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    final aimed = _aimed;

    // Left: a flick or a long enough pull asks to delete. The card springs
    // back either way — the list drops it if the deletion is confirmed.
    final deleting =
        _offset < 0 &&
        (velocity < -flickVelocity ||
            (velocity <= 0 && _offset <= -deleteThreshold));

    // Right: the same, but it also has to say which way it is going.
    final paying =
        aimed != null &&
        (velocity > flickVelocity || _offset >= swipeThreshold);

    _animateTo(0);
    if (deleting) {
      widget.onDelete();
    } else if (paying) {
      aimed.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final aimed = _aimed;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        color: Theme.of(context).cardColor,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              // What the card uncovers as it moves. Only the side being
              // pulled from is built.
              if (_offset > 0)
                Positioned.fill(
                  child: SizedBox(
                    width: swipeWidth,
                    child: Column(
                      children: [
                        Expanded(
                          child: _SwipeHalf(
                            action: widget.swipeUp,
                            active: aimed == widget.swipeUp && aimed != null,
                            alignment: Alignment.bottomLeft,
                          ),
                        ),
                        Expanded(
                          child: _SwipeHalf(
                            action: widget.swipeDown,
                            active: aimed == widget.swipeDown && aimed != null,
                            alignment: Alignment.topLeft,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_offset < 0)
                Positioned.fill(
                  child: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    color: AppTheme.error,
                    child: const Icon(
                      Icons.delete_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              Transform.translate(
                offset: Offset(_offset, 0),
                child: Material(
                  color: Theme.of(context).cardColor,
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One half of the panel uncovered by a right swipe. It fills in once the
/// swipe is aimed at it, so the card says what letting go will do.
class _SwipeHalf extends StatelessWidget {
  final MovableCardAction? action;
  final bool active;

  /// Pulls the two labels towards the middle, where the swipe splits.
  final Alignment alignment;

  const _SwipeHalf({
    required this.action,
    required this.active,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    if (action == null) return const SizedBox.shrink();
    final filled = active || action.selected;
    return Container(
      color: filled ? action.color : action.color.withAlpha(38),
      alignment: alignment,
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            action.icon,
            size: 18,
            color: filled ? Colors.white : action.color,
          ),
          const SizedBox(width: 6),
          Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : action.color,
            ),
          ),
        ],
      ),
    );
  }
}
