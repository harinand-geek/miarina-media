import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/licenses.dart';
import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/logo.dart';
import '../../design/widgets/pressable.dart';
import '../../engine/media_engine.dart';
import '../../l10n/app_localizations.dart';
import '../capture/capture_settings.dart';
import '../cinema/cinema_widgets.dart';
import '../now_playing/sound_view.dart' show MmSwitch;
import '../health/health_data.dart';
import '../get/download_settings.dart';
import '../updates/updates_view.dart' show UpdatesSettings;
import '../history/history_data.dart';
import '../import/import_data.dart';
import '../import/welcome_screen.dart';
import '../history/history_screen.dart' show confirmClearHistory;
import '../library/library_data.dart';
import '../online/online_obtain.dart' show OnlineSettingsGroup;
import '../playback/playback.dart';
import '../shortcuts/shortcuts_view.dart';
import '../now_playing/now_playing_screen.dart' show lastLocationProvider;
import 'extension_settings.dart';
import '../tour/tour.dart';
import 'settings_data.dart';

enum SettingsSection {
  general,
  appearance,
  playback,
  capture,
  library,
  downloads,
  extension,
  shortcuts,
  data,
  updates,
  about,
}

String sectionPath(SettingsSection s) => '${Routes.settings}/${s.name}';

String sectionLabel(L10n t, SettingsSection s) => switch (s) {
  SettingsSection.general => t.setGeneral,
  SettingsSection.appearance => t.setAppearance,
  SettingsSection.playback => t.setPlayback,
  SettingsSection.capture => t.capTab,
  SettingsSection.library => t.setLibrary,
  SettingsSection.downloads => t.setDownloads,
  SettingsSection.extension => t.setExtension,
  SettingsSection.shortcuts => t.setShortcuts,
  SettingsSection.data => t.setData,
  SettingsSection.updates => t.setUpdates,
  SettingsSection.about => t.setAbout,
};

/// W-S1…S3 Settings (Windows: own navigation in place of the sidebar) and
/// A-08 (Android: the list of sections, then one page per section). Every
/// change applies at once and is saved.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key, this.section});

  /// Null on Android's section list.
  final SettingsSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final mobile = !ref.watch(desktopShellProvider);
    if (mobile) {
      final s = section;
      return s == null
          ? _SettingsNav(current: null, mobile: true)
          : _SectionPage(section: s, mobile: true);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 232,
          decoration: BoxDecoration(
            color: c.sidebar,
            border: Border(right: BorderSide(color: c.divider)),
          ),
          child: _SettingsNav(
            current: section ?? SettingsSection.general,
            mobile: false,
          ),
        ),
        Expanded(
          child: _SectionPage(
            section: section ?? SettingsSection.general,
            mobile: false,
          ),
        ),
      ],
    );
  }
}

class _SettingsNav extends ConsumerWidget {
  const _SettingsNav({required this.current, required this.mobile});

