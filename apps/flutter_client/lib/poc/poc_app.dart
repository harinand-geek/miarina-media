import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app/launch_args.dart';
import '../engine/engine_factory.dart';
import '../engine/media_engine.dart';

// Phase 1 proof of concept: exercises the MediaEngine contract only. The
// approved screens are built later from design/design_handoff_lecture_ecouter.

const _bg = Color(0xFF101820);
const _surface = Color(0xFF182530);
const _line = Color(0xFF243545);
const _fg = Color(0xFFF5F7FA);
const _muted = Color(0xFF94A3B8);
const _coral = Color(0xFFFF7A45);
const _warning = Color(0xFFE8B04B);
const _danger = Color(0xFFF07070);

const _mediaTypes = XTypeGroup(
  label: 'Médias',
  extensions: [
    'mp3',
    'flac',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wav',
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
  ],
);
const _subtitleTypes = XTypeGroup(
  label: 'Sous-titres',
  extensions: ['srt', 'vtt', 'ass', 'ssa'],
);
const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

class PocApp extends StatelessWidget {
  const PocApp({super.key, this.launchArgs = const LaunchArgs()});

  final LaunchArgs launchArgs;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Miarina Media',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _bg,
        colorScheme: const ColorScheme.dark(primary: _coral, surface: _surface),
        sliderTheme: const SliderThemeData(
          activeTrackColor: _coral,
          inactiveTrackColor: _line,
          thumbColor: _fg,
          trackHeight: 4,
        ),
      ),
      home: PocScreen(launchArgs: launchArgs),
    );
  }
}

class PocScreen extends StatefulWidget {
  const PocScreen({super.key, this.launchArgs = const LaunchArgs()});

  final LaunchArgs launchArgs;

  @override
  State<PocScreen> createState() => _PocScreenState();
}

