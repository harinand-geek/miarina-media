import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';

/// The one interactive surface of the app: hover tint (80 ms), a slight press
/// scale, a 2 px teal focus ring offset by 2 px, Enter/Space activation and
/// a semantic label. Everything clickable that is not a text field uses it.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTap,
    this.semanticLabel,
    this.tooltip,
    this.borderRadius = const BorderRadius.all(Radius.circular(MmRadius.pill)),
    this.hoverColor,
    this.pressScale = 0.97,
    this.focusNode,
    this.autofocus = false,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onSecondaryTap;
  final String? semanticLabel;
  final String? tooltip;
  final BorderRadius borderRadius;

  /// Background while hovered; null keeps the child's own background.
  final Color? hoverColor;
  final double pressScale;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool selected;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hover = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null || widget.onDoubleTap != null;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final motion = MmMotion.of(context);
    final scale = _pressed && !motion.reduced ? widget.pressScale : 1.0;

    Widget body = AnimatedContainer(
      duration: motion.hover,
      curve: MmMotion.standard,
      decoration: BoxDecoration(
        color: _hover && _enabled ? widget.hoverColor : null,
        borderRadius: widget.borderRadius,
      ),
      foregroundDecoration: _focused
          ? BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: c.accent,
                width: 2,
                strokeAlign: BorderSide.strokeAlignOutside + 1,
              ),
            )
          : null,
      child: widget.child,
    );

    body = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 90),
      curve: MmMotion.standard,
      child: body,
    );

    body = FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      enabled: _enabled,
      mouseCursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: widget.onSecondaryTap,
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        child: body,
      ),
    );

    // Its own node: screen readers focus exactly this control, not the row
    // or list item around it.
    body = Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: body,
    );

    final tip = widget.tooltip;
    return tip == null ? body : Tooltip(message: tip, child: body);
  }
}
