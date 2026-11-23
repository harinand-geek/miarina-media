import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/logo.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_widgets.dart' show PillSegment;
import '../get/get_data.dart';
import '../get/get_screens.dart' show bytes;
import 'browser_data.dart';

part 'browser_phone.dart';

// Obtenir › Navigateur (Windows v2 screen 8), ported from the Tauri app.
// The page is a native WebView2 placed in the area this screen leaves for
// it; nothing Flutter draws can sit above it, so the Tauri floating button
// becomes a strip under the page and the format sheet a side panel.
// Phones: browser_phone.dart.

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

class BrowserScreen extends ConsumerStatefulWidget {
  const BrowserScreen({super.key});

  @override
  ConsumerState<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends ConsumerState<BrowserScreen> {
  final _address = GlobalKey<_AddressFieldState>();
  bool _panel = false;

  /// What the history tab shows: history or favorites.
  String _historyView = 'history';

  void _openHistory(String view) {
    final t = L10n.of(context);
    setState(() => _historyView = view);
    if (_browser.tabHistory() != null) _toast(context, t.brTooManyTabs);
  }

  Timer? _scan;

  BrowserController get _browser => ref.read(browserProvider.notifier);

  @override
  void initState() {
    super.initState();
    // Players often attach their sources after the page has loaded.
    _scan = Timer.periodic(const Duration(seconds: 3), (_) {
      final s = ref.read(browserProvider).snapshot;
      if (s?.kind == 'web') ref.read(browserApiProvider).scan();
    });
  }

  @override
  void dispose() {
    _scan?.cancel();
    super.dispose();
  }

  void _shortcut(String name) {
    final s = ref.read(browserProvider).snapshot;
    switch (name) {
      case 'Ctrl+L':
        _address.currentState?.edit();
      case 'Ctrl+T':
        _newTab();
      case 'Ctrl+W':
        if (s != null) _browser.tabClose(_activeId(s));
      case 'Ctrl+Tab':
        _browser.cycle(1);
      case 'Ctrl+Shift+Tab':
        _browser.cycle(-1);
      case 'Ctrl+H':
        _openHistory('history');
      case 'F5':
        _browser.nav('reload');
    }
  }

  int _activeId(BrowserSnapshot s) =>
      s.tabs.firstWhere((t) => t.active, orElse: () => s.tabs.first).id;

  void _newTab() {
    final t = L10n.of(context);
    if (_browser.tabNew() != null) _toast(context, t.brTooManyTabs);
    _address.currentState?.edit();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    ref.listen(browserProvider.select((s) => s.signal), (_, signal) {
      if (signal == null) return;
      if (signal.shortcut != null) _shortcut(signal.shortcut!);
      // A file the page offered: the app's engine analyzes it.
      if (signal.download != null) {
        context.go(
          Uri(
            path: Routes.getAnalysis,
            queryParameters: {'url': signal.download!},
          ).toString(),
        );
      }
    });
    final state = ref.watch(browserProvider);
    final desktop = ref.watch(desktopShellProvider);
    if (state.available == false) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            desktop ? t.brUnavailable : t.brUnavailablePhone,
            textAlign: TextAlign.center,
            style: MmType.body.copyWith(color: c.muted),
          ),
        ),
      );
    }
    final s = state.snapshot;
    if (s == null) return const SizedBox.shrink();
    if (!desktop) return _PhoneBrowser(snapshot: s);
    final web = s.kind == 'web';
    final candidates = candidatesOf(s);
    final panel = _panel && web && candidates.isNotEmpty;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyL, control: true): () =>
            _shortcut('Ctrl+L'),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true): () =>
            _shortcut('Ctrl+T'),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () =>
            _shortcut('Ctrl+W'),
        const SingleActivator(LogicalKeyboardKey.tab, control: true): () =>
            _shortcut('Ctrl+Tab'),
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): () =>
            _shortcut('Ctrl+Shift+Tab'),
        const SingleActivator(LogicalKeyboardKey.f5): () => _shortcut('F5'),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            _shortcut('Ctrl+H'),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TabStrip(snapshot: s, onNew: _newTab),
            _Toolbar(
              snapshot: s,
              onHistory: _openHistory,
              address: _address,
              mediaCount: candidates.length,
              onMedia: () => setState(() => _panel = !_panel),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: web
                        ? _PageHost(
                            // A new rectangle whenever the panel or strip
                            // changes the room left for the page.
                            key: ValueKey('page-$panel'),
                          )
                        : s.kind == 'history'
                        ? _HistoryTab(
                            view: _historyView,
                            onView: (v) => setState(() => _historyView = v),
                            onOpen: (url) => _browser.navigate(url),
                            onHidden: () => ref.read(browserApiProvider).hide(),
                          )
                        : _StartPage(
                            onOpen: (a) => _browser.navigate(a),
                            onHidden: () => ref.read(browserApiProvider).hide(),
                          ),
                  ),
                  if (panel)
                    SizedBox(
                      width: 360,
                      child: _MediaPanel(
                        key: ValueKey(s.url),
                        candidates: candidates,
                        onClose: () => setState(() => _panel = false),
                      ),
                    ),
                ],
              ),
            ),
            if (web && candidates.isNotEmpty && !panel)
              _DownloadStrip(
                count: candidates.length,
                onOpen: () => setState(() => _panel = true),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabStrip extends ConsumerWidget {
  const _TabStrip({required this.snapshot, required this.onNew});

  final BrowserSnapshot snapshot;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final browser = ref.read(browserProvider.notifier);
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      color: c.sidebar,
      child: Row(
        children: [
          Flexible(
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              children: [
                for (final tab in snapshot.tabs)
                  _TabChip(
                    tab: tab,
                    onTap: () => browser.tabSelect(tab.id),
                    onClose: () => browser.tabClose(tab.id),
                    label: tab.kind == 'history'
                        ? t.brHistory
                        : tab.kind == 'web' && tab.title.isNotEmpty
                        ? tab.title
                        : tab.kind == 'web'
                        ? hostOf(tab.url)
                        : t.brStartTab,
                  ),
              ],
            ),
          ),
          Tooltip(
            message: t.brNewTab,
            child: Pressable(
              onTap: onNew,
              semanticLabel: t.brNewTab,
              child: SizedBox(
                width: 34,
                height: 34,
                child: Icon(PhosphorRegular.plus, size: 18, color: c.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.tab,
    required this.label,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: Pressable(
        onTap: tab.active ? null : onTap,
        semanticLabel: label,
        selected: tab.active,
        child: Container(
          width: 220,
          padding: const EdgeInsets.only(left: 12, right: 4),
          decoration: BoxDecoration(
            color: tab.active ? c.surface : Colors.transparent,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(MmRadius.md),
            ),
          ),
          child: Row(
            children: [
              tab.loading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.accent,
                      ),
                    )
                  : Icon(PhosphorRegular.globe, size: 16, color: c.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MmType.labelStrong.copyWith(
                    fontSize: 13,
                    color: tab.active ? c.fg : c.muted,
                  ),
                ),
              ),
              if (tab.media > 0)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: c.accentSubtle,
                    borderRadius: BorderRadius.circular(MmRadius.xs),
                  ),
                  child: Text(
                    '${tab.media}',
                    style: MmType.monoStyle(size: 11, color: c.chipText),
                  ),
                ),
              Tooltip(
                message: t.brCloseTab(label),
                child: Pressable(
                  onTap: onClose,
                  semanticLabel: t.brCloseTab(label),
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: Icon(PhosphorRegular.x, size: 14, color: c.muted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.snapshot,
    required this.onHistory,
    required this.address,
    required this.mediaCount,
    required this.onMedia,
  });

  final BrowserSnapshot snapshot;
  final void Function(String view) onHistory;
  final GlobalKey<_AddressFieldState> address;
  final int mediaCount;
  final VoidCallback onMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final browser = ref.read(browserProvider.notifier);
    final s = snapshot;
    final web = s.kind == 'web';
    final starred =
        web && ref.watch(browserFavoritesProvider).any((f) => f.url == s.url);
    Widget button(IconData icon, String label, VoidCallback? onTap) => Tooltip(
      message: label,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: Opacity(
          opacity: onTap == null ? 0.35 : 1,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, size: 20, color: c.muted),
          ),
        ),
      ),
    );
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          button(
            PhosphorRegular.arrowLeft,
            t.brBack,
            s.canGoBack ? () => browser.nav('back') : null,
          ),
          button(
            PhosphorRegular.arrowRight,
            t.brForward,
            s.canGoForward ? () => browser.nav('forward') : null,
          ),
          s.loading
              ? button(PhosphorRegular.x, t.brStop, () => browser.nav('stop'))
              : button(
                  PhosphorRegular.arrowClockwise,
                  t.brReload,
                  web ? () => browser.nav('reload') : null,
                ),
          button(
            PhosphorRegular.house,
            t.brHome,
            web ? () => browser.nav('home') : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AddressField(
              key: address,
              url: web ? s.url : '',
              mediaCount: mediaCount,
              onMedia: onMedia,
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: starred ? t.brFavRemove : t.brFavAdd,
            child: Pressable(
              onTap: web
                  ? () {
                      final added = ref
                          .read(browserFavoritesProvider.notifier)
                          .toggle(s.url, s.title);
                      _toast(context, added ? t.brFavAdded : t.brFavRemoved);
                    }
                  : null,
              semanticLabel: starred ? t.brFavRemove : t.brFavAdd,
              selected: starred,
              child: Opacity(
                opacity: web ? 1 : 0.35,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    starred ? PhosphorFill.star : PhosphorRegular.star,
                    size: 20,
                    color: starred ? c.warning : c.muted,
                  ),
                ),
              ),
            ),
          ),
          button(
            PhosphorRegular.bookmarksSimple,
            t.brFavorites,
            () => onHistory('favorites'),
          ),
          button(
            PhosphorRegular.clockCounterClockwise,
            t.brHistory,
            () => onHistory('history'),
          ),
        ],
      ),
    );
  }
}

