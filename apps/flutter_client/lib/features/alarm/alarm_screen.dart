import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/malagasy_fallback.dart';
import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../now_playing/sound_view.dart' show ChoicePill, MmSwitch;
import '../playback/playback.dart';
import 'alarm_data.dart';

/// Shows the ringing screen when the alarm rings; watched by the app root.
final alarmKeeperProvider = Provider<void>((ref) {
  ref.listen(alarmProvider.select((s) => s.ringing), (was, now) {
    if (now && was != true) ref.read(routerProvider).push(Routes.alarmRinging);
  }, fireImmediately: true);
});

/// « Lundi 1 décembre · 07:00 ».
String alarmWhen(BuildContext context, DateTime at) {
  final locale = intlLocaleOf(context);
  final day = DateFormat.MMMMEEEEd(locale).format(at);
  return '${day[0].toUpperCase()}${day.substring(1)} · '
      '${DateFormat.Hm(locale).format(at)}';
}

/// The music alarm's settings: on or off, the time, the days, the music,
/// the volume and the gradual sound.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Android's page that allows exact alarms.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      unawaited(ref.read(alarmProvider.notifier).refreshPermission());
    }
  }

  Future<void> _pickTime(AlarmSettings s) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: s.hour, minute: s.minute),
    );
    if (picked == null || !mounted) return;
    await ref
        .read(alarmProvider.notifier)
        .save(
          s.copyWith(hour: picked.hour, minute: picked.minute, enabled: true),
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final state = ref.watch(alarmProvider);
    final s = state.settings;
    final ctl = ref.read(alarmProvider.notifier);
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final pad = mobile ? 16.0 : 32.0;
    final locale = intlLocaleOf(context);
    final weekday = DateFormat.E(locale);
    // A Monday, to name the days.
    final monday = DateTime(2026, 11, 30);
    final sub = MmType.bodySm.copyWith(color: c.muted);
    final label = MmType.heading.copyWith(fontSize: 15, color: c.fg);

    Widget card(Widget child) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: c.brightness == Brightness.dark
            ? c.surface
            : Color.lerp(c.bg, c.fg, 0.07),
        borderRadius: BorderRadius.circular(28),
      ),
      child: child,
    );

    final next = state.next;
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, mobile ? 12 : 24, pad, 120),
      children: [
        Text(t.alarmTitle, style: MmType.display.copyWith(color: c.fg)),
        const SizedBox(height: 2),
        Text(t.alarmBody, style: sub),
        const SizedBox(height: 18),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Pressable(
                      onTap: () => _pickTime(s),
                      semanticLabel: t.alarmTitle,
                      child: Text(
                        DateFormat.Hm(locale)
                            .format(DateTime(2026, 1, 1, s.hour, s.minute)),
                        style: MmType.displayXl.copyWith(
                          fontSize: 64,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                          fontVariations: const [FontVariation.weight(600)],
                          color: s.enabled ? c.fg : c.muted,
                        ),
                      ),
                    ),
                  ),
                  MmSwitch(
                    value: s.enabled,
                    label: t.alarmTitle,
                    onChanged: (v) => ctl.save(s.copyWith(enabled: v)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                next == null
                    ? t.alarmOff
                    : t.alarmNext(alarmWhen(context, next)),
                style: MmType.body.copyWith(color: c.fgSoft),
              ),
              if (Platform.isWindows) ...[
                const SizedBox(height: 4),
                Text(t.alarmAppOpen, style: sub),
              ],
              if (s.enabled && !state.exactAllowed) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(PhosphorRegular.warning, size: 18, color: c.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.alarmExactNeeded,
                        style: MmType.bodySm.copyWith(color: c.fgSoft),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoicePill(
                      label: t.alarmAllow,
                      on: true,
                      onTap: () => unawaited(ctl.requestExact()),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.alarmDays, style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = 1; d <= 7; d++)
                    ChoicePill(
                      label: weekday
                          .format(monday.add(Duration(days: d - 1)))
                          .replaceAll('.', ''),
                      on: s.days.contains(d),
                      onTap: () {
                        final days = {...s.days};
                        days.contains(d) ? days.remove(d) : days.add(d);
                        unawaited(ctl.save(s.copyWith(days: days)));
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(t.alarmOnce, style: sub),
              const SizedBox(height: 18),
              Text(t.alarmMusic, style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (src, name) in [
                    (AlarmSource.mix, t.dailyMix),
                    (AlarmSource.favorites, t.navFavorites),
                    (AlarmSource.all, t.alarmAllMusic),
                  ])
                    ChoicePill(
                      label: name,
                      on: s.source == src,
                      onTap: () => unawaited(ctl.save(s.copyWith(source: src))),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Platform.isAndroid) ...[
                Text(t.alarmVolume, style: label),
                Slider(
                  value: s.volume,
                  min: 0.1,
                  divisions: 9,
                  activeColor: c.coral,
                  label: '${(s.volume * 100).round()} %',
                  onChanged: (v) => unawaited(ctl.save(s.copyWith(volume: v))),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.alarmGradual, style: label),
                        Text(t.alarmGradualBody, style: sub),
                      ],
                    ),
                  ),
                  MmSwitch(
                    value: s.gradual,
                    label: t.alarmGradual,
                    onChanged: (v) => ctl.save(s.copyWith(gradual: v)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The alarm rings: the time, what plays, « Arrêter » and « Encore
/// 10 min ».
class AlarmRingingScreen extends ConsumerStatefulWidget {
  const AlarmRingingScreen({super.key});

  @override
  ConsumerState<AlarmRingingScreen> createState() => _AlarmRingingState();
}

class _AlarmRingingState extends ConsumerState<AlarmRingingScreen> {
  late final Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.listenHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final locale = intlLocaleOf(context);
    final entry = ref.watch(queueProvider.select((q) => q.current));
    final ctl = ref.read(alarmProvider.notifier);

    Widget button(
      String text, {
      required bool main,
      required VoidCallback onTap,
    }) => Pressable(
      onTap: onTap,
      semanticLabel: text,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: main ? c.coral : c.surface2,
          borderRadius: BorderRadius.circular(MmRadius.pill),
        ),
        child: Text(
          text,
          style: MmType.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontVariations: const [FontVariation.weight(600)],
            color: main ? c.coralInk : c.fg,
          ),
        ),
      ),
    );

    return Material(
      color: c.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          child: Column(
            children: [
              Text(
                t.alarmGoodMorning,
                style: MmType.title.copyWith(color: c.fgSoft),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.Hm(locale).format(_now),
                style: MmType.displayXl.copyWith(
                  fontSize: 88,
                  height: 1,
                  fontWeight: FontWeight.w600,
                  fontVariations: const [FontVariation.weight(600)],
                  color: c.fg,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat.MMMMEEEEd(locale).format(_now),
                style: MmType.body.copyWith(color: c.fgSoft),
              ),
              const Spacer(),
              Icon(PhosphorRegular.musicNotes, size: 40, color: c.coralStrong),
              const SizedBox(height: 12),
              if (entry != null) ...[
                Text(
                  entry.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.title.copyWith(fontSize: 20, color: c.fg),
                ),
                if (entry.subtitle != null)
                  Text(
                    entry.subtitle!,
                    textAlign: TextAlign.center,
                    style: MmType.body.copyWith(color: c.muted),
                  ),
              ],
              const Spacer(),
              button(
                t.alarmStop,
                main: true,
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ctl.stop();
                  if (mounted) _leave();
                },
              ),
              const SizedBox(height: 12),
              button(
                t.alarmSnooze,
                main: false,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  await ctl.snooze();
                  final at = ref.read(alarmProvider).next;
                  if (!mounted) return;
                  if (at != null) {
                    messenger?.showSnackBar(
                      SnackBar(
                        content: Text(
                          t.alarmSnoozed(DateFormat.Hm(locale).format(at)),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  _leave();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
