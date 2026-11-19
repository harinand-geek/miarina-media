import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/rust/api/library.dart';
import '../../src/rust/api/search.dart';
import '../library/groups.dart';
import '../library/library_data.dart';

/// Search of the local library; tests use an in-memory one.
abstract interface class SearchApi {
  Future<SearchResults> search(String query, {int limit = 200});
}

class RustSearchApi implements SearchApi {
  RustSearchApi(this._ref);

  final Ref _ref;

  @override
  Future<SearchResults> search(String query, {int limit = 200}) async =>
      librarySearch(
        dbPath: await _ref.read(dbPathProvider.future),
        query: query,
        limit: limit,
      );
}

final searchApiProvider = Provider<SearchApi>(RustSearchApi.new);

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'æ': 'ae',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'œ': 'oe',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
};

/// Lower case without accents, for comparisons ("Marée" → "maree").
String fold(String text) {
  final b = StringBuffer();
  for (final ch in text.toLowerCase().split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

/// Every word of [query] starts a word of [text] (the core's rule).
bool matchesWords(String text, String query) {
  final words = fold(text).split(RegExp(r'[^a-z0-9]+'));
  return fold(query)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((q) => q.isNotEmpty)
      .every((q) => words.any((w) => w.startsWith(q)));
}

/// How well [title] answers [query]: exact 3, starts with 2, else 1.
int titleScore(String title, String query) {
  final t = fold(title).trim();
  final q = fold(query).trim();
  if (t == q) return 3;
  if (t.startsWith(q)) return 2;
  return 1;
}

class SearchData {
  const SearchData({
    required this.query,
    required this.tracks,
    required this.focus,
    required this.cinema,
    required this.albums,
    required this.artists,
  });

  final String query;
  final List<SearchHit> tracks;
  final List<SearchHit> focus;
  final List<SearchHit> cinema;
  final List<LibraryGroup> albums;
  final List<LibraryGroup> artists;

  int get musicCount => tracks.length + albums.length + artists.length;
  int get total => musicCount + focus.length + cinema.length;
  bool get isEmpty => total == 0;

  /// The entry that answers the query best (title match first, then
  /// music, Focus, Cinema).
  SearchHit? get best {
    SearchHit? top;
    var score = 0;
    for (final h in [...tracks, ...focus, ...cinema]) {
      final s = titleScore(h.item.title, query);
      if (s > score) {
        score = s;
        top = h;
      }
    }
    return top;
  }
}

final searchProvider = FutureProvider.family<SearchData, String>((
  ref,
  query,
) async {
  final q = query.trim();
  if (q.isEmpty) {
    return const SearchData(
      query: '',
      tracks: [],
      focus: [],
      cinema: [],
      albums: [],
      artists: [],
    );
  }
  final results = await ref.watch(searchApiProvider).search(q);
  final albums = await ref.watch(groupsProvider(GroupKind.album).future);
  final artists = await ref.watch(groupsProvider(GroupKind.artist).future);
  List<SearchHit> of(SearchSection s) =>
      [
        for (final h in results.hits)
          if (h.section == s) h,
      ]..sort(
        (a, b) =>
            titleScore(b.item.title, q).compareTo(titleScore(a.item.title, q)),
      );
  return SearchData(
    query: q,
    tracks: of(SearchSection.music),
    focus: of(SearchSection.focus),
    cinema: of(SearchSection.cinema),
    albums: [
      for (final a in albums)
        if (matchesWords(a.name, q)) a,
    ],
    artists: [
      for (final a in artists)
        if (matchesWords(a.name, q)) a,
    ],
  );
});
