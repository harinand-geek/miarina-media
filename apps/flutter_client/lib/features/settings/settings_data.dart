import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../engine/media_engine.dart';
import '../playback/playback.dart';
import '../playback/playback_memory.dart';
import '../playback/settings_store.dart';

enum ThemePref { dark, light, system }

enum Density { comfortable, compact }

/// W-S1 Appearance. The theme and the language use the 0.1.x keys
/// (`mm:theme`, `mm:lang`); the rest is new and lives in the settings
/// table (`appearance`).
@immutable
class AppearancePrefs {
  const AppearancePrefs({
    this.theme = ThemePref.dark,
    this.language,
    this.textScale = 1,
    this.density = Density.comfortable,
    this.reduceMotion = false,
    this.reduceTransparency = false,
    this.coverBackdrop = true,
  });

  final ThemePref theme;

  /// 'fr' or 'en'; null follows the system.
  final String? language;

  /// 0.9 to 1.3.
  final double textScale;
  final Density density;

  /// On: no movement, short fades. Off: follows the Windows setting.
  final bool reduceMotion;
  final bool reduceTransparency;

  /// Blurred cover behind Now playing.
  final bool coverBackdrop;

  static const textScales = [0.9, 1.0, 1.1, 1.2, 1.3];

  AppearancePrefs copyWith({
    ThemePref? theme,
    Object? language = _keep,
    double? textScale,
    Density? density,
    bool? reduceMotion,
    bool? reduceTransparency,
    bool? coverBackdrop,
  }) => AppearancePrefs(
    theme: theme ?? this.theme,
    language: identical(language, _keep) ? this.language : language as String?,
    textScale: textScale ?? this.textScale,
    density: density ?? this.density,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    reduceTransparency: reduceTransparency ?? this.reduceTransparency,
    coverBackdrop: coverBackdrop ?? this.coverBackdrop,
  );

  Map<String, Object> toJson() => {
    'textScale': textScale,
    'density': density.name,
    'reduceMotion': reduceMotion,
    'reduceTransparency': reduceTransparency,
    'coverBackdrop': coverBackdrop,
  };
}

const _keep = Object();

/// W-S2 Playback. Resume uses the 0.1.x key (`mm:resume`); the engine
/// settings live in the settings table (`playback`).
@immutable
class PlaybackPrefs {
  const PlaybackPrefs({
    this.resume = true,
    this.engine = const EnginePreferences(subtitleLanguage: 'fr'),
  });

  final bool resume;
  final EnginePreferences engine;

  PlaybackPrefs copyWith({bool? resume, EnginePreferences? engine}) =>
      PlaybackPrefs(
        resume: resume ?? this.resume,
        engine: engine ?? this.engine,
      );

  Map<String, Object?> toJson() => {
    'subtitleLanguage': engine.subtitleLanguage,
    'sidecarSubtitles': engine.sidecarSubtitles,
    'exclusiveAudio': engine.exclusiveAudio,
    'audioOutput': engine.audioOutput,
  };
}

EnginePreferences withEngine(
  EnginePreferences e, {
  Object? subtitleLanguage = _keep,
  bool? sidecarSubtitles,
  bool? exclusiveAudio,
  String? audioOutput,
}) => EnginePreferences(
  subtitleLanguage: identical(subtitleLanguage, _keep)
      ? e.subtitleLanguage
      : subtitleLanguage as String?,
  sidecarSubtitles: sidecarSubtitles ?? e.sidecarSubtitles,
  exclusiveAudio: exclusiveAudio ?? e.exclusiveAudio,
  audioOutput: audioOutput ?? e.audioOutput,
);

T _pick<T>(Object? map, String key, T fallback) {
  if (map is! Map) return fallback;
  final v = map[key];
  return v is T ? v : fallback;
}

final appearanceProvider =
    AsyncNotifierProvider<AppearanceController, AppearancePrefs>(
      AppearanceController.new,
    );

class AppearanceController extends AsyncNotifier<AppearancePrefs> {
  @override
  Future<AppearancePrefs> build() async {
    final store = ref.read(playbackStoreProvider);
    final theme = await store.read('mm:theme');
    final lang = await store.read('mm:lang');
    final raw = await ref.read(settingsStoreProvider).read('appearance');
    final scale = _pick<num>(raw, 'textScale', 1).toDouble();
    return AppearancePrefs(
      theme: ThemePref.values.asNameMap()[theme] ?? ThemePref.dark,
      language: lang == 'fr' || lang == 'en' ? lang : null,
      textScale: scale.clamp(0.9, 1.3),
      density:
          Density.values.asNameMap()[_pick<String>(raw, 'density', '')] ??
          Density.comfortable,
      reduceMotion: _pick(raw, 'reduceMotion', false),
      reduceTransparency: _pick(raw, 'reduceTransparency', false),
      coverBackdrop: _pick(raw, 'coverBackdrop', true),
    );
  }

  Future<void> save(AppearancePrefs next) async {
    final before = await future;
    state = AsyncData(next);
    final store = ref.read(playbackStoreProvider);
    if (next.theme != before.theme) {
      await store.write({'mm:theme': next.theme.name});
    }
    if (next.language != before.language) {
      await store.write({'mm:lang': next.language});
    }
    await ref.read(settingsStoreProvider).write('appearance', next.toJson());
  }
}

final playbackPrefsProvider =
    AsyncNotifierProvider<PlaybackPrefsController, PlaybackPrefs>(
      PlaybackPrefsController.new,
    );

class PlaybackPrefsController extends AsyncNotifier<PlaybackPrefs> {
  @override
  Future<PlaybackPrefs> build() async {
    final resume = await ref.read(playbackStoreProvider).read(resumeKey);
    final raw = await ref.read(settingsStoreProvider).read('playback');
    final lang = raw is Map && raw.containsKey('subtitleLanguage')
        ? raw['subtitleLanguage'] as String?
        : 'fr';
    return PlaybackPrefs(
      resume: resume != '0',
      engine: EnginePreferences(
        subtitleLanguage: lang,
        sidecarSubtitles: _pick(raw, 'sidecarSubtitles', true),
        exclusiveAudio: _pick(raw, 'exclusiveAudio', false),
        audioOutput: _pick(raw, 'audioOutput', 'auto'),
      ),
    );
  }

  Future<void> save(PlaybackPrefs next) async {
    final before = await future;
    state = AsyncData(next);
    if (next.resume != before.resume) {
      // Same value as 0.1.x: '0' turns resuming off, nothing = on.
      await ref.read(playbackStoreProvider).write({
        resumeKey: next.resume ? null : '0',
      });
    }
    await ref.read(settingsStoreProvider).write('playback', next.toJson());
  }
}

/// Keeps the engine in line with the playback settings. Watched by the app
/// root.
final enginePreferencesProvider = Provider<void>((ref) {
  ref.listen(playbackPrefsProvider, (_, next) {
    final prefs = next.value;
    final engine = ref.read(mediaEngineProvider);
    if (prefs != null && engine != null) {
      engine.applyPreferences(prefs.engine);
    }
  }, fireImmediately: true);
});

final audioOutputsProvider = FutureProvider<List<AudioOutput>>((ref) async {
  final engine = ref.watch(mediaEngineProvider);
  if (engine == null || !engine.capabilities.audioOutputs) return const [];
  return engine.audioOutputs();
});

/// Subtitle languages offered, with their own names.
const subtitleLanguages = {
  'fr': 'Français',
  'en': 'English',
  'mg': 'Malagasy',
  'es': 'Español',
  'de': 'Deutsch',
  'it': 'Italiano',
  'pt': 'Português',
};
