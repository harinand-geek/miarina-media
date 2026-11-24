part of 'browser_screen.dart';

// Obtenir › Navigateur on a phone (design_handoff_android_v2, screen 02):
// address bar with the media chip, tab counter and menu; the page (a native
// WebView in a platform view, so Flutter draws over it); the floating
// "Télécharger · N" button once media is found (tap: formats sheet, hold:
// default format); bottom bar back, forward, home, favorites, back to the
// app. The tab bar and mini player of the app are hidden here.

const _fabInk = Color(0xFF062320);

/// Starts the download of `f` from `info` (format sheet, floating button).
Future<void> _startDownload(
  WidgetRef ref,
  L10n t,
  MediaInfo info,
  FormatOffer f, {
  required bool now,
}) => ref
    .read(downloadsProvider.notifier)
    .start(
      StartRequest(
        url: info.url,
        title: downloadTitle(info, f),
        isAudio: info.video.isEmpty || !info.video.contains(f),
        engine: info.engine,
        formatId: f.id == 'original' ? null : f.id,
        formatLabel: f.id == 'original'
            ? t.getOriginalFile(f.quality)
            : f.quality,
        extension_: f.extension_,
        startNow: now,
        thumbnail: info.thumbnail,
      ),
    );

class _PhoneBrowser extends ConsumerStatefulWidget {
  const _PhoneBrowser({required this.snapshot});

  final BrowserSnapshot snapshot;

  @override
  ConsumerState<_PhoneBrowser> createState() => _PhoneBrowserState();
}

class _PhoneBrowserState extends ConsumerState<_PhoneBrowser> {
  final _address = GlobalKey<_PhoneAddressState>();
  String _historyView = 'history';
  bool _quick = false;

  BrowserController get _browser => ref.read(browserProvider.notifier);

  void _openHistory(String view) {
    final t = L10n.of(context);
    setState(() => _historyView = view);
    if (_browser.tabHistory() != null) _toast(context, t.brTooManyTabs);
  }

  void _newTab() {
    final t = L10n.of(context);
    if (_browser.tabNew() != null) {
      _toast(context, t.brTooManyTabs);
      return;
    }
    _address.currentState?.edit();
  }

  /// Android Back: the page's previous page, else back to Obtenir.
  void _back() {
    final s = widget.snapshot;
    if (s.kind == 'web' && s.canGoBack) {
      _browser.nav('back');
    } else {
      context.go(Routes.get);
    }
  }

