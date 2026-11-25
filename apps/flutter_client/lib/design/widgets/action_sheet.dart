import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'pressable.dart';

/// One row of [showActionSheet].
class SheetAction {
  const SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.danger = false,
    this.keepOpen = false,
  });

  final IconData icon;
  final String label;

  /// Runs after the sheet has closed (unless [keepOpen]).
  final VoidCallback? onTap;

  /// Shown on the right ("Désactivé", "1×").
  final String? value;
  final bool danger;
  final bool keepOpen;
}

/// Phone sheet of the expressive design (2026-11-25): a header (cover,
/// title, subtitle), then groups of rows joined into rounded blocks (big
/// outer corners, small inner ones), each icon on a disc. The groups rise in
/// one after the other.
Future<void> showActionSheet(
  BuildContext context, {
  Widget? header,
  required List<List<SheetAction>> groups,
}) {
  final c = MmColors.of(context);
  final dark = c.brightness == Brightness.dark;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: dark ? c.surface : c.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (context) => ActionSheetBody(header: header, groups: groups),
  );
}

class ActionSheetBody extends StatelessWidget {
  const ActionSheetBody({super.key, this.header, required this.groups});

  final Widget? header;
  final List<List<SheetAction>> groups;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final groups = this.groups.where((g) => g.isNotEmpty).toList();
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          14,
          10,
          14,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.faintIcon,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: header,
              ),
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _Rise(
                index: i,
                child: _Group(actions: groups[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Header of a sheet: cover, title, subtitle.
class SheetHeader extends StatelessWidget {
  const SheetHeader({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Row(
      children: [
        leading,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: MmType.title.copyWith(color: c.fg),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.body.copyWith(fontSize: 15, color: c.muted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.actions});

  final List<SheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final n = actions.length;
    return Column(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(height: 3),
          _Row(
            action: actions[i],
            radius: BorderRadius.vertical(
              top: Radius.circular(i == 0 ? 24 : 6),
              bottom: Radius.circular(i == n - 1 ? 24 : 6),
            ),
          ),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.action, required this.radius});

  final SheetAction action;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final dark = c.brightness == Brightness.dark;
    final row = dark ? c.surface2 : Color.lerp(c.bg, c.fg, 0.055)!;
    final disc = dark ? Color.lerp(c.surface2, c.fg, 0.08)! : c.surface;
    final fg = action.danger ? c.danger : c.fg;
    final onTap = action.onTap;
    return Pressable(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              if (action.keepOpen) {
                onTap();
                return;
              }
              Navigator.of(context).pop();
              onTap();
            },
      semanticLabel: action.value == null
          ? action.label
          : '${action.label}, ${action.value}',
      pressScale: 0.98,
      borderRadius: radius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
        decoration: BoxDecoration(color: row, borderRadius: radius),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: disc, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(action.icon, size: 22, color: fg),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                action.label,
                style: MmType.body.copyWith(
                  fontSize: 16,
                  height: 1.3,
                  color: fg,
                ),
              ),
            ),
            if (action.value != null) ...[
              const SizedBox(width: 12),
              Text(
                action.value!,
                style: MmType.label.copyWith(fontSize: 15, color: c.fgSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Group [index] rises 12 px and fades in, 40 ms after the previous one.
class _Rise extends StatelessWidget {
  const _Rise({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = MmMotion.of(context);
    if (motion.reduced) return child;
    final delay = 0.12 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 40 * index),
      curve: Interval(delay.clamp(0.0, 0.6), 1, curve: MmMotion.standard),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
