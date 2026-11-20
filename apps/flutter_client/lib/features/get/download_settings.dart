import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_widgets.dart' show PillSegment;
import '../settings/settings_screen.dart' show SettingsGroup, SettingsRow;
import 'get_data.dart';
import 'get_screens.dart' show bytes, pickDownloadDir, revealProvider;

/// Media tools (yt-dlp, FFmpeg…) as Settings shows them.
final toolsProvider = FutureProvider<List<ToolStatus>>((ref) async {
  if (!ref.watch(downloadsProvider.select((s) => s.ready))) return const [];
  return ref.read(getApiProvider).tools();
});

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

class _Action extends StatelessWidget {
  const _Action(this.label, this.onTap);

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

/// Settings › Téléchargements, ported from the Tauri app (Downloads tab, and
/// the resource mode of its Performance tab): folder, simultaneous
/// downloads, Eco / Balanced / Performance (real limits), media tools.
/// Not built yet in the Tauri app either: listed and marked planned.
class DownloadSettings extends ConsumerStatefulWidget {
  const DownloadSettings({super.key});

  @override
  ConsumerState<DownloadSettings> createState() => _DownloadSettingsState();
}

class _DownloadSettingsState extends ConsumerState<DownloadSettings> {
  bool _checking = false;
  bool _installing = false;

  GetApi get _api => ref.read(getApiProvider);

  Future<void> _set(Future<GetSettings> Function() change) async {
    await change();
    ref.invalidate(getSettingsProvider);
  }

  Future<void> _checkUpdates() async {
    final t = L10n.of(context);
    setState(() => _checking = true);
    try {
      final r = await _api.updateYtDlp();
      if (mounted) {
        _toast(
          context,
          r.updated
              ? t.getYtdlpUpdated(r.version)
              : t.getYtdlpLatest(r.version),
        );
      }
      ref.invalidate(toolsProvider);
    } catch (_) {
      if (mounted) _toast(context, t.getUpdFailed);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _install() async {
    final t = L10n.of(context);
    setState(() => _installing = true);
    try {
      await _api.installTools();
      if (mounted) _toast(context, t.getToolsInstalled);
      ref.invalidate(toolsProvider);
    } catch (_) {
      if (mounted) _toast(context, t.getInstallFailed);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final settings = ref.watch(getSettingsProvider).value;
    final tools = ref.watch(toolsProvider).value ?? const <ToolStatus>[];
    final planned = Text('—', style: MmType.body.copyWith(color: c.faint));
    if (settings == null) return const SizedBox.shrink();
    final n = settings.concurrency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          rows: [
            SettingsRow(
              title: t.getSaveTo,
              body: settings.downloadDir,
              control: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Action(
                    t.getOpenFolder,
                    () => ref.read(revealProvider)(settings.downloadDir),
                  ),
                  const SizedBox(width: 8),
                  _Action(t.getChange, () => pickDownloadDir(context, ref)),
                ],
              ),
            ),
            SettingsRow(
              title: t.getSimultaneous,
              body: t.getSimultaneousDesc,
              control: _Stepper(
                value: n,
                min: 1,
                max: settings.maxConcurrency,
                label: t.getSimultaneous,
                onChanged: (v) => _set(() => _api.setConcurrency(v)),
              ),
            ),
            SettingsRow(
              title: t.getResourceMode,
              body: t.getModeDesc(
                settings.maxDownloads,
                settings.maxConversions,
              ),
              control: PillSegment<String>(
                values: [
                  ('eco', t.getModeEco),
                  ('balanced', t.getModeBalanced),
                  ('performance', t.getModePerformance),
                ],
                selected: settings.resourceMode,
                onChanged: (m) => _set(() => _api.setResourceMode(m)),
              ),
            ),
            SettingsRow(
              title: t.getDefaultVideoQuality,
              body: t.getDefaultVideoQualityDesc,
              p1: true,
              control: planned,
            ),
            SettingsRow(title: t.getDefaultAudio, p1: true, control: planned),
            SettingsRow(title: t.getSpeedLimit, p1: true, control: planned),
            SettingsRow(
              title: t.getDownloadSubs,
              body: t.getDownloadSubsDesc,
              p1: true,
              control: planned,
            ),
          ],
        ),
        if (tools.isNotEmpty)
          SettingsGroup(
            title: t.getMediaTools,
            rows: [
              for (final tool in tools)
                SettingsRow(
                  title: tool.name,
                  body: tool.id == 'yt_dlp' && tool.installed
                      ? '${tool.version} · ${tool.license} · ${t.getAutoUpdated}'
                      : tool.bundled
                      ? '${tool.version} · ${tool.license}'
                      : '${tool.version} · ${tool.license} · ${t.getToDownload(bytes(context, tool.downloadBytes.toInt()))}',
                  control: tool.installed
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tool.bundled
                                  ? t.getIncludedVerified
                                  : t.getInstalledVerified,
                              style: MmType.labelStrong.copyWith(
                                fontSize: 12.5,
                                color: c.accentStrong,
                              ),
                            ),
                            if (tool.id == 'yt_dlp') ...[
                              const SizedBox(width: 12),
                              _Action(
                                _checking ? t.getUpdChecking : t.getUpdCheck,
                                _checking ? null : _checkUpdates,
                              ),
                            ],
                          ],
                        )
                      : _Action(
                          _installing ? t.getDownloadingShort : t.getDownload,
                          _installing ? null : _install,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final int min;
  final int max;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    Widget button(IconData icon, String tip, int? to) => Tooltip(
      message: tip,
      child: Pressable(
        onTap: to == null ? null : () => onChanged(to),
        semanticLabel: '$label · $tip',
        child: Opacity(
          opacity: to == null ? 0.4 : 1,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(icon, size: 16, color: c.fg),
          ),
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: c.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            PhosphorRegular.minus,
            t.getLess,
            value > min ? value - 1 : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: MmType.monoStyle(size: 13, color: c.fg),
            ),
          ),
          button(
            PhosphorRegular.plus,
            t.getMore,
            value < max ? value + 1 : null,
          ),
        ],
      ),
    );
  }
}