  Future<void> _sheet(Widget Function(BuildContext sheet) build) {
    final c = MmColors.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(top: false, child: build(sheet)),
    );
  }

  void _formats(List<Candidate> candidates) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    _sheet(
      (sheet) => SizedBox(
        height: height,
        child: _PhoneFormats(
          key: ValueKey(widget.snapshot.url),
          candidates: candidates,
          onStarted: () => Navigator.of(sheet).pop(),
        ),
      ),
    );
  }

  /// Hold on the floating button: the main media at its default format.
  Future<void> _quickDownload(List<Candidate> candidates) async {
    final t = L10n.of(context);
    final main = mainCandidate(candidates);
    if (main == null || _quick) return;
    setState(() => _quick = true);
    try {
      final a = await ref.read(getApiProvider).analyze(main.url);
      final info = a.info;
      final f = info == null || a.status != AnalysisStatus.ready
          ? null
          : preferredFormat(
                  info.video,
                  ref.read(getSettingsProvider).value,
                  audio: false,
                ) ??
                preferredFormat(
                  info.audio,
                  ref.read(getSettingsProvider).value,
                  audio: true,
                );
      if (info == null || f == null) throw StateError('no format');
      await _startDownload(ref, t, info, f, now: true);
      if (mounted) _toast(context, t.getAddedToQueue(shortQuality(f)));
    } catch (_) {
      if (mounted) _toast(context, t.brItemProtected);
    } finally {
      if (mounted) setState(() => _quick = false);
    }
  }

  void _tabs() {
    _sheet(
      (sheet) => _PhoneTabs(
        onNew: () {
          Navigator.of(sheet).pop();
          _newTab();
        },
        onDone: () => Navigator.of(sheet).pop(),
      ),
    );
  }

  void _menu() {
    final t = L10n.of(context);
    final s = widget.snapshot;
    final web = s.kind == 'web';
    final favorites = ref.read(browserFavoritesProvider.notifier);
    final starred = web && favorites.has(s.url);
    final items = <(IconData, String, VoidCallback?)>[
      (PhosphorRegular.plus, t.brStartTab, _newTab),
      (
        starred ? PhosphorFill.star : PhosphorRegular.star,
        starred ? t.brFavRemove : t.brFavAdd,
        web
            ? () {
                final now = favorites.toggle(s.url, s.title);
                _toast(context, now ? t.brFavAdded : t.brFavRemoved);
              }
            : null,
      ),
      (
        PhosphorRegular.clockCounterClockwise,
        t.brHistory,
        () => _openHistory('history'),
      ),
      (
        PhosphorRegular.arrowClockwise,
        t.brReload,
        web ? () => _browser.nav('reload') : null,
      ),
    ];
    _sheet((sheet) {
      final c = MmColors.of(sheet);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetHandle(),
            for (final (icon, label, onTap) in items)
              Pressable(
                onTap: onTap == null
                    ? null
                    : () {
                        Navigator.of(sheet).pop();
                        onTap();
                      },
                semanticLabel: label,
                child: Opacity(
                  opacity: onTap == null ? 0.4 : 1,
                  child: SizedBox(
                    height: 52,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(icon, size: 22, color: c.muted),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              label,
                              style: MmType.body.copyWith(color: c.fg),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = widget.snapshot;
    final web = s.kind == 'web';
    final candidates = candidatesOf(s);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ColoredBox(
        color: c.bg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: c.sidebar,
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _PhoneAddress(
                      key: _address,
                      snapshot: s,
                      mediaCount: web ? candidates.length : 0,
                      onMedia: () => _formats(candidates),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Pressable(
                    onTap: _tabs,
                    semanticLabel: t.brTabsOpen(s.tabs.length),
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: c.fg, width: 2),
                          ),
                          child: Text(
                            '${s.tabs.length}',
                            style: MmType.labelStrong.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: c.fg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: _menu,
                    semanticLabel: t.moreOptions,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                    child: SizedBox(
                      width: 40,
                      height: 44,
                      child: Icon(
                        PhosphorRegular.dotsThreeVertical,
                        size: 22,
                        color: c.fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 3,
              child: web && s.loading
                  ? LinearProgressIndicator(
                      minHeight: 3,
                      color: c.accent,
                      backgroundColor: Colors.transparent,
                    )
                  : ColoredBox(color: c.sidebar),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: web
                        ? const _PhonePage()
                        : s.kind == 'history'
                        ? _HistoryTab(
                            view: _historyView,
                            onView: (v) => setState(() => _historyView = v),
                            onOpen: (url) => _browser.navigate(url),
                            onHidden: () => ref.read(browserApiProvider).hide(),
                          )
                        : _StartPage(
                            compact: true,
                            onOpen: (a) => _browser.navigate(a),
                            onHidden: () => ref.read(browserApiProvider).hide(),
                          ),
                  ),
                  // Only with media really found; never over the bar below.
                  if (web && candidates.isNotEmpty)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 16,
                      child: Center(
                        child: _DownloadFab(
                          count: candidates.length,
                          busy: _quick,
                          onTap: () => _formats(candidates),
                          onHold: () => _quickDownload(candidates),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _PhoneBottomBar(
              snapshot: s,
              onFavorites: () => _openHistory('favorites'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen 03: the media found on the page as chips (the main one
/// preselected), then the analysis of the chosen one, as in Obtenir:
/// Vidéo / Audio seul / Sous-titres, formats, folder, « À la file » and
/// « Télécharger · taille ».
class _PhoneFormats extends StatefulWidget {
  const _PhoneFormats({
    super.key,
    required this.candidates,
    required this.onStarted,
  });

  final List<Candidate> candidates;
  final VoidCallback onStarted;

  @override
  State<_PhoneFormats> createState() => _PhoneFormatsState();
}

class _PhoneFormatsState extends State<_PhoneFormats> {
  late String? _url = mainCandidate(widget.candidates)?.url;

  String _kind(L10n t, String kind) => switch (kind) {
    'audio' => t.brKindAudio,
    'hls' => t.brKindHls,
    'dash' => t.brKindDash,
    'page' => t.brKindPage,
    _ => t.brKindVideo,
  };

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final url = _url;
    final selected = widget.candidates.where((m) => m.url == url).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const _SheetHandle(),
        if (widget.candidates.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (final m in widget.candidates)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      onTap: () => setState(() => _url = m.url),
                      semanticLabel: '${_kind(t, m.kind)} · ${m.title}',
                      selected: m.url == url,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 32,
                        constraints: const BoxConstraints(maxWidth: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: m.url == url ? c.accentSubtle : c.surface2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: m.url == url ? c.accent : c.line,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              m.kind == 'audio'
                                  ? PhosphorRegular.musicNote
                                  : PhosphorRegular.filmStrip,
                              size: 16,
                              color: m.url == url ? c.chipText : c.muted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                m.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.labelStrong.copyWith(
                                  fontSize: 13,
                                  color: m.url == url ? c.chipText : c.fgSoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (url != null)
          Expanded(
            child: GetAnalysisScreen(
              key: ValueKey(url),
              url: url,
              tab: selected?.kind == 'audio' ? 'audio' : 'video',
              onStarted: widget.onStarted,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text(
            t.brLegalHint,
            textAlign: TextAlign.center,
            style: MmType.caption.copyWith(fontSize: 11.5, color: c.muted),
          ),
        ),
      ],
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: MmColors.of(context).lineStrong,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

/// The page of the selected tab (BrowserChannel.kt shows it here).
class _PhonePage extends ConsumerStatefulWidget {
  const _PhonePage();

  @override
  ConsumerState<_PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<_PhonePage> {
  late final BrowserApi _api = ref.read(browserApiProvider);

  @override
  void initState() {
    super.initState();
    // The size is the platform view's: the core only needs "shown".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _api.show(0, 0, 1, 1);
    });
  }

  @override
  void dispose() {
    _api.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const ColoredBox(color: Colors.white);
    return const AndroidView(
      viewType: 'org.miarina.media/browser_page',
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}

/// Address pill: lock, host in full color and the rest muted, media chip;
/// a tap edits it (address or search).
class _PhoneAddress extends ConsumerStatefulWidget {
  const _PhoneAddress({
    super.key,
    required this.snapshot,
    required this.mediaCount,
    required this.onMedia,
  });

  final BrowserSnapshot snapshot;
  final int mediaCount;
  final VoidCallback onMedia;

  @override
  ConsumerState<_PhoneAddress> createState() => _PhoneAddressState();
}

class _PhoneAddressState extends ConsumerState<_PhoneAddress> {
  final _field = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) setState(() => _editing = false);
    });
  }

  @override
  void dispose() {
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  void edit() {
    final s = widget.snapshot;
    _field.text = s.kind == 'web' ? s.url : '';
    _field.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _field.text.length,
    );
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _submit(String value) {
    final t = L10n.of(context);
    if (value.trim().isEmpty) return;
    final error = ref.read(browserProvider.notifier).navigate(value);
    if (error == null) {
      _focus.unfocus();
      setState(() => _editing = false);
    } else {
      _toast(context, t.brUnsupported);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final s = widget.snapshot;
    final web = s.kind == 'web' && s.url.isNotEmpty;
    final parts = splitAddress(s.url);
    final Widget content;
    if (_editing) {
      content = TextField(
        key: const ValueKey('browser-address'),
        controller: _field,
        focusNode: _focus,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        autocorrect: false,
        onSubmitted: _submit,
        style: MmType.monoStyle(size: 14, color: c.fg),
        cursorColor: c.accent,
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: t.brAddressPh,
          hintStyle: MmType.body.copyWith(fontSize: 14, color: c.faint),
        ),
      );
    } else {
      content = Text.rich(
        web
            ? TextSpan(
                children: [
                  TextSpan(
                    text: parts.host,
                    style: MmType.monoStyle(size: 14, color: c.fg),
                  ),
                  TextSpan(
                    text: parts.rest,
                    style: MmType.monoStyle(size: 14, color: c.muted),
                  ),
                ],
              )
            : TextSpan(
                text: t.brAddressPh,
                style: MmType.body.copyWith(fontSize: 14, color: c.muted),
              ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Pressable(
      onTap: _editing ? null : edit,
      semanticLabel: web ? s.url : t.brAddressPh,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 14, right: 7),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(
              _editing || !web
                  ? PhosphorRegular.magnifyingGlass
                  : parts.secure
                  ? PhosphorFill.lockSimple
                  : PhosphorRegular.globe,
              size: 18,
              color: web && parts.secure && !_editing ? c.accent : c.muted,
            ),
            const SizedBox(width: 8),
            Expanded(child: content),
            if (!_editing && widget.mediaCount > 0) ...[
              const SizedBox(width: 6),
              Pressable(
                onTap: widget.onMedia,
                semanticLabel: widget.mediaCount == 1
                    ? t.brMediaOne
                    : t.brMediaMany(widget.mediaCount),
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: c.accent.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorFill.filmStrip, size: 16, color: c.chipText),
                      const SizedBox(width: 5),
                      Text(
                        '${widget.mediaCount}',
                        style: MmType.labelStrong.copyWith(
                          fontSize: 13,
                          color: c.chipText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Télécharger · N": tap for the formats sheet, hold for the default
/// format of the main media.
class _DownloadFab extends StatelessWidget {
  const _DownloadFab({
    required this.count,
    required this.busy,
    required this.onTap,
    required this.onHold,
  });

  final int count;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onHold;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final label = t.brDownloadCount(count);
    return Semantics(
      button: true,
      label: label,
      hint: t.brDownloadHoldHint,
      onLongPress: onHold,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onHold,
        child: Container(
          height: 52,
          padding: const EdgeInsets.only(left: 18, right: 14),
          decoration: BoxDecoration(
            color: c.accent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: MmShadows.floating,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _fabInk,
                  ),
                )
              else
                const Icon(
                  PhosphorRegular.downloadSimple,
                  size: 22,
                  color: _fabInk,
                ),
              const SizedBox(width: 8),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _fabInk,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 1,
                height: 22,
                color: _fabInk.withValues(alpha: 0.25),
              ),
              const SizedBox(width: 8),
              const Icon(PhosphorRegular.caretUp, size: 20, color: _fabInk),
            ],
          ),
        ),
      ),
    );
  }
}

/// 60 dp: back, forward, start page, favorites, back to the app.
class _PhoneBottomBar extends ConsumerWidget {
  const _PhoneBottomBar({required this.snapshot, required this.onFavorites});

  final BrowserSnapshot snapshot;
  final VoidCallback onFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final browser = ref.read(browserProvider.notifier);
    final s = snapshot;
    final web = s.kind == 'web';
    Widget button(
      IconData icon,
      String label,
      VoidCallback? onTap, {
      Color? color,
    }) => Expanded(
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        borderRadius: BorderRadius.circular(MmRadius.pill),
        child: SizedBox(
          height: 60,
          child: Icon(
            icon,
            size: 24,
            color: onTap == null ? c.faint : color ?? c.fgSoft,
          ),
        ),
      ),
    );
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(top: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          button(
            PhosphorRegular.arrowLeft,
            t.brBack,
            web && s.canGoBack ? () => browser.nav('back') : null,
          ),
          button(
            PhosphorRegular.arrowRight,
            t.brForward,
            web && s.canGoForward ? () => browser.nav('forward') : null,
          ),
          button(
            PhosphorRegular.house,
            t.brHome,
            s.kind == 'start' ? null : () => browser.nav('home'),
          ),
          button(PhosphorRegular.bookmarkSimple, t.brFavorites, onFavorites),
          button(
            PhosphorRegular.squaresFour,
            t.brBackToApp,
            () => context.go(Routes.get),
            color: c.accent,
          ),
        ],
      ),
    );
  }
}

/// The open tabs: select, close, new tab.
class _PhoneTabs extends ConsumerWidget {
  const _PhoneTabs({required this.onNew, required this.onDone});

  final VoidCallback onNew;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final browser = ref.read(browserProvider.notifier);
    final tabs =
        ref.watch(browserProvider.select((s) => s.snapshot?.tabs)) ??
        const <BrowserTab>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        const _SheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.brTabs,
                  style: MmType.heading.copyWith(fontSize: 17, color: c.fg),
                ),
              ),
              Pressable(
                onTap: onNew,
                semanticLabel: t.brStartTab,
                borderRadius: BorderRadius.circular(MmRadius.pill),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    borderRadius: BorderRadius.circular(MmRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(PhosphorRegular.plus, size: 18, color: c.chipText),
                      const SizedBox(width: 6),
                      Text(
                        t.brStartTab,
                        style: MmType.labelStrong.copyWith(color: c.chipText),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              for (final tab in tabs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Pressable(
                    onTap: () {
                      browser.tabSelect(tab.id);
                      onDone();
                    },
                    semanticLabel: _tabLabel(t, tab),
                    selected: tab.active,
                    borderRadius: BorderRadius.circular(MmRadius.md),
                    child: Container(
                      height: 56,
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      decoration: BoxDecoration(
                        color: tab.active ? c.accentSubtle : c.surface2,
                        borderRadius: BorderRadius.circular(MmRadius.md),
                        border: Border.all(
                          color: tab.active ? c.accent : c.line,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            switch (tab.kind) {
                              'history' =>
                                PhosphorRegular.clockCounterClockwise,
                              'web' => PhosphorRegular.globe,
                              _ => PhosphorRegular.house,
                            },
                            size: 20,
                            color: tab.active ? c.chipText : c.muted,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _tabLabel(t, tab),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: MmType.labelStrong.copyWith(
                                    fontSize: 14,
                                    color: c.fg,
                                  ),
                                ),
                                if (tab.kind == 'web')
                                  Text(
                                    [
                                      hostOf(tab.url),
                                      if (tab.media > 0)
                                        tab.media == 1
                                            ? t.brMediaOne
                                            : t.brMediaMany(tab.media),
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MmType.monoStyle(
                                      size: 11.5,
                                      color: c.muted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Pressable(
                            onTap: () => browser.tabClose(tab.id),
                            semanticLabel: t.brCloseTab(_tabLabel(t, tab)),
                            borderRadius: BorderRadius.circular(MmRadius.pill),
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                PhosphorRegular.x,
                                size: 18,
                                color: c.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _tabLabel(L10n t, BrowserTab tab) => switch (tab.kind) {
  'history' => t.brHistory,
  'web' => tab.title.isNotEmpty ? tab.title : hostOf(tab.url),
  _ => t.brStartTab,
};
