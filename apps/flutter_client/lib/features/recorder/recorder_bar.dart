import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../engine/media_engine.dart' show MediaSource;
import '../../l10n/app_localizations.dart';
import '../playback/playback.dart';
import '../updates/updates_view.dart' show rootMessengerKey;
import 'recorder_data.dart';
import 'recorder_screen.dart' show clockOf;

/// Above every screen (app root): while recording the window is the
/// floating bar (the screens wait under it, not drawn), and the toast
/// after each recording.
class RecorderHost extends ConsumerStatefulWidget {
  const RecorderHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RecorderHost> createState() => _RecorderHostState();
}

class _RecorderHostState extends ConsumerState<RecorderHost> {
  StreamSubscription<RecorderEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = ref.read(recorderProvider.notifier).events.listen(_toast);
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  void _toast(RecorderEvent e) {
    final messenger = rootMessengerKey.currentState;
    final context = rootMessengerKey.currentContext;
    if (messenger == null || context == null) return;
    final t = L10n.of(context);
    SnackBarAction? action;
    final text = switch (e) {
      RecordingSaved(:final recording) => () {
        action = SnackBarAction(
          label: t.recPlay,
          onPressed: () => unawaited(_play(recording)),
        );
        return recording.format == 'gif' ? t.recGifSaved : t.recSavedToast;
      }(),
      RecordingFailed(:final reason) => switch (reason) {
        'window_gone' => t.recWindowGone,
        'no_screen' => t.recNoScreen,
        'finish_failed' => t.recFinishFailed,
        'ffmpeg_missing' => t.convToolsMissing,
        _ => t.recFailed,
      },
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: action,
          content: Text(text),
        ),
      );
  }

  Future<void> _play(RecentRecording r) async {
    await ref.read(queueProvider.notifier).playAll([
      QueueEntry(
        source: MediaSource.file(r.path),
        title: r.name,
        isVideo: r.format != 'gif',
      ),
    ]);
    ref.read(routerProvider).go(Routes.watch);
  }

  @override
  Widget build(BuildContext context) {
    final bar = ref.watch(recorderProvider.select((s) => s.barShown));
    if (!bar) return widget.child;
    return Stack(
      children: [
        // The screens keep their state but are neither laid out in the
        // bar's size nor animated while recording.
        Offstage(
          child: TickerMode(
            enabled: false,
            child: OverflowBox(
              minWidth: 1280,
              maxWidth: 1280,
              minHeight: 800,
              maxHeight: 800,
              child: widget.child,
            ),
          ),
        ),
        const Positioned.fill(
          child: Material(
            type: MaterialType.transparency,
            child: RecorderBar(),
          ),
        ),
      ],
    );
  }
}

/// The floating bar (handoff « Barre flottante d'enregistrement »): REC
/// and the time, pause, microphone, stop. Left out of the video.
class RecorderBar extends ConsumerWidget {
  const RecorderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = ref.watch(recorderProvider);
    final rec = ref.read(recorderProvider.notifier);
    final micOn =
        ref.watch(recorderSettingsProvider).value?.mic == true &&
        ref.watch(recorderSettingsProvider).value?.format != 'gif';
    const red = Color(0xFFF07070);
    final paused = s.phase == RecPhase.paused;

    Widget round(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
    }) => Pressable(
      onTap: onTap,
      semanticLabel: label,
      hoverColor: c.surface,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 18, color: color ?? c.fg),
      ),
    );

    final List<Widget> content = switch (s.phase) {
      RecPhase.countdown => [
        Text(t.recStarting, style: MmType.bodySm.copyWith(color: c.muted)),
        const SizedBox(width: 10),
        Text(
          '${s.countdown}',
          style: MmType.monoStyle(size: 20, weight: 700, color: red),
        ),
        const Spacer(),
        _StopButton(
          label: t.capCancel,
          onTap: () => unawaited(rec.cancelCountdown()),
        ),
      ],
      RecPhase.finalizing => [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
        ),
        const SizedBox(width: 12),
        Text(t.recFinalizing, style: MmType.bodySm.copyWith(color: c.fg)),
      ],
      _ => [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: paused ? const Color(0xFF5B6B7C) : red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          paused ? t.recPausedLabel : t.recRec,
          style: MmType.monoStyle(size: 11, weight: 700, color: red),
        ),
        const SizedBox(width: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 72),
          child: Text(
            clockOf(s.elapsedMs),
            style: MmType.monoStyle(size: 14, weight: 600, color: c.fg),
          ),
        ),
        Container(
          width: 1,
          height: 20,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: c.line,
        ),
        round(
          paused ? PhosphorFill.play : PhosphorFill.pause,
          paused ? t.recResume : t.recPause,
          () => unawaited(paused ? rec.resume() : rec.pause()),
        ),
        if (micOn)
          round(
            s.micMuted
                ? PhosphorRegular.microphoneSlash
                : PhosphorRegular.microphone,
            s.micMuted ? t.recMicUnmute : t.recMicMute,
            rec.toggleMic,
            color: s.micMuted ? const Color(0xFF64748B) : null,
          ),
        const Spacer(),
        _StopButton(label: t.recStop, onTap: () => unawaited(rec.stop())),
      ],
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 6, 0),
      decoration: BoxDecoration(
        color: c.sidebar,
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: c.overlayBorder),
      ),
      child: Row(children: content),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: c.danger,
          borderRadius: BorderRadius.circular(MmRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(PhosphorFill.stop, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: MmType.labelStrong.copyWith(
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
