part of 'get_screens.dart';

// Obtenir › Plusieurs liens. No mockup beyond the home tile: composed from
// the approved analysis and Playlist screens (link card, Vidéo / Audio seul
// tabs, quality chips, rows, bottom action bar). Each link goes through the
// ordinary analysis: a direct file stays a direct file, a page takes the
// quality chosen for all, and the result is said per link.

/// Links read at most from one paste.
const maxBatchLinks = 50;

/// Analyses run at once (each starts the extractor).
const _batchAtOnce = 2;

enum _LinkState { invalid, ready, analyzing, added, failed }

class _BatchLink {
  _BatchLink(this.url, {this.host, this.issue});

  final String url;
  final String? host;

  /// Link check code when the link itself is refused.
  final String? issue;

  _LinkState state = _LinkState.ready;

  /// Why it failed (shown), and the engine's own words (tooltip).
  String? reason;
  String? detail;
  String? title;
}

/// The links of a pasted text: one per line (or separated by spaces),
/// duplicates dropped, at most [maxBatchLinks].
List<String> splitLinks(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final part in text.split(RegExp(r'\s+'))) {
    final v = part.trim();
    if (v.isEmpty || !seen.add(v)) continue;
    out.add(v);
    if (out.length == maxBatchLinks) break;
  }
  return out;
}

class GetBatchScreen extends ConsumerStatefulWidget {
  const GetBatchScreen({super.key});

  @override
  ConsumerState<GetBatchScreen> createState() => _GetBatchScreenState();
}