class _AddressField extends ConsumerStatefulWidget {
  const _AddressField({
    super.key,
    required this.url,
    required this.mediaCount,
    required this.onMedia,
  });

  final String url;
  final int mediaCount;
  final VoidCallback onMedia;

  @override
  ConsumerState<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends ConsumerState<_AddressField> {
  final _text = TextEditingController();
  final _focus = FocusNode(debugLabel: 'address');
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
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Ctrl+L, a click: the whole address, selected.
  void edit() {
    setState(() => _editing = true);
    _text.text = widget.url;
    _text.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _text.text.length,
    );
    _focus.requestFocus();
  }

  void _submit(String value) {
    final t = L10n.of(context);
    final error = ref.read(browserProvider.notifier).navigate(value);
    if (error != null) {
      if (error.contains('unsupported_address')) {
        _toast(context, t.brUnsupported);
      }
      return;
    }
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final parts = splitAddress(widget.url);
    final empty = widget.url.isEmpty;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(MmRadius.pill),
        border: Border.all(color: _editing ? c.accent : c.line),
      ),
      child: Row(
        children: [
          Icon(
            empty || _editing
                ? PhosphorRegular.magnifyingGlass
                : parts.secure
                ? PhosphorRegular.lockSimple
                : PhosphorRegular.info,
            size: 16,
            color: c.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _editing || empty
                ? TextField(
                    key: const ValueKey('browser-address'),
                    controller: _text,
                    focusNode: _focus,
                    onTap: _editing ? null : edit,
                    onSubmitted: _submit,
                    style: MmType.bodySm.copyWith(color: c.fg),
                    cursorColor: c.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: t.brAddressPh,
                      hintStyle: MmType.bodySm.copyWith(color: c.muted),
                    ),
                  )
                : Pressable(
                    onTap: edit,
                    semanticLabel: widget.url,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: parts.host,
                              style: MmType.monoStyle(
                                size: 13,
                                color: c.fg,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: parts.rest.isEmpty ? '' : ' ${parts.rest}',
                              style: MmType.monoStyle(size: 13, color: c.muted),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),
          if (widget.mediaCount > 0)
            Pressable(
              onTap: widget.onMedia,
              semanticLabel: t.brDownloadFound(widget.mediaCount),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: c.accentSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.pill),
                ),
                child: Text(
                  widget.mediaCount == 1
                      ? t.brMediaOne
                      : t.brMediaMany(widget.mediaCount),
                  style: MmType.captionStrong.copyWith(
                    fontSize: 12,
                    color: c.chipText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The room left for the page: reports its rectangle (physical pixels) to
/// the core after each layout, hides the page when unmounted or not
/// painted (mini player).
class _PageHost extends ConsumerStatefulWidget {
  const _PageHost({super.key});

  @override
  ConsumerState<_PageHost> createState() => _PageHostState();
}

class _PageHostState extends ConsumerState<_PageHost> {
  (int, int, int, int)? _shown;
  late final BrowserApi _api = ref.read(browserApiProvider);

  void _report() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (!TickerMode.valuesOf(context).enabled) {
      if (_shown != null) _api.hide();
      _shown = null;
      return;
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final o = box.localToGlobal(Offset.zero);
    final rect = (
      (o.dx * dpr).round(),
      (o.dy * dpr).round(),
      (box.size.width * dpr).round(),
      (box.size.height * dpr).round(),
    );
    if (rect == _shown) return;
    _shown = rect;
    _api.show(rect.$1, rect.$2, rect.$3, rect.$4);
  }

  @override
  void dispose() {
    _api.hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every size change (window, sidebar) leads here.
    MediaQuery.sizeOf(context);
    TickerMode.valuesOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) => _report());
    return LayoutBuilder(
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _report());
        return ColoredBox(color: MmColors.of(context).bg);
      },
    );
  }
}

class _StartPage extends ConsumerStatefulWidget {
  const _StartPage({
    required this.onOpen,
    required this.onHidden,
    this.compact = false,
  });