  final SettingsSection? current;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        12,
        mobile ? MediaQuery.paddingOf(context).top + 12 : 14,
        12,
        16,
      ),
      children: [
        if (!mobile)
          Align(
            alignment: Alignment.centerLeft,
            child: Pressable(
              onTap: () {
                final back = ref.read(lastLocationProvider);
                context.go(
                  back.startsWith(Routes.settings) ? Routes.listenHome : back,
                );
              },
              semanticLabel: t.back,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorRegular.caretLeft, size: 18, color: c.muted),
                    const SizedBox(width: 2),
                    Text(t.back, style: MmType.label.copyWith(color: c.muted)),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          child: Text(
            t.navSettings,
            style: MmType.titleLg.copyWith(fontSize: 22, color: c.fg),
          ),
        ),
        for (final s in SettingsSection.values)
          // Keyboard shortcuts, the browser extension and the screen
          // tools are desktop matters (the screen tools: Windows only).
          if (s == SettingsSection.capture
              ? !mobile && Platform.isWindows
              : !mobile ||
                    s != SettingsSection.shortcuts &&
                        s != SettingsSection.extension)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Pressable(
                onTap: s == current
                    ? null
                    : () => mobile
                          ? context.push(sectionPath(s))
                          : context.go(sectionPath(s)),
                selected: s == current,
                semanticLabel: sectionLabel(t, s),
                borderRadius: BorderRadius.circular(MmRadius.pill),
                hoverColor: c.cardHover,
                child: Container(
                  height: mobile ? 52 : 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: s == current ? c.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    border: Border.all(
                      color: s == current ? c.line : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          sectionLabel(t, s),
                          style: MmType.label.copyWith(
                            fontSize: mobile ? 15 : 13.5,
                            color: s == current ? c.fg : c.fgSoft,
                          ),
                        ),
                      ),
                      if (mobile)
                        Icon(
                          PhosphorRegular.caretRight,
                          size: 18,
                          color: c.faint,
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

class _SectionPage extends ConsumerWidget {
  const _SectionPage({required this.section, required this.mobile});

  final SettingsSection section;
  final bool mobile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final body = switch (section) {
      SettingsSection.general => const _General(),
      SettingsSection.appearance => const _Appearance(),
      SettingsSection.playback => const _Playback(),
      SettingsSection.capture => const CaptureSettingsView(),
      SettingsSection.shortcuts => const ShortcutsView(),
      SettingsSection.library => const _Library(),
      SettingsSection.downloads => const DownloadSettings(),
      SettingsSection.extension => const ExtensionSettings(),
      SettingsSection.data => const _Data(),
      SettingsSection.updates => const UpdatesSettings(),
      SettingsSection.about => const _About(),
    };
    return ListView(
      padding: EdgeInsets.fromLTRB(
        mobile ? 16 : 40,
        mobile ? MediaQuery.paddingOf(context).top + 8 : 32,
        mobile ? 16 : 40,
        32,
      ),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (mobile)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Pressable(
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(Routes.settings),
                      semanticLabel: t.back,
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          PhosphorRegular.arrowLeft,
                          size: 22,
                          color: c.fg,
                        ),
                      ),
                    ),
                  ),
                Text(
                  section == SettingsSection.shortcuts
                      ? t.keysTitle
                      : sectionLabel(t, section),
                  style: MmType.display.copyWith(color: c.fg),
                ),
                const SizedBox(height: 18),
                body,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A titled card of settings rows (§ W-S2 groups).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.rows});

  final String? title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title!.toUpperCase(),
                style: MmType.overline.copyWith(color: c.muted),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(MmRadius.card),
              border: Border.all(color: c.divider),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.divider),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One setting: title, explanation, control on the right. A P1 row is
/// shown dimmed with its badge and cannot be changed (handoff rule).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.body,
    required this.control,
    this.p1 = false,
  });

  final String title;
  final String? body;
  final Widget control;
  final bool p1;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: MmType.labelStrong.copyWith(color: c.fg),
                      ),
                    ),
                    if (p1) ...[const SizedBox(width: 8), const P1Badge()],
                  ],
                ),
                if (body != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    body!,
                    style: MmType.caption.copyWith(
                      fontSize: 12.5,
                      color: c.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
    return p1 ? IgnorePointer(child: Opacity(opacity: 0.55, child: row)) : row;
  }
}

class P1Badge extends StatelessWidget {
  const P1Badge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: c.warningSubtle,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: c.warningBorder),
      ),
      child: Text(
        'P1',
        style: MmType.monoStyle(size: 9.5, weight: 700, color: c.warning),
      ),
    );
  }
}