class _GetBatchScreenState extends ConsumerState<GetBatchScreen> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  var _links = <_BatchLink>[];
  bool _truncated = false;
  String _tab = 'video';
  final _quality = <String, String>{};
  bool _running = false;
  int _check = 0;

  @override
  void initState() {
    super.initState();
    _field.addListener(_changed);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  PresetOffers? get _presets {
    try {
      return ref.read(getApiProvider).presetOffers();
    } catch (_) {
      return null; // Obtenir not started (no core): nothing to offer.
    }
  }

  void _changed() {
    if (_running) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _parse);
  }

  /// Checks each link as typed; the results replace the list.
  Future<void> _parse() async {
    final check = ++_check;
    final text = _field.text;
    final urls = splitLinks(text);
    final api = ref.read(getApiProvider);
    final links = <_BatchLink>[];
    for (final u in urls) {
      final r = await api.checkLink(u);
      links.add(
        r.url != null
              ? _BatchLink(r.url!, host: r.host)
              : _BatchLink(u, issue: r.error ?? 'malformed')
          ..state = r.url != null ? _LinkState.ready : _LinkState.invalid,
      );
    }
    if (!mounted || check != _check) return;
    setState(() {
      _links = links;
      _truncated =
          text.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toSet().length >
          maxBatchLinks;
    });
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    final current = _field.text.trimRight();
    _field.text = current.isEmpty ? text : '$current\n$text';
    _focus.requestFocus();
  }

  FormatOffer? _format(PresetOffers presets) {
    final formats = _tab == 'audio' ? presets.audio : presets.video;
    for (final f in formats) {
      if (f.id == _quality[_tab]) return f;
    }
    return defaultFormat(formats);
  }

  Iterable<_BatchLink> get _todo => _links.where(
    (l) => l.state == _LinkState.ready || l.state == _LinkState.failed,
  );

  Future<void> _start() async {
    final presets = _presets;
    final preset = presets == null ? null : _format(presets);
    if (_running || preset == null) return;
    final queue = _todo.toList();
    if (queue.isEmpty) return;
    setState(() {
      _running = true;
      for (final l in queue) {
        l.state = _LinkState.ready;
        l.reason = null;
      }
    });
    var next = 0;
    Future<void> worker() async {
      while (next < queue.length && mounted) {
        await _one(queue[next++], preset);
      }
    }

    await Future.wait([for (var i = 0; i < _batchAtOnce; i++) worker()]);
    if (!mounted) return;
    setState(() => _running = false);
    final t = L10n.of(context);
    final added = _links.where((l) => l.state == _LinkState.added).length;
    final failed = _links.where((l) => l.state == _LinkState.failed).length;
    _toast(
      context,
      t.batchDone(added, failed),
      action: added == 0
          ? null
          : SnackBarAction(
              label: t.getView,
              onPressed: () => context.go(Routes.getDownloads),
            ),
    );
  }

  /// One link: its own analysis, then the download it allows.
  Future<void> _one(_BatchLink link, FormatOffer preset) async {
    final t = L10n.of(context);
    final audio = _tab == 'audio';
    setState(() => link.state = _LinkState.analyzing);
    void fail(String reason, [String? detail]) {
      if (!mounted) return;
      setState(() {
        link.state = _LinkState.failed;
        link.reason = reason;
        link.detail = detail;
      });
    }

    try {
      final a = await ref.read(getApiProvider).analyze(link.url);
      if (!mounted) return;
      switch (a.status) {
        case AnalysisStatus.playlist:
          return fail(t.batchIsPlaylist);
        case AnalysisStatus.needsTools:
          return fail(t.batchNeedsTools);
        case AnalysisStatus.noMedia:
          return fail(switch (a.code) {
            'network' => t.getWhyNetwork,
            'platform' => t.getWhyPlatform,
            final c when c.startsWith('http:') => t.getWhyHttp(c.substring(5)),
            _ => t.getNoMediaTitle,
          }, a.detail);
        case AnalysisStatus.ready:
          break;
      }
      final info = a.info!;
      final StartRequest request;
      if (info.engine == 'http') {
        // A direct file is downloaded as it is.
        final own = defaultFormat(audio ? info.audio : info.video);
        if (own == null) {
          return fail(audio ? t.batchNoAudio : t.batchNoVideo);
        }
        request = StartRequest(
          url: info.url,
          title: info.title,
          isAudio: info.video.isEmpty,
          engine: info.engine,
          formatId: own.id == 'original' ? null : own.id,
          formatLabel: t.getOriginalFile(own.quality),
          extension_: own.extension_,
          startNow: false,
          thumbnail: info.thumbnail,
        );
      } else {
        request = StartRequest(
          url: info.url,
          title: '${info.title} (${shortQuality(preset)})',
          isAudio: audio,
          engine: info.engine,
          formatId: preset.id,
          formatLabel: preset.quality,
          extension_: preset.extension_,
          startNow: false,
          thumbnail: info.thumbnail,
        );
      }
      await ref.read(downloadsProvider.notifier).start(request);
      if (!mounted) return;
      setState(() {
        link.state = _LinkState.added;
        link.title = info.title;
      });
    } catch (e) {
      debugPrint('batch link refused: $e');
      fail('$e'.contains('queue is full') ? t.plQueueFull : t.batchFailed);
    }
  }

  void _retry(_BatchLink link) {
    if (_running) return;
    setState(() => link.state = _LinkState.ready);
    _start();
  }

  String _issueText(L10n t, String code) => switch (code) {
    'too_long' => t.getLinkTooLong,
    'unsupported_scheme' => t.getLinkScheme,
    'contains_credentials' => t.getLinkCredentials,
    _ => t.getLinkMalformed,
  };

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final compact = compactGet(context);
    final presets = _presets;
    final format = presets == null ? null : _format(presets);
    final formats = presets == null
        ? const <FormatOffer>[]
        : (_tab == 'audio' ? presets.audio : presets.video);
    final valid = _links.where((l) => l.state != _LinkState.invalid).length;
    final todo = _todo.length;
    final canStart = !_running && todo > 0 && format != null;
    final dir = ref.watch(getSettingsProvider).value?.downloadDir ?? '';
    final startLabel = _running ? t.batchRunning : t.batchStart(todo);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.getQBatch,
          style: compact
              ? MmType.title.copyWith(fontSize: 18, color: c.fg)
              : MmType.display.copyWith(fontSize: 22, color: c.fg),
        ),
        const SizedBox(height: 6),
        Text(
          t.batchLead(maxBatchLinks),
          style: MmType.bodySm.copyWith(color: c.muted),
        ),
      ],
    );

    final input = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('batch-links'),
            controller: _field,
            focusNode: _focus,
            enabled: !_running,
            minLines: compact ? 4 : 5,
            maxLines: 10,
            keyboardType: TextInputType.multiline,
            style: MmType.monoStyle(size: 12.5, color: c.fg),
            decoration: InputDecoration(
              isDense: true,
              hintText: t.batchHint,
              hintStyle: MmType.monoStyle(size: 12.5, color: c.faint),
              filled: true,
              fillColor: c.bg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MmRadius.sm),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MmRadius.sm),
                borderSide: BorderSide(color: c.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MmRadius.sm),
                borderSide: BorderSide(color: c.accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _Button(
                t.getPaste,
                _running ? null : _paste,
                icon: PhosphorRegular.clipboardText,
                height: 34,
              ),
              const SizedBox(width: 8),
              _Button(
                t.batchClear,
                _running || _field.text.isEmpty ? null : _field.clear,
                height: 34,
              ),
              const Spacer(),
              if (_truncated)
                Flexible(
                  child: Text(
                    t.batchTruncated(maxBatchLinks),
                    textAlign: TextAlign.right,
                    style: MmType.caption.copyWith(color: c.warning),
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    final tabs = [
      ('video', PhosphorRegular.filmStrip, t.getFmtVideo),
      ('audio', PhosphorRegular.musicNote, t.getQAudio),
    ];
    final quality = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              for (final (id, icon, label) in tabs) ...[
                Pressable(
                  onTap: _running ? null : () => setState(() => _tab = id),
                  semanticLabel: label,
                  selected: _tab == id,
                  child: Container(
                    height: compact ? 44 : 40,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _tab == id ? c.accent : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 18,
                          color: _tab == id ? c.fg : c.muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: MmType.labelStrong.copyWith(
                            fontSize: 13.5,
                            color: _tab == id ? c.fg : c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          t.batchQuality,
          style: MmType.labelStrong.copyWith(fontSize: 13, color: c.fgSoft),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in formats)
              _QualityChip(
                label: f.quality,
                tag: f.tag == 'Recommended' ? t.getTagRecommended : null,
                selected: f.id == format?.id,
                onTap: () {
                  if (!_running) setState(() => _quality[_tab] = f.id);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          t.batchQualityNote,
          style: MmType.caption.copyWith(color: c.muted),
        ),
        if (presets?.needsFfmpeg ?? false)
          Text(
            t.getNeedsFfmpeg,
            style: MmType.caption.copyWith(color: c.warning),
          ),
      ],
    );

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: t.batchLinks,
                style: MmType.labelStrong.copyWith(
                  fontSize: 13,
                  color: c.fgSoft,
                ),
              ),
              TextSpan(
                text: '  ${t.batchValid(valid, _links.length)}',
                style: MmType.monoStyle(size: 12, color: c.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(MmRadius.lg),
            border: Border.all(color: c.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: _links.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    t.batchEmpty,
                    style: MmType.bodySm.copyWith(color: c.muted),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, l) in _links.indexed)
                      _LinkRow(
                        index: i + 1,
                        link: l,
                        status: switch (l.state) {
                          _LinkState.invalid => _issueText(t, l.issue!),
                          _LinkState.ready => '',
                          _LinkState.analyzing => t.batchAnalyzing,
                          _LinkState.added => t.batchAdded,
                          _LinkState.failed => l.reason ?? t.batchFailed,
                        },
                        onRetry: l.state == _LinkState.failed && !_running
                            ? () => _retry(l)
                            : null,
                        retryLabel: t.getTryAgain,
                      ),
                  ],
                ),
        ),
      ],
    );

    final body = <Widget>[
      intro,
      const SizedBox(height: 18),
      input,
      SizedBox(height: compact ? 18 : 24),
      quality,
      SizedBox(height: compact ? 18 : 24),
      list,
    ];

    if (compact) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Pressable(
                    onTap: () => context.go(Routes.get),
                    semanticLabel: t.getBack,
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorRegular.arrowLeft,
                            size: 20,
                            color: c.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            t.getBack,
                            style: MmType.labelStrong.copyWith(
                              fontSize: 14,
                              color: c.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...body,
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: c.sidebar,
              border: Border(top: BorderSide(color: c.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Pill(
                    startLabel,
                    canStart ? _start : null,
                    primary: true,
                    icon: PhosphorRegular.downloadSimple,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: _Scroll(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: body,
              ),
            ),
          ),
        ),
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 48),
          decoration: BoxDecoration(
            color: c.sidebar,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              Icon(PhosphorRegular.folder, size: 20, color: c.muted),
              const SizedBox(width: 12),
              Flexible(
                child: Tooltip(
                  message: dir,
                  child: Text(
                    dir,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MmType.monoStyle(size: 12.5, color: c.muted),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: () => pickDownloadDir(context, ref),
                semanticLabel: t.getChange,
                child: Text(
                  t.getChange,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13,
                    color: c.accentStrong,
                  ),
                ),
              ),
              const Spacer(),
              _Button(
                startLabel,
                canStart ? _start : null,
                primary: true,
                icon: PhosphorRegular.downloadSimple,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.index,
    required this.link,
    required this.status,
    required this.onRetry,
    required this.retryLabel,
  });

  final int index;
  final _BatchLink link;
  final String status;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final compact = compactGet(context);
    final (icon, color) = switch (link.state) {
      _LinkState.invalid => (PhosphorRegular.warningCircle, c.warning),
      _LinkState.ready => (PhosphorRegular.link, c.faint),
      _LinkState.analyzing => (PhosphorRegular.hourglassSimple, c.accent),
      _LinkState.added => (PhosphorRegular.checkCircle, c.accent),
      _LinkState.failed => (PhosphorRegular.minusCircle, c.danger),
    };
    final statusText = Text(
      status,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MmType.caption.copyWith(
        color: switch (link.state) {
          _LinkState.failed => c.danger,
          _LinkState.invalid => c.warning,
          _LinkState.added => c.chipText,
          _ => c.muted,
        },
      ),
    );
    return Semantics(
      label: '${link.url}, $status',
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 56 : 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            SizedBox(
              width: 26,
              child: Text(
                '$index',
                style: MmType.monoStyle(size: 12, color: c.muted),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    link.title ?? link.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: link.title != null
                        ? MmType.bodySm.copyWith(color: c.fg)
                        : MmType.monoStyle(size: 12.5, color: c.fg),
                  ),
                  if (compact && status.isNotEmpty) statusText,
                ],
              ),
            ),
            if (!compact && status.isNotEmpty) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Tooltip(message: link.detail ?? '', child: statusText),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(width: 10),
              _Button(retryLabel, onRetry, height: 30),
            ],
          ],
        ),
      ),
    );
  }
}
