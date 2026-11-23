import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/browser.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;
import '../get/get_data.dart' show downloadsProvider;
import '../library/library_data.dart' show dataDirProvider;

export '../../src/rust/api/browser.dart'
    show
        BrowserEvent,
        BrowserFavorite,
        BrowserPageCommand,
        BrowserSnapshot,
        BrowserTab,
        BrowserVisit,
        DetectedMediaInfo;

/// The built-in browser in the core (WebView2 pages on Windows, native
/// WebViews on Android); tests use a fake.
abstract interface class BrowserApi {
  /// False when the pages cannot live on this thread.
  Future<bool> init();
  Stream<rust.BrowserEvent> events();
  rust.BrowserSnapshot snapshot();

  /// Physical pixels of the window's client area.
  void show(int x, int y, int width, int height);
  void hide();

  /// The address opened; throws with `not_a_web_address` or
  /// `unsupported_address`.
  String navigate(String address);
  void nav(String action);
  void tabNew([String? url]);
  void tabClose(int id);
  void tabSelect(int id);
  void cycle(int step);
  void scan();

  /// Selects the history and favorites tab (opened if needed).
  void tabHistory();
  List<rust.BrowserFavorite> favorites();

  /// Stars or unstars a web page; the new list.
  List<rust.BrowserFavorite> favoriteToggle(String url, String title);
  List<rust.BrowserVisit> history(String query);
  void historyDelete(int id);
  void historyClear();

  /// Android: what a native page did (`type`: started, finished, moved,
  /// title, found), checked by the core.
  void pageReport(String type, Map<Object?, Object?> report);
}

class RustBrowserApi implements BrowserApi {
  RustBrowserApi(this._ref);

  final Ref _ref;

  @override
  Future<bool> init() async {
    if (!(Platform.isWindows || Platform.isAndroid) ||
        !RustLib.instance.initialized) {
      return false;
    }
    // The browser shares the database opened by the download manager.
    await _ref.read(downloadsProvider.notifier).started;
    return rust.browserInit(dataDir: await _ref.read(dataDirProvider.future));
  }

  @override
  Stream<rust.BrowserEvent> events() => rust.browserEvents();

  @override
  rust.BrowserSnapshot snapshot() => rust.browserSnapshot();

  @override
  void show(int x, int y, int width, int height) =>
      rust.browserShow(x: x, y: y, width: width, height: height);

  @override
  void hide() => rust.browserHide();

  @override
  String navigate(String address) => rust.browserNavigate(address: address);

  @override
  void nav(String action) => rust.browserNav(action: action);

  @override
  void tabNew([String? url]) => rust.browserTabNew(url: url);

  @override
  void tabClose(int id) => rust.browserTabClose(id: id);

  @override
  void tabSelect(int id) => rust.browserTabSelect(id: id);

  @override
  void cycle(int step) => rust.browserCycle(step: step);

  @override
  void scan() => rust.browserScan();

  @override
  void tabHistory() => rust.browserTabHistory();

  @override
  List<rust.BrowserFavorite> favorites() => rust.browserFavorites();

  @override
  List<rust.BrowserFavorite> favoriteToggle(String url, String title) =>
      rust.browserFavoriteToggle(url: url, title: title);

  @override
  List<rust.BrowserVisit> history(String query) =>
      rust.browserHistory(query: query, limit: 500);

  @override
  void historyDelete(int id) => rust.browserHistoryDelete(id: id);

  @override
  void historyClear() => rust.browserHistoryClear();

  @override
  void pageReport(String type, Map<Object?, Object?> r) {
    final tab = r['tab'];
    if (tab is! int || tab <= 0) return;
    String text(String key) => r[key] is String ? r[key] as String : '';
    bool flag(String key) => r[key] == true;
    switch (type) {
      case 'started':
        rust.browserPageStarted(tab: tab, url: text('url'));
      case 'finished':
        rust.browserPageFinished(
          tab: tab,
          ok: flag('ok'),
          canGoBack: flag('back'),
          canGoForward: flag('forward'),
        );
      case 'moved':
        rust.browserPageMoved(
          tab: tab,
          url: text('url'),
          canGoBack: flag('back'),
          canGoForward: flag('forward'),
        );
      case 'title':
        rust.browserPageTitle(tab: tab, title: text('title'));
      case 'found':
        rust.browserPageFound(
          tab: tab,
          kind: text('kind'),
          url: text('url'),
          detail: text('detail'),
        );
    }
  }
}

