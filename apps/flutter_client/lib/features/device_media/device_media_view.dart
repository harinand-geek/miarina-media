import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/logo.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../library/library_data.dart';
import '../playback/settings_store.dart';
import 'device_media.dart';

/// Android Musique tab without the phone's media: the explanation before the
/// system dialog (A-06), or the refusal (A-07) once it was asked. Shown only
/// while the library is empty; otherwise the tab shows what it has. Back
/// from the system settings, the access is read again.
class DeviceMediaGate extends ConsumerStatefulWidget {
  const DeviceMediaGate({super.key, required this.active, required this.child});

  /// Whether the current screen belongs to the Musique tab.
  final bool active;
  final Widget child;

  @override
  ConsumerState<DeviceMediaGate> createState() => _DeviceMediaGateState();
}

class _DeviceMediaGateState extends ConsumerState<DeviceMediaGate> {
  static const bannerHiddenKey = 'deviceMediaBannerHidden';

  late final AppLifecycleListener _lifecycle;

  /// The banner was closed with its ✕ (null until read).
  bool? _bannerHidden;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(deviceMediaProvider.notifier).recheck(),
    );
    ref.read(settingsStoreProvider).read(bannerHiddenKey).then((v) {
      if (mounted) setState(() => _bannerHidden = v == true);
    });
  }

  void _hideBanner() {
    setState(() => _bannerHidden = true);
    ref.read(settingsStoreProvider).write(bannerHiddenKey, true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || !ref.watch(deviceMediaSupportedProvider)) {
      return widget.child;
    }
    final device = ref.watch(deviceMediaProvider).value;
    final stats = ref.watch(libraryStatsProvider).value;
    if (device == null || stats == null) return widget.child;
    if (!device.access.any && stats.total == BigInt.zero) {
      return device.asked ? const AccessDeniedView() : const AskAccessView();
    }
    // Something downloaded before the phone's music was allowed: the
    // library is not empty, so the explanation above never shows; this
    // banner still offers the access (0.2.7).
    final banner = !device.access.audio && _bannerHidden == false;
    return Column(
      children: [
        Expanded(child: widget.child),
        if (banner)
          DeviceAccessBanner(asked: device.asked, onClose: _hideBanner),
      ],
    );
  }
}

/// Musique with downloads but without the phone's music: a card above the
/// tab bar to allow it (or to open the Android settings after a refusal).
class DeviceAccessBanner extends ConsumerWidget {
  const DeviceAccessBanner({
    super.key,
    required this.asked,
    required this.onClose,
  });

  final bool asked;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final device = ref.read(deviceMediaProvider.notifier);
    final action = asked ? t.deviceDeniedSettings : t.deviceBannerAllow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MmRadius.card),
          border: Border.all(color: c.cardHover),
        ),
        child: Row(
          children: [
            Icon(PhosphorRegular.musicNotes, size: 24, color: c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.deviceBannerTitle,
                    style: MmType.heading.copyWith(color: c.fg),
                  ),
                  const SizedBox(height: 6),
                  Pressable(
                    onTap: asked ? device.openSettings : device.request,
                    semanticLabel: action,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(MmRadius.pill),
                      ),
                      child: Text(
                        action,
                        style: MmType.labelStrong.copyWith(
                          color: const Color(0xFF062320),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: t.close,
              onPressed: onClose,
              icon: Icon(PhosphorRegular.x, size: 18, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A-06: why the access is asked, then the system dialog.
class AskAccessView extends ConsumerWidget {
  const AskAccessView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final reasons = [
      (
        PhosphorRegular.musicNote,
        c.coralStrong,
        t.deviceAccessMusic,
        t.deviceAccessMusicBody,
      ),
      (
        PhosphorRegular.filmSlate,
        c.coralStrong,
        t.deviceAccessVideo,
        t.deviceAccessVideoBody,
      ),
      (
        PhosphorRegular.bell,
        c.accent,
        t.deviceAccessNotif,
        t.deviceAccessNotifBody,
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight - 72),
          child: IntrinsicHeight(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: MiarinaLogo(size: 56),
                ),
                const SizedBox(height: 18),
                Semantics(
                  header: true,
                  child: Text(
                    t.deviceAccessTitle,
                    style: MmType.display.copyWith(
                      fontSize: 26,
                      height: 32 / 26,
                      color: c.fg,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  t.deviceAccessBody,
                  style: MmType.body.copyWith(
                    fontSize: 14.5,
                    height: 22 / 14.5,
                    color: c.muted,
                  ),
                ),
                const SizedBox(height: 18),
                for (final (icon, tint, title, body) in reasons) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(MmRadius.card),
                      border: Border.all(color: c.cardHover),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, size: 24, color: tint),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: MmType.heading.copyWith(
                                  fontSize: 14.5,
                                  color: c.fg,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                body,
                                style: MmType.caption.copyWith(
                                  fontSize: 12.5,
                                  height: 18 / 12.5,
                                  color: c.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const Spacer(),
                const SizedBox(height: 18),
                Pressable(
                  onTap: () => ref.read(deviceMediaProvider.notifier).request(),
                  semanticLabel: t.deviceAccessAllow,
                  borderRadius: BorderRadius.circular(MmRadius.card),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(MmRadius.card),
                    ),
                    child: Text(
                      t.deviceAccessAllow,
                      style: MmType.labelStrong.copyWith(
                        fontSize: 15,
                        color: const Color(0xFF062320),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A-07: the access was refused; the system settings can grant it.
class AccessDeniedView extends ConsumerWidget {
  const AccessDeniedView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 8, 10),
          child: Text(
            t.tabMusic,
            style: MmType.display.copyWith(fontSize: 26, color: c.fg),
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        c.danger.withValues(alpha: 0.16),
                        c.bg,
                      ),
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Icon(
                      PhosphorRegular.lockSimple,
                      size: 40,
                      color: c.danger,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.deviceDeniedTitle,
                    textAlign: TextAlign.center,
                    style: MmType.title.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: c.fg,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.deviceDeniedBody,
                    textAlign: TextAlign.center,
                    style: MmType.body.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 20),
                  Pressable(
                    onTap: () =>
                        ref.read(deviceMediaProvider.notifier).openSettings(),
                    semanticLabel: t.deviceDeniedSettings,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    // Wraps on narrow phones or large text instead of
                    // overflowing.
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(MmRadius.pill),
                      ),
                      child: Text(
                        t.deviceDeniedSettings,
                        textAlign: TextAlign.center,
                        style: MmType.labelStrong.copyWith(
                          fontSize: 14.5,
                          color: const Color(0xFF062320),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