  final void Function(String address) onOpen;
  final VoidCallback onHidden;

  /// Phone: four sites a row, the floating button in the explanation.
  final bool compact;

  @override
  ConsumerState<_StartPage> createState() => _StartPageState();
}

class _StartPageState extends ConsumerState<_StartPage> {
  @override
  void initState() {
    super.initState();
    // No page above the start page.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onHidden());
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final favorites = ref.watch(browserFavoritesProvider);
    final compact = widget.compact;
    return ListView(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 32, 16, 24)
          : const EdgeInsets.fromLTRB(32, 48, 32, 24),
      children: [
        const Center(child: MiarinaLogo(size: 28)),
        const SizedBox(height: 18),
        Text(
          t.brStartTitle,
          textAlign: TextAlign.center,
          style: MmType.heading.copyWith(fontSize: 18, color: c.fg),
        ),
        const SizedBox(height: 10),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              compact ? t.brStartBodyPhone : t.brStartBody,
              textAlign: TextAlign.center,
              style: MmType.bodySm.copyWith(color: c.muted),
            ),
          ),
        ),
        const SizedBox(height: 32),
        for (final (head, sites) in [
          if (favorites.isNotEmpty)
            (t.brFavorites, [for (final f in favorites) (f.title, f.url)]),
          (favorites.isEmpty ? null : t.brSites, startSites),
        ]) ...[
          if (head != null)
            Center(
              child: SizedBox(
                width: 720,
                child: Text(
                  head.toUpperCase(),
                  style: MmType.overline.copyWith(color: c.muted),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Wrap(
                alignment: WrapAlignment.center,
                runSpacing: 16,
                children: [
                  for (final (name, address) in sites)
                    SizedBox(
                      width: compact ? 84 : 180,
                      child: Pressable(
                        onTap: () => widget.onOpen(address),
                        semanticLabel: name,
                        borderRadius: BorderRadius.circular(MmRadius.lg),
                        hoverColor: c.cardHover,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              // Letter tiles: no third-party logos are
                              // shipped (nor loaded from the network).
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: c.surface2,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  name[0],
                                  style: MmType.heading.copyWith(
                                    fontSize: 18,
                                    color: c.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: MmType.caption.copyWith(color: c.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 48),
        Text(
          t.brLegalHint,
          textAlign: TextAlign.center,
          style: MmType.caption.copyWith(fontSize: 12.5, color: c.muted),
        ),
      ],
    );
  }
}

/// Media found on the page: under the page (the page is native and covers
/// anything drawn on it).
class _DownloadStrip extends StatelessWidget {
  const _DownloadStrip({required this.count, required this.onOpen});

  final int count;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Icon(PhosphorRegular.downloadSimple, size: 20, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1 ? t.brMediaFoundOne : t.brMediaFound(count),
              style: MmType.labelStrong.copyWith(fontSize: 13.5, color: c.fg),
            ),
          ),
          Pressable(
            onTap: onOpen,
            semanticLabel: t.brDownloadFound(count),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(MmRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    PhosphorRegular.downloadSimple,
                    size: 18,
                    color: Color(0xFF062320),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.brChooseMedia,
                    style: MmType.labelStrong.copyWith(
                      fontSize: 13.5,
                      color: const Color(0xFF062320),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Télécharger depuis cette page": the media found (the main one
/// preselected), its formats read by the analysis, then queue or download.
class _MediaPanel extends ConsumerStatefulWidget {
  const _MediaPanel({
    super.key,
    required this.candidates,
    required this.onClose,
    this.sheet = false,
  });

  final List<Candidate> candidates;
  final VoidCallback onClose;

  /// Phone: the bottom sheet of the floating button (screen 03).
  final bool sheet;

  @override
  ConsumerState<_MediaPanel> createState() => _MediaPanelState();
}

class _MediaPanelState extends ConsumerState<_MediaPanel> {
  late String? _url = mainCandidate(widget.candidates)?.url;
  final _analyses = <String, Future<Analysis>>{};
  final _formats = <String, String>{};
  bool _starting = false;

  Future<Analysis> _analysis(String url) =>
      _analyses[url] ??= ref.read(getApiProvider).analyze(url);

  String _kind(L10n t, String kind) => switch (kind) {
    'audio' => t.brKindAudio,
    'hls' => t.brKindHls,
    'dash' => t.brKindDash,
    'page' => t.brKindPage,
    _ => t.brKindVideo,
  };

  Future<void> _start(
    MediaInfo info,
    FormatOffer f, {
    required bool now,
  }) async {
    final t = L10n.of(context);
    setState(() => _starting = true);
    try {
      await _startDownload(ref, t, info, f, now: now);
      if (mounted) {
        _toast(context, t.getAddedToQueue(shortQuality(f)));
        widget.onClose();
      }
    } catch (_) {
      if (mounted) _toast(context, t.brItemProtected);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final url = _url;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: widget.sheet ? null : Border(left: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.sheet) ...[
            const SizedBox(height: 10),
            const _SheetHandle(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.brSheetTitle,
                    style: MmType.heading.copyWith(fontSize: 15, color: c.fg),
                  ),
                ),
                Tooltip(
                  message: t.brClosePanel,
                  child: Pressable(
                    onTap: widget.onClose,
                    semanticLabel: t.brClosePanel,
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(PhosphorRegular.x, size: 18, color: c.muted),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final cand in widget.candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Pressable(
                      onTap: () => setState(() => _url = cand.url),
                      semanticLabel: cand.title,
                      selected: cand.url == url,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cand.url == url
                              ? c.accentSubtle
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(MmRadius.md),
                          border: Border.all(
                            color: cand.url == url ? c.accent : c.line,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cand.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.labelStrong.copyWith(
                                fontSize: 13,
                                color: c.fg,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                _kind(t, cand.kind),
                                cand.detail,
                                if (cand.sizeBytes != null)
                                  bytes(context, cand.sizeBytes!),
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
                    ),
                  ),
                if (url != null) ...[
                  const SizedBox(height: 10),
                  FutureBuilder<Analysis>(
                    future: _analysis(url),
                    builder: (context, snap) {
                      final a = snap.data;
                      if (snap.hasError ||
                          (a != null && a.status != AnalysisStatus.ready)) {
                        return Text(
                          t.brItemProtected,
                          style: MmType.bodySm.copyWith(color: c.muted),
                        );
                      }
                      if (a == null) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: LinearProgressIndicator(
                            color: c.accent,
                            backgroundColor: c.line,
                          ),
                        );
                      }
                      final info = a.info!;
                      final formats = [...info.video, ...info.audio];
                      final chosen = formats.firstWhere(
                        (f) => f.id == _formats[url],
                        orElse: () =>
                            defaultFormat(info.video) ??
                            defaultFormat(info.audio)!,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final f in formats)
                            Pressable(
                              onTap: () => setState(() => _formats[url] = f.id),
                              semanticLabel: f.quality,
                              selected: f.id == chosen.id,
                              child: Container(
                                height: 40,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: f.id == chosen.id
                                      ? c.accentSubtle
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    MmRadius.sm,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      f.id == chosen.id
                                          ? PhosphorFill.radioButton
                                          : PhosphorRegular.circle,
                                      size: 16,
                                      color: f.id == chosen.id
                                          ? c.accent
                                          : c.faint,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        f.id == 'original'
                                            ? t.getOriginalFile(f.quality)
                                            : f.quality,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: MmType.labelStrong.copyWith(
                                          fontSize: 13,
                                          color: c.fg,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      f.sizeBytes == null
                                          ? '—'
                                          : bytes(
                                              context,
                                              f.sizeBytes!.toInt(),
                                            ),
                                      style: MmType.monoStyle(
                                        size: 11.5,
                                        color: c.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _PanelButton(
                                  t.getAddToQueue,
                                  _starting
                                      ? null
                                      : () => _start(info, chosen, now: false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PanelButton(
                                  t.getDownload,
                                  _starting
                                      ? null
                                      : () => _start(info, chosen, now: true),
                                  primary: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  t.brLegalHint,
                  style: MmType.caption.copyWith(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton(this.label, this.onTap, {this.primary = false});

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? c.accent : c.surface2,
            borderRadius: BorderRadius.circular(MmRadius.sm),
            border: primary ? null : Border.all(color: c.lineStrong),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MmType.labelStrong.copyWith(
              fontSize: 13,
              color: primary ? const Color(0xFF062320) : c.fg,
            ),
          ),
        ),
      ),
    );
  }
}

/// The history and favorites tab (NAV-03, ported from the Tauri app):
/// visited pages by day and starred pages, searchable. Kept on this device;
/// clearing it deletes no file, download or favorite.
class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab({
    required this.view,
    required this.onView,
    required this.onOpen,
    required this.onHidden,
  });

  final String view;
  final ValueChanged<String> onView;
  final void Function(String url) onOpen;
  final VoidCallback onHidden;

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  String _query = '';
  Timer? _debounce;
  List<BrowserVisit>? _visits;

  BrowserApi get _api => ref.read(browserApiProvider);

  @override
  void initState() {
    super.initState();
    // No page above this tab.
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onHidden());
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _load() {
    try {
      _visits = _api.history(_query);
    } catch (_) {
      _visits = const [];
    }
    if (mounted) setState(() {});
  }

  void _search(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _load);
  }

  Future<void> _clear() async {
    final t = L10n.of(context);
    final c = MmColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: c.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MmRadius.sheet),
          side: BorderSide(color: c.overlayBorder),
        ),
        title: Text(t.brClearTitle, style: MmType.title.copyWith(color: c.fg)),
        content: Text(
          t.brClearBody,
          style: MmType.body.copyWith(color: c.fgSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              t.cancel,
              style: MmType.labelStrong.copyWith(color: c.fg),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.brClearHistory,
              style: MmType.labelStrong.copyWith(color: c.danger),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _api.historyClear();
    } catch (_) {}
    _load();
    if (mounted) _toast(context, t.brCleared);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final history = widget.view == 'history';
    final q = _query.trim().toLowerCase();
    final favorites = ref
        .watch(browserFavoritesProvider)
        .where(
          (f) =>
              q.isEmpty ||
              f.title.toLowerCase().contains(q) ||
              f.url.toLowerCase().contains(q),
        )
        .toList();
    final visits = _visits ?? const <BrowserVisit>[];
    final empty = history
        ? _visits != null && visits.isEmpty
        : favorites.isEmpty;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String dayLabel(DateTime d) {
      final diff = today.difference(d).inDays;
      if (diff == 0) return t.getToday;
      if (diff == 1) return t.getYesterday;
      return DateFormat.MMMMEEEEd(locale).format(d);
    }

    final groups = <DateTime, List<BrowserVisit>>{};
    for (final v in visits) {
      final at = DateTime.fromMillisecondsSinceEpoch(v.visitedAt);
      (groups[DateTime(at.year, at.month, at.day)] ??= []).add(v);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    history ? t.brHistory : t.brFavorites,
                    style: MmType.display.copyWith(fontSize: 24, color: c.fg),
                  ),
                ),
                PillSegment<String>(
                  values: [
                    ('history', t.brHistory),
                    ('favorites', t.brFavorites),
                  ],
                  selected: widget.view,
                  onChanged: widget.onView,
                ),
                if (history) ...[
                  const SizedBox(width: 12),
                  Pressable(
                    onTap: visits.isEmpty && _query.isEmpty ? null : _clear,
                    semanticLabel: t.brClearHistory,
                    child: Opacity(
                      opacity: visits.isEmpty && _query.isEmpty ? 0.5 : 1,
                      child: Container(
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(MmRadius.sm),
                          border: Border.all(color: c.lineStrong),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(PhosphorRegular.trash, size: 18, color: c.fg),
                            const SizedBox(width: 8),
                            Text(
                              t.brClearHistory,
                              style: MmType.labelStrong.copyWith(
                                fontSize: 13,
                                color: c.fg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(MmRadius.sm),
                border: Border.all(color: c.lineStrong),
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorRegular.magnifyingGlass,
                    size: 18,
                    color: c.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('browser-history-search'),
                      onChanged: _search,
                      style: MmType.bodySm.copyWith(color: c.fg),
                      cursorColor: c.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: t.brHistorySearch,
                        hintStyle: MmType.bodySm.copyWith(color: c.muted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (empty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  q.isNotEmpty
                      ? t.brNoMatch(_query.trim())
                      : history
                      ? t.brHistoryEmpty
                      : t.brFavoritesEmpty,
                  textAlign: TextAlign.center,
                  style: MmType.bodySm.copyWith(color: c.muted),
                ),
              )
            else if (history)
              for (final MapEntry(key: day, value: entries)
                  in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    dayLabel(day).toUpperCase(),
                    style: MmType.overline.copyWith(color: c.muted),
                  ),
                ),
                for (final v in entries)
                  _PageRow(
                    title: v.title.isNotEmpty ? v.title : hostOf(v.url),
                    url: v.url,
                    time: DateFormat.Hm(
                      locale,
                    ).format(DateTime.fromMillisecondsSinceEpoch(v.visitedAt)),
                    onOpen: () => widget.onOpen(v.url),
                    removeLabel: t.brDeleteVisit(
                      v.title.isNotEmpty ? v.title : hostOf(v.url),
                    ),
                    onRemove: () {
                      try {
                        _api.historyDelete(v.id);
                      } catch (_) {}
                      _load();
                    },
                  ),
                const SizedBox(height: 12),
              ]
            else
              for (final f in favorites)
                _PageRow(
                  title: f.title,
                  url: f.url,
                  onOpen: () => widget.onOpen(f.url),
                  removeLabel: t.brRemoveFavorite(f.title),
                  onRemove: () => ref
                      .read(browserFavoritesProvider.notifier)
                      .toggle(f.url, f.title),
                ),
            const SizedBox(height: 12),
            Text(
              t.brHistoryNote,
              style: MmType.caption.copyWith(fontSize: 12, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageRow extends StatelessWidget {
  const _PageRow({
    required this.title,
    required this.url,
    required this.onOpen,
    required this.removeLabel,
    required this.onRemove,
    this.time,
  });

  final String title;
  final String url;
  final String? time;
  final VoidCallback onOpen;
  final String removeLabel;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Row(
      children: [
        if (time != null)
          SizedBox(
            width: 44,
            child: Text(
              time!,
              style: MmType.monoStyle(size: 11.5, color: c.muted),
            ),
          ),
        Expanded(
          child: Tooltip(
            message: url,
            child: Pressable(
              onTap: onOpen,
              semanticLabel: title,
              hoverColor: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.sm),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    Icon(PhosphorRegular.globe, size: 18, color: c.muted),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.labelStrong.copyWith(
                          fontSize: 13.5,
                          color: c.fg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        hostOf(url),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: MmType.monoStyle(size: 11.5, color: c.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: removeLabel,
          child: Pressable(
            onTap: onRemove,
            semanticLabel: removeLabel,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(PhosphorRegular.x, size: 18, color: c.muted),
            ),
          ),
        ),
      ],
    );
  }
}