final browserApiProvider = Provider<BrowserApi>(RustBrowserApi.new);

/// Android: the native pages (BrowserChannel.kt), one per tab, shown in
/// the screen's platform view. Null elsewhere and in tests.
abstract interface class BrowserPages {
  void listen(
    void Function(String type, Map<Object?, Object?> report) onReport,
  );
  Future<void> command(rust.BrowserPageCommand command);
}

class AndroidBrowserPages implements BrowserPages {
  static const _channel = MethodChannel('org.miarina.media/browser');

  @override
  void listen(void Function(String, Map<Object?, Object?>) onReport) {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      if (call.method != 'report' || args is! Map) return;
      final type = args['type'];
      if (type is String) onReport(type, args);
    });
  }

  @override
  Future<void> command(rust.BrowserPageCommand c) async {
    try {
      await _channel.invokeMethod<void>('command', {
        'tab': c.tab,
        'action': c.action,
        'url': c.url,
      });
    } catch (e) {
      debugPrint('browser page: $e');
    }
  }
}

final browserPagesProvider = Provider<BrowserPages?>(
  (ref) => Platform.isAndroid ? AndroidBrowserPages() : null,
);

/// Something the page asked of the screen (focus the address, analyze a
/// file it offered…), numbered so the same request twice is seen twice.
@immutable
class BrowserSignal {
  const BrowserSignal(this.serial, {this.shortcut, this.download});

  final int serial;
  final String? shortcut;
  final String? download;
}

@immutable
class BrowserState {
  const BrowserState({this.available, this.snapshot, this.signal});

  /// Null while starting.
  final bool? available;
  final rust.BrowserSnapshot? snapshot;
  final BrowserSignal? signal;

  BrowserState copyWith({
    bool? available,
    rust.BrowserSnapshot? snapshot,
    BrowserSignal? signal,
  }) => BrowserState(
    available: available ?? this.available,
    snapshot: snapshot ?? this.snapshot,
    signal: signal ?? this.signal,
  );
}

final browserProvider = NotifierProvider<BrowserController, BrowserState>(
  BrowserController.new,
);

class BrowserController extends Notifier<BrowserState> {
  StreamSubscription<rust.BrowserEvent>? _events;
  int _serial = 0;

  BrowserApi get api => ref.read(browserApiProvider);

  @override
  BrowserState build() {
    ref.onDispose(() => _events?.cancel());
    unawaited(_start());
    return const BrowserState();
  }

  BrowserPages? _pages;

  Future<void> _start() async {
    try {
      final ok = await api.init();
      if (!ok) {
        state = state.copyWith(available: false);
        return;
      }
      _pages = ref.read(browserPagesProvider);
      _pages?.listen(api.pageReport);
      _events = api.events().listen(_apply);
      state = state.copyWith(available: true, snapshot: api.snapshot());
    } catch (e) {
      debugPrint('browser not started: $e');
      state = state.copyWith(available: false);
    }
  }

  void _apply(rust.BrowserEvent e) {
    // WebView2 could not start (runtime missing): the screen says so.
    if (e.shortcut == 'unavailable') {
      state = state.copyWith(available: false);
      return;
    }
    // Android: an order for a native page.
    if (e.page != null) unawaited(_pages?.command(e.page!));
    if (e.snapshot != null) state = state.copyWith(snapshot: e.snapshot);
    // A popup: a new tab, outside the page's own callback.
    if (e.openTab != null) _guard(() => api.tabNew(e.openTab));
    if (e.shortcut != null || e.download != null) {
      state = state.copyWith(
        signal: BrowserSignal(
          ++_serial,
          shortcut: e.shortcut,
          download: e.download,
        ),
      );
    }
  }

