part of 'get_screens.dart';

// Obtenir › Playlist (CDC DL-07). No mockup: composed from the approved
// analysis screen (header, Vidéo / Audio seul tabs, bottom action bar) and
// the design system's chips and rows; see docs/flutter-implementation-map.md.

class _PlaylistResult extends ConsumerStatefulWidget {
  const _PlaylistResult({
    required this.list,
    required this.tab,
    this.onStarted,
  });

  final WebPlaylist list;
  final String tab;
  final VoidCallback? onStarted;

  @override
  ConsumerState<_PlaylistResult> createState() => _PlaylistResultState();
}

class _PlaylistResultState extends ConsumerState<_PlaylistResult> {
  late String _tab = widget.tab == 'audio' ? 'audio' : 'video';
  final _quality = <String, String>{};
  late final Set<int> _chosen = {
    for (final e in widget.list.entries)
      if (e.url != null) e.index,
  };
  bool _ownFolder = true;
  bool _starting = false;

  List<FormatOffer> get _formats =>
      _tab == 'audio' ? widget.list.audio : widget.list.video;

  FormatOffer? get _format {
    final chosen = _quality[_tab];
    for (final f in _formats) {
      if (f.id == chosen) return f;
    }
    return preferredFormat(
      _formats,
      ref.read(getSettingsProvider).value,
      audio: _tab == 'audio',
    );
  }

  List<WebPlaylistEntry> get _available =>
      widget.list.entries.where((e) => e.url != null).toList();

  String _entryTitle(L10n t, WebPlaylistEntry e) =>
      e.title.isEmpty ? t.plItemFallback(e.index) : e.title;