/// Value with a menu (Sortie audio, Sous-titres par défaut…).
class SettingsMenu<T> extends StatelessWidget {
  const SettingsMenu({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<(T, String)> values;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final current =
        values.where((v) => v.$1 == selected).firstOrNull?.$2 ??
        values.first.$2;
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface2),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MmRadius.lg),
            side: BorderSide(color: c.overlayBorder),
          ),
        ),
      ),
      menuChildren: [
        for (final (value, text) in values)
          MenuItemButton(
            onPressed: onChanged == null ? null : () => onChanged!(value),
            leadingIcon: SizedBox(
              width: 18,
              child: value == selected
                  ? Icon(PhosphorRegular.check, size: 16, color: c.accent)
                  : null,
            ),
            child: Text(text, style: MmType.label.copyWith(color: c.fg)),
          ),
      ],
      builder: (context, menu, _) => Pressable(
        onTap: onChanged == null
            ? null
            : () => menu.isOpen ? menu.close() : menu.open(),
        semanticLabel: '$label : $current',
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                current,
                style: MmType.labelStrong.copyWith(fontSize: 13, color: c.fg),
              ),
              if (onChanged != null) ...[
                const SizedBox(width: 6),
                Icon(PhosphorRegular.caretDown, size: 15, color: c.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _General extends ConsumerWidget {
  const _General();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final look = ref.watch(appearanceProvider).value;
    if (look == null) return const SizedBox.shrink();
    final ctl = ref.read(appearanceProvider.notifier);
    return SettingsGroup(
      rows: [
        SettingsRow(
          title: t.language,
          body: t.languageBody,
          control: SettingsMenu<String?>(
            label: t.language,
            values: [
              (null, t.languageSystem),
              ('fr', 'Français'),
              ('en', 'English'),
              ('mg', 'Malagasy'),
            ],
            selected: look.language,
            onChanged: (v) => ctl.save(look.copyWith(language: v)),
          ),
        ),
        if (ref.watch(desktopShellProvider))
          SettingsRow(
            title: t.tourReplay,
            body: t.tourReplayBody,
            control: OutlinedButton(
              onPressed: () => ref.read(tourProvider.notifier).start(),
              child: Text(t.tourStart),
            ),
          ),
      ],
    );
  }
}

class _Appearance extends ConsumerWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final look = ref.watch(appearanceProvider).value;
    if (look == null) return const SizedBox.shrink();
    final ctl = ref.read(appearanceProvider.notifier);
    final colors = [
      ('coral', t.colorCoral),
      ('rose', t.colorRose),
      ('amber', t.colorAmber),
      ('blue', t.colorBlue),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.theme, style: MmType.labelStrong.copyWith(color: c.fg)),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: PillSegment(
            values: [
              (ThemePref.dark, t.themeDark),
              (ThemePref.light, t.themeLight),
              (ThemePref.system, t.themeSystem),
            ],
            selected: look.theme,
            onChanged: (v) => ctl.save(look.copyWith(theme: v)),
          ),
        ),
        const SizedBox(height: 22),
        Text(t.playColor, style: MmType.labelStrong.copyWith(color: c.fg)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (id, name) in colors) ...[
              Pressable(
                onTap: () => ctl.save(look.copyWith(playColor: id)),
                semanticLabel: name,
                selected: look.playColor == id,
                borderRadius: BorderRadius.circular(MmRadius.md),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Column(
                    children: [
                      // The ring of the mockup: a gap, then a fg circle.
                      Container(
                        width: 44,
                        height: 44,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: look.playColor == id
                              ? Border.all(color: c.fg, width: 2)
                              : null,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: MmColors.playColors[id],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: MmType.caption.copyWith(color: c.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          rows: [
            SettingsRow(
              title: t.density,
              body: t.densityBody,
              control: SettingsMenu<Density>(
                label: t.density,
                values: [
                  (Density.comfortable, t.densityComfortable),
                  (Density.compact, t.densityCompact),
                ],
                selected: look.density,
                onChanged: (v) => ctl.save(look.copyWith(density: v)),
              ),
            ),
            SettingsRow(
              title: t.textSize,
              body: t.textSizeBody,
              control: SettingsMenu<double>(
                label: t.textSize,
                values: [
                  for (final s in AppearancePrefs.textScales)
                    (s, '${(s * 100).round()} %'),
                ],
                selected: look.textScale,
                onChanged: (v) => ctl.save(look.copyWith(textScale: v)),
              ),
            ),
            SettingsRow(
              title: t.reduceMotion,
              body: t.reduceMotionBody,
              control: MmSwitch(
                value: look.reduceMotion,
                label: t.reduceMotion,
                onChanged: (v) => ctl.save(look.copyWith(reduceMotion: v)),
              ),
            ),
            SettingsRow(
              title: t.reduceTransparency,
              body: t.reduceTransparencyBody,
              control: MmSwitch(
                value: look.reduceTransparency,
                label: t.reduceTransparency,
                onChanged: (v) =>
                    ctl.save(look.copyWith(reduceTransparency: v)),
              ),
            ),
            SettingsRow(
              title: t.coverBackdrop,
              body: t.coverBackdropBody,
              control: MmSwitch(
                value: look.coverBackdrop,
                label: t.coverBackdrop,
                onChanged: (v) => ctl.save(look.copyWith(coverBackdrop: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Playback extends ConsumerWidget {
  const _Playback();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final prefs = ref.watch(playbackPrefsProvider).value;
    final caps = ref.watch(mediaEngineProvider)?.capabilities;
    final outputs = ref.watch(audioOutputsProvider).value ?? const [];
    if (prefs == null) return const SizedBox.shrink();
    final ctl = ref.read(playbackPrefsProvider.notifier);
    final e = prefs.engine;
    void engine(EnginePreferences next) =>
        ctl.save(prefs.copyWith(engine: next));

    String outputLabel(AudioOutput o) =>
        o.id == 'auto' || o.label.isEmpty ? t.systemDefault : o.label;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: t.engineSection,
          rows: [
            SettingsRow(
              title: t.engine,
              body: Platform.isAndroid
                  ? t.engineBodyAndroid
                  : t.engineBodyWindows,
              control: SettingsMenu<int>(
                label: t.engine,
                values: [(0, t.engineValue)],
                selected: 0,
                onChanged: null,
              ),
            ),
            SettingsRow(
              title: t.audioOutput,
              body: t.audioOutputBody,
              control: SettingsMenu<String>(
                label: t.audioOutput,
                values: outputs.isEmpty
                    ? [('auto', t.systemDefault)]
                    : [for (final o in outputs) (o.id, outputLabel(o))],
                selected: e.audioOutput,
                onChanged: (caps?.audioOutputs ?? false) && outputs.length > 1
                    ? (v) => engine(withEngine(e, audioOutput: v))
                    : null,
              ),
            ),
            if (caps?.exclusiveAudio ?? false)
              SettingsRow(
                title: t.exclusive,
                body: t.exclusiveBody,
                control: MmSwitch(
                  value: e.exclusiveAudio,
                  label: t.exclusive,
                  onChanged: (v) => engine(withEngine(e, exclusiveAudio: v)),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: t.chainSection,
          rows: [
            SettingsRow(
              title: t.resumeSetting,
              body: t.resumeSettingBody,
              control: MmSwitch(
                value: prefs.resume,
                label: t.resumeSetting,
                onChanged: (v) => ctl.save(prefs.copyWith(resume: v)),
              ),
            ),
            if (Platform.isAndroid)
              SettingsRow(
                title: t.videoGestures,
                body: t.videoGesturesBody,
                control: MmSwitch(
                  value: prefs.videoGestures,
                  label: t.videoGestures,
                  onChanged: (v) => ctl.save(prefs.copyWith(videoGestures: v)),
                ),
              ),
            // The queue prepares the next file in the engine (gapless) or
            // in a second one (crossfade); not offered where the engine
            // cannot.
            SettingsRow(
              title: t.smartShuffleSetting,
              body: t.smartShuffleSettingBody,
              control: MmSwitch(
                value: prefs.smartShuffle,
                label: t.smartShuffleSetting,
                onChanged: (v) => ctl.save(prefs.copyWith(smartShuffle: v)),
              ),
            ),
            SettingsRow(
              title: t.autoplaySetting,
              body: t.autoplaySettingBody,
              control: MmSwitch(
                value: prefs.autoplay,
                label: t.autoplaySetting,
                onChanged: (v) => ctl.save(prefs.copyWith(autoplay: v)),
              ),
            ),
            if (caps?.gapless ?? false)
              SettingsRow(
                title: t.gapless,
                body: t.gaplessBody,
                control: MmSwitch(
                  value: prefs.gapless,
                  label: t.gapless,
                  onChanged: (v) => ctl.save(prefs.copyWith(gapless: v)),
                ),
              ),
            if (caps?.crossfade ?? false)
              SettingsRow(
                title: t.crossfade,
                body: e.exclusiveAudio ? t.crossfadeExclusive : t.crossfadeBody,
                control: SettingsMenu<int>(
                  label: t.crossfade,
                  values: [
                    for (final s in PlaybackPrefs.crossfadeChoices)
                      (s, s == 0 ? t.off : t.crossfadeSeconds(s)),
                  ],
                  selected: prefs.crossfadeSecs,
                  onChanged: e.exclusiveAudio
                      ? null
                      : (v) => ctl.save(prefs.copyWith(crossfadeSecs: v)),
                ),
              ),
            if (caps?.normalization ?? false)
              SettingsRow(
                title: t.normalizationSetting,
                body: t.normalizationSettingBody,
                control: MmSwitch(
                  value: e.normalize,
                  label: t.normalizationSetting,
                  onChanged: (v) => engine(withEngine(e, normalize: v)),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: t.videoSection,
          rows: [
            if (caps?.hardwareDecoding ?? false)
              SettingsRow(
                title: t.hwDecoding,
                body: t.hwDecodingBody,
                control: MmSwitch(
                  value: e.hardwareDecoding,
                  label: t.hwDecoding,
                  onChanged: (v) => engine(withEngine(e, hardwareDecoding: v)),
                ),
              ),
            if (caps?.subtitleLanguage ?? true)
              SettingsRow(
                title: t.defaultSubtitles,
                body: t.defaultSubtitlesBody,
                control: SettingsMenu<String?>(
                  label: t.defaultSubtitles,
                  values: [
                    (null, t.none),
                    for (final l in subtitleLanguages.entries) (l.key, l.value),
                  ],
                  selected: e.subtitleLanguage,
                  onChanged: (v) => engine(withEngine(e, subtitleLanguage: v)),
                ),
              ),
            if (caps?.sidecarSubtitles ?? false)
              SettingsRow(
                title: t.sidecar,
                body: t.sidecarBody,
                control: MmSwitch(
                  value: e.sidecarSubtitles,
                  label: t.sidecar,
                  onChanged: (v) => engine(withEngine(e, sidecarSubtitles: v)),
                ),
              ),
          ],
        ),
        // Decision 0011: Obtenir for online tracks.
        const OnlineSettingsGroup(),
      ],
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.title, required this.body, required this.path});

  final String title;
  final String body;
  final String? path;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final p = path;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MmType.labelStrong.copyWith(color: c.fg)),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: MmType.caption.copyWith(
                    fontSize: 12.5,
                    color: c.muted,
                  ),
                ),
                if (p != null) ...[
                  const SizedBox(height: 6),
                  SelectableText(
                    p,
                    style: MmType.monoStyle(size: 11.5, color: c.fgSoft),
                  ),
                ],
              ],
            ),
          ),
          // Windows: shown in Explorer (arguments passed as a list, never a
          // shell string).
          if (p != null && Platform.isWindows) ...[
            const SizedBox(width: 16),
            SettingsAction(
              label: t.openFolder,
              onTap: () => Process.run('explorer.exe', [p]),
            ),
          ],
        ],
      ),
    );
  }
}

class _Library extends ConsumerWidget {
  const _Library();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final folders = ref.watch(libraryFoldersProvider).value ?? const [];
    final status = ref.watch(indexStatusProvider).value;
    final health = ref.watch(healthCountsProvider).value;
    final missing = health?.missing.toInt() ?? 0;
    final duplicates = health?.duplicates ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.libraryFolders.toUpperCase(),
          style: MmType.overline.copyWith(color: c.muted),
        ),
        const SizedBox(height: 4),
        Text(
          t.libraryFoldersBody,
          style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
        ),
        const SizedBox(height: 10),
        if (folders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              t.noFolders,
              style: MmType.bodySm.copyWith(color: c.fgSoft),
            ),
          )
        else
          FolderList(folders: folders),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            SettingsAction(
              label: t.addFolder,
              onTap: () async {
                final path = await pickFolder(ref, FolderKind.music);
                if (path != null) await scanFolders(ref);
              },
            ),
            SettingsAction(
              label: t.scanNow,
              onTap: folders.isEmpty ? null : () => scanFolders(ref),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (status != null) ScanProgressCard(status: status),
        // W-O2: reachable from here even when the sidebar shows nothing.
        const SizedBox(height: 26),
        Text(
          t.healthGroup.toUpperCase(),
          style: MmType.overline.copyWith(color: c.muted),
        ),
        const SizedBox(height: 10),
        SettingsGroup(
          rows: [
            SettingsRow(
              title: t.missingTitle,
              body: missing > 0
                  ? t.missingSubtitle(missing)
                  : t.missingEmptyTitle,
              control: SettingsAction(
                label: t.show,
                onTap: () => context.go(Routes.missing),
              ),
            ),
            SettingsRow(
              title: t.duplicatesTitle,
              body: t.duplicatesFound(duplicates),
              control: SettingsAction(
                label: t.show,
                onTap: () => context.go(Routes.duplicates),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Data extends ConsumerWidget {
  const _Data();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final dir = ref.watch(dataDirProvider).value;
    final hasHistory = ref.watch(historyProvider).value?.isNotEmpty ?? false;
    return SettingsGroup(
      rows: [
        _PathRow(title: t.dataFolder, body: t.dataFolderBody, path: dir),
        SettingsRow(
          title: t.playHistory,
          body: t.playHistoryBody,
          control: SettingsAction(
            label: t.historyClear,
            onTap: hasHistory ? () => confirmClearHistory(context, ref) : null,
          ),
        ),
      ],
    );
  }
}

class SettingsAction extends StatelessWidget {
  const SettingsAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: c.lineStrong),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: MmType.labelStrong.copyWith(fontSize: 13, color: c.fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// Version given at build time (--dart-define=MM_VERSION=...); a local build
/// says it is one.
const appVersion = String.fromEnvironment('MM_VERSION');

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final version = appVersion.isEmpty ? t.aboutDevBuild : appVersion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const MiarinaLogo(size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.appTitle, style: MmType.title.copyWith(color: c.fg)),
                  Text(
                    t.aboutLocal,
                    style: MmType.bodySm.copyWith(color: c.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        SettingsGroup(
          rows: [
            SettingsRow(
              title: t.aboutVersion,
              control: Text(
                version,
                style: MmType.monoStyle(size: 12.5, color: c.fg),
              ),
            ),
            SettingsRow(
              title: t.aboutLicense,
              control: Text(
                'GPL-3.0-only',
                style: MmType.monoStyle(size: 12.5, color: c.fg),
              ),
            ),
            SettingsRow(
              title: t.aboutLicenses,
              body: t.aboutLicensesBody,
              control: SettingsAction(
                label: t.show,
                onTap: () {
                  registerAssetLicenses();
                  showLicensePage(
                    context: context,
                    applicationName: t.appTitle,
                    applicationVersion: version,
                    applicationLegalese: 'GPL-3.0-only',
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SettingsGroup(
          rows: [
            SettingsRow(
              title: 'Miarina',
              body: t.aboutCompanyBody,
              control: SettingsAction(
                label: 'miarina.org',
                onTap: () => _openSite(_companySite),
              ),
            ),
            SettingsRow(
              title: t.aboutDeveloper,
              body: '© 2026 Harinjaka',
              control: SettingsAction(
                label: 'cv.harinjaka.org',
                onTap: () => _openSite(_developerSite),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

const _companySite = 'https://miarina.org';
const _developerSite = 'https://cv.harinjaka.org/';

/// Opens one of the fixed addresses above in the default browser.
void _openSite(String url) {
  if (Platform.isWindows) Process.run('explorer.exe', [url]);
}