class _PocScreenState extends State<PocScreen> {
  final MediaEngine? _engine = createPlatformEngine();
  StreamSubscription<PlaybackSnapshot>? _sub;
  PlaybackSnapshot _snap = const PlaybackSnapshot();
  double? _dragPosition;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _sub = _engine?.snapshots.listen((s) => setState(() => _snap = s));
    unawaited(_openLaunchFiles());
  }

  Future<void> _openLaunchFiles() async {
    final engine = _engine;
    final media = widget.launchArgs.media;
    if (engine == null || media == null) return;
    await engine.open(
      MediaSource.file(media, title: media.split(RegExp(r'[\\/]')).last),
    );
    final subtitle = widget.launchArgs.subtitle;
    if (subtitle == null) return;
    // The external track can only be attached once the file is loaded.
    if (engine.current.duration == Duration.zero) {
      await engine.snapshots
          .firstWhere(
            (s) =>
                s.duration > Duration.zero || s.status == PlaybackStatus.error,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => engine.current,
          );
    }
    await engine.loadExternalSubtitle(Uri.file(subtitle));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _engine?.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _openMedia() async {
    final file = await openFile(acceptedTypeGroups: const [_mediaTypes]);
    if (file == null) return;
    await _engine?.open(MediaSource.file(file.path, title: file.name));
    _focus.requestFocus();
  }

  Future<void> _openSubtitle() async {
    final file = await openFile(acceptedTypeGroups: const [_subtitleTypes]);
    if (file == null) return;
    await _engine?.loadExternalSubtitle(Uri.file(file.path));
  }

  void _togglePlay() {
    final e = _engine;
    if (e == null || _snap.source == null) return;
    _snap.isPlaying ? e.pause() : e.play();
  }

  void _seekBy(Duration delta) => _engine?.seek(_snap.position + delta);

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlay();
      case LogicalKeyboardKey.arrowLeft:
        _seekBy(const Duration(seconds: -5));
      case LogicalKeyboardKey.arrowRight:
        _seekBy(const Duration(seconds: 5));
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: engine == null ? _unsupported() : _player(engine),
          ),
        ),
      ),
    );
  }

  Widget _unsupported() => const Center(
    child: Text(
      'Aucun moteur de lecture pour cette plateforme dans cette version de test.',
      style: TextStyle(color: _muted, fontSize: 15),
      textAlign: TextAlign.center,
    ),
  );

  Widget _player(MediaEngine engine) {
    final caps = engine.capabilities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'Miarina Media',
              style: TextStyle(
                color: _fg,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'preuve de concept · lecture',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted, fontSize: 13),
              ),
            ),
            FilledButton(onPressed: _openMedia, child: const Text('Ouvrir…')),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: const Color(0xFF070B0F),
              child: _snap.hasVideo
                  ? GestureDetector(
                      onTap: _togglePlay,
                      child: engine.buildVideoView(),
                    )
                  : Center(
                      child: Text(
                        _snap.source?.title ??
                            'Ouvrez un fichier audio ou vidéo',
                        style: const TextStyle(color: _muted, fontSize: 16),
                      ),
                    ),
            ),
          ),
        ),
        if (_snap.error != null) _errorBanner(_snap.error!),
        const SizedBox(height: 12),
        _seekRow(engine),
        const SizedBox(height: 8),
        _transportRow(engine, caps),
        const SizedBox(height: 10),
        _tracksRow(engine, caps),
        const SizedBox(height: 10),
        Text(
          'état ${_snap.status.name}${_snap.buffering ? ' · mise en mémoire tampon' : ''}'
          '${_snap.hasVideo ? ' · ${_snap.videoSize!.width.toInt()}×${_snap.videoSize!.height.toInt()}' : ''}'
          ' · Espace lecture/pause, ←/→ ±5 s',
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _errorBanner(PlaybackError error) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF2B2616),
      border: Border.all(color: const Color(0xFF4A3F1F)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      '${error.recoverable ? 'Avertissement' : 'Lecture impossible'} : ${error.message}',
      style: TextStyle(
        color: error.recoverable ? _warning : _danger,
        fontSize: 13,
      ),
    ),
  );

  Widget _seekRow(MediaEngine engine) {
    final total = _snap.duration.inMilliseconds.toDouble();
    final value = (_dragPosition ?? _snap.position.inMilliseconds.toDouble())
        .clamp(0.0, total > 0 ? total : 1.0);
    return Row(
      children: [
        _time(Duration(milliseconds: value.round())),
        Expanded(
          child: Slider(
            value: value,
            max: total > 0 ? total : 1,
            onChanged: total > 0
                ? (v) => setState(() => _dragPosition = v)
                : null,
            onChangeEnd: (v) {
              engine.seek(Duration(milliseconds: v.round()));
              setState(() => _dragPosition = null);
            },
          ),
        ),
        _time(_snap.duration),
      ],
    );
  }

  Widget _time(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Text(
      h > 0 ? '$h:$m:$s' : '$m:$s',
      style: const TextStyle(
        color: _muted,
        fontSize: 12.5,
        fontFeatures: [FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _transportRow(MediaEngine engine, EngineCapabilities caps) {
    final hasMedia = _snap.source != null;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          onPressed: hasMedia
              ? () => _seekBy(const Duration(seconds: -10))
              : null,
          child: const Text('−10 s'),
        ),
        FilledButton(
          onPressed: hasMedia ? _togglePlay : null,
          child: Text(_snap.isPlaying ? 'Pause' : 'Lire'),
        ),
        OutlinedButton(
          onPressed: hasMedia
              ? () => _seekBy(const Duration(seconds: 10))
              : null,
          child: const Text('+10 s'),
        ),
        OutlinedButton(
          onPressed: hasMedia ? engine.stop : null,
          child: const Text('Arrêter'),
        ),
        if (caps.speed)
          OutlinedButton(
            onPressed: hasMedia
                ? () {
                    final i = _speeds.indexOf(_snap.speed);
                    engine.setSpeed(_speeds[(i + 1) % _speeds.length]);
                  }
                : null,
            child: Text('Vitesse ${_snap.speed}×'),
          ),
        OutlinedButton(
          onPressed: () => engine.setRepeatMode(
            RepeatSetting.values[(_snap.repeat.index + 1) %
                RepeatSetting.values.length],
          ),
          child: Text(switch (_snap.repeat) {
            RepeatSetting.off => 'Répéter : non',
            RepeatSetting.one => 'Répéter : ce titre',
            RepeatSetting.all => 'Répéter : tout',
          }),
        ),
        const SizedBox(width: 12),
        const Text('Volume', style: TextStyle(color: _muted, fontSize: 13)),
        SizedBox(
          width: 140,
          child: Slider(value: _snap.volume, onChanged: engine.setVolume),
        ),
      ],
    );
  }

  Widget _tracksRow(MediaEngine engine, EngineCapabilities caps) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (caps.audioTrackSelection && _snap.audioTracks.length > 1)
          DropdownButton<String>(
            value: _snap.selectedAudio,
            hint: const Text('Piste audio'),
            items: [
              for (final t in _snap.audioTracks)
                DropdownMenuItem(
                  value: t.id,
                  child: Text('Audio : ${t.label}'),
                ),
            ],
            onChanged: (id) => id == null ? null : engine.selectAudioTrack(id),
          ),
        if (caps.embeddedSubtitles && _snap.subtitleTracks.isNotEmpty)
          DropdownButton<String?>(
            value: _snap.subtitlesEnabled ? _snap.selectedSubtitle : null,
            hint: const Text('Sous-titres'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sous-titres : aucun'),
              ),
              for (final t in _snap.subtitleTracks)
                DropdownMenuItem<String?>(
                  value: t.id,
                  child: Text('Sous-titres : ${t.label}'),
                ),
            ],
            onChanged: engine.selectSubtitleTrack,
          ),
        if (caps.externalSubtitles && _snap.hasVideo)
          OutlinedButton(
            onPressed: _openSubtitle,
            child: const Text('Charger des sous-titres…'),
          ),
      ],
    );
  }
}