  Future<void> _start() async {
    final format = _format;
    if (_starting || format == null || _chosen.isEmpty) return;
    final t = L10n.of(context);
    final list = widget.list;
    setState(() => _starting = true);
    try {
      final count = await ref
          .read(getApiProvider)
          .startPlaylist(
            WebPlaylistStart(
              playlistTitle: list.title,
              isAudio: _tab == 'audio',
              formatId: format.id,
              formatLabel: format.quality,
              extension_: format.extension_,
              ownFolder: _ownFolder,
              items: [
                for (final e in list.entries)
                  if (e.url != null && _chosen.contains(e.index))
                    WebPlaylistPick(
                      index: e.index,
                      url: e.url!,
                      title: _entryTitle(t, e),
                      thumbnailUrl: e.thumbnailUrl,
                    ),
              ],
            ),
          );
      if (!mounted) return;
      _toast(context, t.plQueued(count));
      if (widget.onStarted != null) {
        widget.onStarted!();
      } else {
        context.go(Routes.getDownloads);
      }
    } catch (e) {
      debugPrint('playlist refused: $e');
      if (mounted) {
        _toast(
          context,
          '$e'.contains('queue_full') ? t.plQueueFull : t.plFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _toggle(int index) => setState(
    () => _chosen.contains(index) ? _chosen.remove(index) : _chosen.add(index),
  );

  void _all(bool on) => setState(() {
    _chosen.clear();
    if (on) _chosen.addAll(_available.map((e) => e.index));
  });

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final compact = compactGet(context);
    final list = widget.list;
    final format = _format;
    final available = _available.length;
    final canStart = format != null && _chosen.isNotEmpty && !_starting;
    final dir = ref.watch(getSettingsProvider).value?.downloadDir ?? '';
    final source = [
      list.host,
      list.publisher == list.host ? null : list.publisher,
    ].whereType<String>().join(' · ');
    final shown = list.entries.length;
    final total = list.count?.toInt();
    final countLabel = list.truncated
        ? (total != null && total > shown
              ? t.plTruncated(shown, total)
              : t.plTruncatedUnknown(shown))
        : t.plCount(total ?? shown);
    final downloadLabel = _starting
        ? t.plPreparing
        : t.plDownload(_chosen.length);

    final header = Row(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        _Thumb(
          path: list.thumbnail,
          audio: _tab == 'audio',
          width: compact ? 96 : 224,
        ),
        SizedBox(width: compact ? 12 : 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                list.title,
                maxLines: compact ? 3 : 2,
                overflow: TextOverflow.ellipsis,
                style: compact
                    ? MmType.title.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.fg,
                      )
                    : MmType.display.copyWith(fontSize: 22, color: c.fg),
              ),
              const SizedBox(height: 6),
              Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.monoStyle(
                  size: compact ? 12 : 12.5,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                  border: Border.all(color: c.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorRegular.playlist, size: 15, color: c.muted),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        countLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.captionStrong.copyWith(
                          fontSize: 12,
                          color: c.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final tabs = [
      ('video', PhosphorRegular.filmStrip, t.getFmtVideo),
      ('audio', PhosphorRegular.musicNote, t.getQAudio),
    ];
    final tabBar = Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          for (final (id, icon, label) in tabs) ...[
            Pressable(
              onTap: () => setState(() => _tab = id),
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
                    Icon(icon, size: 18, color: _tab == id ? c.fg : c.muted),
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
    );

    final qualities = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.plQuality,
          style: MmType.labelStrong.copyWith(fontSize: 13, color: c.fgSoft),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _formats)
              _QualityChip(
                label: f.quality,
                tag: f.tag == 'Recommended' ? t.getTagRecommended : null,
                selected: f.id == format?.id,
                onTap: () => setState(() => _quality[_tab] = f.id),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(t.plQualityNote, style: MmType.caption.copyWith(color: c.muted)),
        if (list.needsFfmpeg)
          Text(
            t.getNeedsFfmpeg,
            style: MmType.caption.copyWith(color: c.warning),
          ),
      ],
    );

    final allOn = _chosen.length == available && available > 0;
    final itemsHead = Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: t.plItems,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13,
                    color: c.fgSoft,
                  ),
                ),
                TextSpan(
                  text: '  ${t.plSelected(_chosen.length, available)}',
                  style: MmType.monoStyle(size: 12, color: c.muted),
                ),
              ],
            ),
          ),
        ),
        Pressable(
          onTap: () => _all(!allOn),
          semanticLabel: allOn ? t.plSelectNone : t.plSelectAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              allOn ? t.plSelectNone : t.plSelectAll,
              style: MmType.labelStrong.copyWith(
                fontSize: 13,
                color: c.accentStrong,
              ),
            ),
          ),
        ),
      ],
    );

    final rows = [
      for (final e in list.entries)
        _EntryRow(
          index: e.index,
          title: _entryTitle(t, e),
          duration: e.durationSecs == null
              ? null
              : etaLabel(e.durationSecs!.round()),
          available: e.url != null,
          unavailableLabel: t.plUnavailable,
          chosen: _chosen.contains(e.index),
          onTap: e.url == null ? null : () => _toggle(e.index),
        ),
    ];

    final folderToggle = Pressable(
      onTap: () => setState(() => _ownFolder = !_ownFolder),
      semanticLabel: t.plOwnFolder(list.title),
      selected: _ownFolder,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CheckBox(on: _ownFolder),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              t.plOwnFolder(list.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: MmType.bodySm.copyWith(color: c.fgSoft),
            ),
          ),
        ],
      ),
    );

    final body = [
      header,
      SizedBox(height: compact ? 14 : 20),
      tabBar,
      SizedBox(height: compact ? 14 : 20),
      qualities,
      SizedBox(height: compact ? 18 : 24),
      itemsHead,
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MmRadius.lg),
          border: Border.all(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    ];

    if (compact) {
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                if (widget.onStarted == null) ...[
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
                ],
                ...body,
                const SizedBox(height: 14),
                folderToggle,
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
                    downloadLabel,
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
            back: widget.onStarted == null,
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
              const SizedBox(width: 24),
              Flexible(child: folderToggle),
              const Spacer(),
              _Button(
                downloadLabel,
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

/// A quality for every entry: the format rows' colours, as a chip.
class _QualityChip extends StatelessWidget {
  const _QualityChip({
    required this.label,
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String? tag;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: tag == null ? label : '$label, $tag',
      selected: selected,
      borderRadius: BorderRadius.circular(MmRadius.pill),
      child: Container(
        height: compactGet(context) ? 40 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? c.accentSubtle : c.surface,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: selected ? c.accent : c.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: MmType.labelStrong.copyWith(
                fontSize: 13,
                color: selected ? c.fg : c.fgSoft,
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: 8),
              Text(
                tag!,
                style: MmType.captionStrong.copyWith(
                  fontSize: 10.5,
                  color: c.chipText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The format rows' selection mark, square for a multiple choice.
class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.on, this.enabled = true});

  final bool on;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: on ? c.accent : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: on
            ? null
            : Border.all(color: enabled ? c.faint : c.line, width: 2),
      ),
      alignment: Alignment.center,
      child: on
          ? const Icon(
              PhosphorRegular.check,
              size: 13,
              color: Color(0xFF062320),
            )
          : null,
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.index,
    required this.title,
    required this.duration,
    required this.available,
    required this.unavailableLabel,
    required this.chosen,
    required this.onTap,
  });

  final int index;
  final String title;
  final String? duration;
  final bool available;
  final String unavailableLabel;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final compact = compactGet(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: available ? title : '$title, $unavailableLabel',
      selected: chosen,
      hoverColor: c.surface2,
      child: Opacity(
        opacity: available ? 1 : 0.55,
        child: Container(
          height: compact ? 52 : 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Row(
            children: [
              _CheckBox(on: chosen && available, enabled: available),
              const SizedBox(width: 14),
              SizedBox(
                width: 30,
                child: Text(
                  '$index',
                  style: MmType.monoStyle(size: 12, color: c.muted),
                ),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.bodySm.copyWith(
                    color: available ? c.fg : c.muted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!available)
                Text(
                  unavailableLabel,
                  style: MmType.caption.copyWith(color: c.warning),
                )
              else if (duration != null)
                Text(
                  duration!,
                  style: MmType.monoStyle(size: 12, color: c.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