  /// Runs a browser call; a refused one (12 tabs, not a web page) is
  /// reported with its code.
  String? _guard(void Function() call) {
    try {
      call();
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// Null when opened, else the reason (`not_a_web_address`,
  /// `unsupported_address`).
  String? navigate(String address) => _guard(() => api.navigate(address));

  void nav(String action) => _guard(() => api.nav(action));

  /// Null when opened, else `too_many_tabs`.
  String? tabNew([String? url]) => _guard(() => api.tabNew(url));

  void tabClose(int id) => _guard(() => api.tabClose(id));

  void tabSelect(int id) => _guard(() => api.tabSelect(id));

  void cycle(int step) => _guard(() => api.cycle(step));

  /// Null when shown, else `too_many_tabs`.
  String? tabHistory() => _guard(api.tabHistory);
}

/// Starred pages (newest first), shared by the toolbar star, the start
/// page and the favorites tab.
final browserFavoritesProvider =
    NotifierProvider<FavoritesController, List<rust.BrowserFavorite>>(
      FavoritesController.new,
    );

class FavoritesController extends Notifier<List<rust.BrowserFavorite>> {
  @override
  List<rust.BrowserFavorite> build() {
    // Read once the browser is up.
    if (ref.watch(browserProvider.select((s) => s.available)) != true) {
      return const [];
    }
    try {
      return ref.read(browserApiProvider).favorites();
    } catch (_) {
      return const [];
    }
  }

  bool has(String url) => state.any((f) => f.url == url);

  /// True when the page is now a favorite.
  bool toggle(String url, String title) {
    final had = has(url);
    try {
      state = ref.read(browserApiProvider).favoriteToggle(url, title);
    } catch (_) {
      return had;
    }
    return !had;
  }
}

/// Something the user can download from the current page.
@immutable
class Candidate {
  const Candidate({
    required this.url,
    required this.kind,
    required this.title,
    required this.detail,
    this.sizeBytes,
  });

  /// What gets analyzed: a media address, or the page itself (extractor).
  final String url;

  /// video, audio, hls, dash, page.
  final String kind;
  final String title;
  final String detail;
  final int? sizeBytes;
}

String _decode(String name) {
  try {
    return Uri.decodeComponent(name);
  } catch (_) {
    return name;
  }
}

String hostOf(String url) => Uri.tryParse(url)?.host ?? '';

/// Media found on the page, plus the page itself when it plays a stream
/// only the extractor can read (as the Tauri app).
List<Candidate> candidatesOf(rust.BrowserSnapshot s) => [
  if (s.streamPlayer && s.url.isNotEmpty)
    Candidate(
      url: s.url,
      kind: 'page',
      title: s.title.isNotEmpty ? s.title : hostOf(s.url),
      detail: hostOf(s.url),
    ),
  for (final m in s.media)
    Candidate(
      url: m.url,
      kind: m.kind,
      title: m.name.isNotEmpty ? _decode(m.name) : m.host,
      detail: m.host,
      sizeBytes: m.sizeBytes?.toInt(),
    ),
];

int _heightIn(String title) =>
    int.tryParse(
      RegExp(
            r'(\d{3,4})p(?![a-z])',
            caseSensitive: false,
          ).firstMatch(title)?.group(1) ??
          '',
    ) ??
    0;

/// Pre-selected item: the page player, else the best video variant up to
/// 1080p, else the first video, else the first item.
Candidate? mainCandidate(List<Candidate> list) {
  for (final c in list) {
    if (c.kind == 'page') return c;
  }
  final videos = [
    for (final c in list)
      if (c.kind == 'video') c,
  ];
  final sized = [
    for (final c in videos)
      if (_heightIn(c.title) > 0 && _heightIn(c.title) <= 1080) c,
  ]..sort((a, b) => _heightIn(b.title).compareTo(_heightIn(a.title)));
  if (sized.isNotEmpty) return sized.first;
  if (videos.isNotEmpty) return videos.first;
  return list.isEmpty ? null : list.first;
}

/// Address bar: host in full color, the rest muted.
({String host, String rest, bool secure}) splitAddress(String url) {
  final u = Uri.tryParse(url);
  if (u == null || u.host.isEmpty) return (host: url, rest: '', secure: false);
  final path = u.path == '/' ? '' : u.path;
  final query = u.hasQuery ? '?${u.query}' : '';
  return (
    host: u.hasPort ? '${u.host}:${u.port}' : u.host,
    rest: '$path$query',
    secure: u.scheme == 'https',
  );
}

/// Sites offered on the start page (as the Tauri app).
const startSites = [
  ('YouTube', 'https://m.youtube.com'),
  ('Google', 'https://www.google.com'),
  ('Wikimedia Commons', 'https://commons.wikimedia.org'),
  ('Internet Archive', 'https://archive.org'),
  ('Vimeo', 'https://vimeo.com'),
  ('Dailymotion', 'https://www.dailymotion.com'),
  ('SoundCloud', 'https://soundcloud.com'),
  ('Facebook', 'https://m.facebook.com'),
];
