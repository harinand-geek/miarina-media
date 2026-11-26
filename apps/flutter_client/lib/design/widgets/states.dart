import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../mm_icons.g.dart';
import '../tokens.dart';
import 'pressable.dart';

/// An action button of the state screens (W-E1, W-E3).
class StateAction {
  const StateAction(this.label, this.onTap, {this.primary = false, this.icon});

  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final IconData? icon;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(this.action, {this.compact = false});

  final StateAction action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final a = action;
    return Pressable(
      onTap: a.onTap,
      semanticLabel: a.label,
      pressScale: 0.97,
      child: Opacity(
        opacity: a.onTap == null ? 0.5 : 1,
        child: Container(
          height: compact ? 34 : 42,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
          decoration: BoxDecoration(
            color: a.primary
                ? (compact ? c.surface2 : c.accent)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: a.primary && !compact
                ? null
                : Border.all(
                    color: compact && !a.primary
                        ? Colors.transparent
                        : c.lineStrong,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (a.icon != null) ...[
                Icon(
                  a.icon,
                  size: 18,
                  color: a.primary && !compact ? const Color(0xFF062320) : c.fg,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  a.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(
                    fontSize: compact ? 13 : 14,
                    color: a.primary && !compact
                        ? const Color(0xFF062320)
                        : compact && !a.primary
                        ? c.fgSoft
                        : c.fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// W-E1: what to do, which formats are read, two actions, and the link
/// with the Get space.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.note,
  });

  final IconData icon;
  final String title;
  final String body;
  final List<StateAction> actions;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: c.coralSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.xxl),
                ),
                child: Icon(icon, size: 40, color: c.coralStrong),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: MmType.display.copyWith(fontSize: 24, color: c.fg),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: MmType.body.copyWith(height: 1.6, color: c.muted),
                ),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [for (final a in actions) _ActionButton(a)],
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 18),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: MmType.caption.copyWith(color: c.faint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// W-E2: skeletons shaped like the content, shown only when loading lasts
/// more than 300 ms (nothing before, to avoid a flash). Reduced motion: no
/// pulse.
class DelayedSkeleton extends StatefulWidget {
  const DelayedSkeleton({super.key, required this.child});

  final Widget child;

  @override
  State<DelayedSkeleton> createState() => _DelayedSkeletonState();
}

class _DelayedSkeletonState extends State<DelayedSkeleton>
    with SingleTickerProviderStateMixin {
  late final Timer _timer;
  bool _shown = false;
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _shown = true);
      if (!MmMotion.of(context).reduced) _pulse.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_shown) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(
          begin: 1.0,
          end: 0.55,
        ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
        child: widget.child,
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = MmRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: MmColors.of(context).surface,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Grid of cards (albums, posters…) while loading.
class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({
    super.key,
    this.aspectRatio = 1,
    this.minTile = 168,
    this.padding = 32,
  });

  final double aspectRatio;
  final double minTile;
  final double padding;

  @override
  Widget build(BuildContext context) => DelayedSkeleton(
    child: LayoutBuilder(
      builder: (context, box) {
        const gap = 18.0;
        final width = box.maxWidth - padding * 2;
        final cols = ((width + gap) / (minTile + gap)).floor().clamp(2, 8);
        final tile = (width - gap * (cols - 1)) / cols;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Wrap(
            spacing: gap,
            runSpacing: 18,
            children: [
              for (var i = 0; i < cols * 2; i++)
                SizedBox(
                  width: tile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(
                        height: tile / aspectRatio,
                        radius: MmRadius.md,
                      ),
                      const SizedBox(height: 10),
                      SkeletonBox(width: tile * 0.75, height: 10),
                      const SizedBox(height: 6),
                      SkeletonBox(width: tile * 0.5, height: 8),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Rows (tracks, history…) while loading.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 8,
    this.rowHeight = 44,
    this.padding = 32,
  });

  final int rows;
  final double rowHeight;
  final double padding;

  @override
  Widget build(BuildContext context) => DelayedSkeleton(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            SizedBox(
              height: rowHeight,
              child: Row(
                children: [
                  SkeletonBox(width: rowHeight - 12, height: rowHeight - 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.5 + (i % 3) * 0.1,
                          child: const SkeletonBox(height: 10),
                        ),
                        const SizedBox(height: 6),
                        const FractionallySizedBox(
                          widthFactor: 0.3,
                          child: SkeletonBox(height: 8),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

enum ErrorTone { danger, warning, info }

/// W-E3: what happened, what is kept, one action; technical details in
/// monospace, copyable for support.
class ErrorCard extends StatelessWidget {
  const ErrorCard({
    super.key,
    required this.title,
    required this.body,
    this.details,
    this.actions = const [],
    this.tone = ErrorTone.danger,
    this.copyLabel,
    this.copiedLabel,
  });

  final String title;
  final String body;
  final String? details;
  final List<StateAction> actions;
  final ErrorTone tone;

  /// "Copier les détails" (shown when [details] is set).
  final String? copyLabel;
  final String? copiedLabel;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final (tint, icon) = switch (tone) {
      ErrorTone.danger => (c.danger, PhosphorRegular.warningCircle),
      ErrorTone.warning => (c.warning, PhosphorRegular.warning),
      ErrorTone.info => (c.muted, PhosphorRegular.info),
    };
    final copy = details != null && copyLabel != null
        ? StateAction(copyLabel!, () {
            Clipboard.setData(ClipboardData(text: details!));
            if (copiedLabel != null) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                SnackBar(
                  content: Text(copiedLabel!),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          })
        : null;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.xl),
        border: Border.all(color: c.surface2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(MmRadius.md),
            ),
            child: Icon(icon, size: 22, color: tint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MmType.title.copyWith(fontSize: 16, color: c.fg),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: MmType.bodySm.copyWith(height: 1.5, color: c.fgSoft),
                ),
                if (details != null) ...[
                  const SizedBox(height: 4),
                  SelectableText(
                    details!,
                    maxLines: 3,
                    style: MmType.monoStyle(size: 11, color: c.muted),
                  ),
                ],
                if (actions.isNotEmpty || copy != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final a in actions) _ActionButton(a, compact: true),
                      if (copy != null) _ActionButton(copy, compact: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
