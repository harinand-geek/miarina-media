import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/extension.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;
import '../library/library_data.dart' show dataDirProvider;
import '../now_playing/sound_view.dart' show MmSwitch;
import 'settings_screen.dart';

export '../../src/rust/api/extension.dart' show ExtensionStatus;

// Settings › Extension navigateur (Windows v2, EXT-01): the Chrome and Edge
// extension sends a link to Miarina Media, which opens its analysis.
// Adaptations of the mockup (docs/decisions/0009): the extension has a
// fixed ID and the app registers it itself, so step 2 connects this PC in
// one click instead of a pairing code; until the extension is in the
// stores, step 1 opens its folder for « Charger l'extension non
// empaquetée ».

/// The registration in the core (api/extension.rs); tests use a fake.
abstract interface class ExtensionApi {
  rust.ExtensionStatus status(String dataDir);
  rust.ExtensionStatus setEnabled(String dataDir, bool enabled);
  Future<bool> test(String dataDir);
}

class RustExtensionApi implements ExtensionApi {
  @override
  rust.ExtensionStatus status(String dataDir) =>
      rust.extensionStatus(dataDir: dataDir);

  @override
  rust.ExtensionStatus setEnabled(String dataDir, bool enabled) =>
      rust.extensionSetEnabled(dataDir: dataDir, enabled: enabled);

  @override
  Future<bool> test(String dataDir) => rust.extensionTest(dataDir: dataDir);
}

final extensionApiProvider = Provider<ExtensionApi?>(
  (ref) => Platform.isWindows && RustLib.instance.initialized
      ? RustExtensionApi()
      : null,
);

@immutable
class ExtensionState {
  const ExtensionState({this.status, this.tested, this.testOk = false});

  final rust.ExtensionStatus? status;

  /// Last test (this session).
  final DateTime? tested;
  final bool testOk;

  bool get connected => (status?.chrome ?? false) || (status?.edge ?? false);
}

final extensionProvider = NotifierProvider<ExtensionController, ExtensionState>(
  ExtensionController.new,
);

class ExtensionController extends Notifier<ExtensionState> {
  ExtensionApi? get _api => ref.read(extensionApiProvider);

  @override
  ExtensionState build() {
    final dir = ref.watch(dataDirProvider).value;
    final api = ref.watch(extensionApiProvider);
    if (dir == null || api == null) return const ExtensionState();
    try {
      return ExtensionState(status: api.status(dir));
    } catch (e) {
      debugPrint('extension status: $e');
      return const ExtensionState();
    }
  }

  /// Null when done, else the reason (`bridge_missing`, or the system's).
  String? setEnabled(bool enabled) {
    final dir = ref.read(dataDirProvider).value;
    final api = _api;
    if (dir == null || api == null) return 'bridge_missing';
    try {
      state = ExtensionState(status: api.setEnabled(dir, enabled));
      return null;
    } catch (e) {
      state = ExtensionState(status: api.status(dir));
      return '$e'.contains('bridge_missing') ? 'bridge_missing' : '$e';
    }
  }

  Future<bool> test() async {
    final dir = ref.read(dataDirProvider).value;
    final api = _api;
    if (dir == null || api == null) return false;
    final ok = await api.test(dir);
    state = ExtensionState(
      status: state.status,
      tested: DateTime.now(),
      testOk: ok,
    );
    return ok;
  }
}

class ExtensionSettings extends ConsumerWidget {
  const ExtensionSettings({super.key});

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final state = ref.watch(extensionProvider);
    final ctl = ref.read(extensionProvider.notifier);
    final s = state.status;
    final bridge = s?.bridge ?? false;
    final folder = s?.folder;

    void connect(bool on) {
      final error = ctl.setEnabled(on);
      if (error != null) {
        _toast(
          context,
          error == 'bridge_missing' ? t.extNoBridge : t.extFailed,
        );
      }
    }

    final String testLine;
    if (state.tested == null) {
      testLine = t.extTestNever;
    } else {
      final at = DateFormat.Hm(Localizations.localeOf(context).languageCode)
          .format(state.tested!);
      testLine = state.testOk ? t.extTestOk(at) : t.extTestFailed(at);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(t.extLead, style: MmType.bodySm.copyWith(color: c.fgSoft)),
        const SizedBox(height: 16),
        if (!bridge)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              t.extNoBridge,
              style: MmType.bodySm.copyWith(color: c.warning),
            ),
          ),
        SettingsGroup(
          rows: [
            SettingsRow(
              title: t.extAccept,
              body: t.extAcceptBody,
              control: MmSwitch(
                value: state.connected,
                label: t.extAccept,
                onChanged: bridge ? connect : null,
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: t.extSteps,
          rows: [
            _Step(
              n: 1,
              title: t.extStep1,
              body: t.extStep1Body,
              action: SettingsAction(
                label: t.extOpenFolder,
                onTap: folder == null
                    ? null
                    : () => Process.run('explorer.exe', [folder]),
              ),
            ),
            _Step(
              n: 2,
              title: t.extStep2,
              body: state.connected
                  ? t.extConnected
                  : s?.other ?? false
                  ? t.extOther
                  : t.extStep2Body,
              done: state.connected,
              action: SettingsAction(
                label: state.connected ? t.extDisconnect : t.extConnect,
                onTap: bridge ? () => connect(!state.connected) : null,
              ),
            ),
            _Step(
              n: 3,
              title: t.extStep3,
              body: testLine,
              done: state.tested != null && state.testOk,
              action: SettingsAction(
                label: t.extTest,
                onTap: state.connected
                    ? () async {
                        final ok = await ctl.test();
                        if (context.mounted) {
                          _toast(context, ok ? t.extTestDone : t.extTestBad);
                        }
                      }
                    : null,
              ),
            ),
          ],
        ),
        Text(
          t.extPrivacy,
          style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
        ),
      ],
    );
  }
}

/// One step of the wizard: number (a check once done), title, line, button.
class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.body,
    required this.action,
    this.done = false,
  });

  final int n;
  final String title;
  final String body;
  final Widget action;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? c.accent : c.accentSubtle,
              shape: BoxShape.circle,
            ),
            child: done
                ? const Icon(
                    PhosphorRegular.check,
                    size: 16,
                    color: Color(0xFF062320),
                  )
                : Text(
                    '$n',
                    style: MmType.labelStrong.copyWith(color: c.chipText),
                  ),
          ),
          const SizedBox(width: 14),
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
              ],
            ),
          ),
          const SizedBox(width: 12),
          action,
        ],
      ),
    );
  }
}

/// The extension can send links (Obtenir shows its hint).
final extensionConnectedProvider = Provider<bool>(
  (ref) => ref.watch(extensionProvider.select((s) => s.connected)),
);
