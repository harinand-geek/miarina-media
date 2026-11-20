import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/cover_art.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/track_bar.dart' show formatClock;
import '../../l10n/app_localizations.dart';
import '../../src/rust/api/library.dart';
import '../../src/rust/api/tags.dart' as rust;
import '../../src/rust/frb_generated.dart' show RustLib;

export '../../src/rust/api/tags.dart' show TagFields, TagSheet;

/// The tag editor in the core (`api/tags.rs`); tests use a fake.
abstract interface class TagsApi {
  Future<rust.TagSheet> get(int id);

  /// Tags in the library, and in the file when [writeToFile]; [renameTo]
  /// renames the file first.
  Future<LibraryItem> save(
    int id,
    rust.TagFields fields, {
    required bool writeToFile,
    String? renameTo,
  });

  /// [from]: image (with [image]), source, frame (at [atSecs]), none.
  Future<LibraryItem> cover(
    int id,
    String from, {
    String? image,
    double? atSecs,
  });
}

class RustTagsApi implements TagsApi {
  const RustTagsApi();

  void _ready() {
    if (!RustLib.instance.initialized) throw StateError('library');
  }

  @override
  Future<rust.TagSheet> get(int id) async {
    _ready();
    return rust.tagsGet(id: id);
  }

  @override
  Future<LibraryItem> save(
    int id,
    rust.TagFields fields, {
    required bool writeToFile,
    String? renameTo,
  }) async {
    _ready();
    return rust.tagsSave(
      id: id,
      fields: fields,
      writeToFile: writeToFile,
      renameTo: renameTo,
    );
  }

  @override
  Future<LibraryItem> cover(
    int id,
    String from, {
    String? image,
    double? atSecs,
  }) async {
    _ready();
    return rust.tagsCover(id: id, from: from, image: image, atSecs: atSecs);
  }
}

final tagsApiProvider = Provider<TagsApi>((_) => const RustTagsApi());

/// "Choisir une image…": the picture chosen by the user (tests answer it).
final coverImagePickerProvider = Provider<Future<String?> Function(String)>(
  (_) =>
      (label) async => (await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: label,
            extensions: const ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'],
          ),
        ],
      ))?.path,
);

/// The core's error codes, in words.
String tagError(L10n t, Object e) {
  final s = '$e';
  if (s.contains('tags_unsupported')) return t.errTagsUnsupported;
  if (s.contains('tags_write')) return t.errTagsWrite;
  if (s.contains('invalid_name')) return t.errInvalidName;
  if (s.contains('file_missing')) return t.fileMissing;
  if (s.contains('not_found')) return t.errNotInLibrary;
  if (s.contains('cover_refused')) return t.errCoverRefused;
  return t.errLibrary;
}

/// "01 - Artist - Title" / "Artist - Title" / "Title" from a file name
/// (same rules as the Tauri app).
Map<String, String> tagsFromFileName(String path) {
  var stem = path.split(RegExp(r'[\\/]')).last;
  stem = stem.replaceFirst(RegExp(r'\.[^.]+$'), '');
  final parts = stem
      .replaceAll('_', ' ')
      .split(RegExp(r'\s+-\s+'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  final out = <String, String>{};
  final track = parts.isEmpty
      ? null
      : RegExp(r'^(\d{1,3})\.?$').firstMatch(parts.first)?.group(1);
  if (track != null) {
    parts.removeAt(0);
    out['trackNo'] = '${int.parse(track)}';
  }
  if (parts.length >= 2) {
    out['artist'] = parts.first;
    out['title'] = parts.sublist(1).join(' - ');
  } else if (parts.length == 1) {
    out['title'] = parts.first.replaceFirst(RegExp(r'^\d{1,3}[.\s]+'), '');
  }
  return out;
}

const _numbers = {'year', 'trackNo', 'discNo'};

bool _validNumber(String v) =>
    v.trim().isEmpty || RegExp(r'^\d{1,4}$').hasMatch(v.trim());

Map<String, String> _draftOf(rust.TagFields f) => {
  'title': f.title ?? '',
  'artist': f.artist ?? '',
  'album': f.album ?? '',
  'albumArtist': f.albumArtist ?? '',
  'year': f.year?.toString() ?? '',
  'genre': f.genre ?? '',
  'trackNo': f.trackNo?.toString() ?? '',
  'discNo': f.discNo?.toString() ?? '',
  'comment': f.comment ?? '',
  'lyrics': f.lyrics ?? '',
};

rust.TagFields _fieldsOf(Map<String, String> d) {
  String? text(String k) => d[k]!.trim().isEmpty ? null : d[k]!.trim();
  int? number(String k) => int.tryParse(d[k]!.trim());
  return rust.TagFields(
    title: text('title'),
    artist: text('artist'),
    album: text('album'),
    albumArtist: text('albumArtist'),
    year: number('year'),
    genre: text('genre'),
    trackNo: number('trackNo'),
    discNo: number('discNo'),
    comment: text('comment'),
    lyrics: text('lyrics'),
  );
}

/// Opens « Modifier les tags » for [item]; the updated entry when saved
/// (or when only the cover changed), null otherwise. A video gets its own
/// fields (director, series, licence) and [frameAt]: where "Capturer
/// l'image" takes its picture.
Future<LibraryItem?> showTagEditor(
  BuildContext context,
  LibraryItem item, {
  Duration? frameAt,
}) => showDialog<LibraryItem>(
  context: context,
  builder: (_) => _TagEditor(item: item, frameAt: frameAt),
);

class _TagEditor extends ConsumerStatefulWidget {
  const _TagEditor({required this.item, this.frameAt});

  final LibraryItem item;
  final Duration? frameAt;

  @override
  ConsumerState<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends ConsumerState<_TagEditor> {
  late LibraryItem _item = widget.item;
  rust.TagSheet? _sheet;
  Map<String, String>? _original;
  final _controllers = <String, TextEditingController>{};
  bool _writeToFile = true;
  bool _rename = false;
  bool _saving = false;
  bool _coverBusy = false;
  bool _coverChanged = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final sheet = await ref.read(tagsApiProvider).get(_item.id);
      if (!mounted) return;
      final draft = _draftOf(sheet.fields);
      setState(() {
        _sheet = sheet;
        _original = draft;
        _writeToFile = sheet.writable;
        for (final e in draft.entries) {
          _controllers[e.key] = TextEditingController(text: e.value)
            ..addListener(() => setState(() {}));
        }
      });
    } catch (e) {
      if (!mounted) return;
      final t = L10n.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(content: Text(tagError(t, e))));
    }
  }

  Map<String, String> get _draft => {
    for (final e in _controllers.entries) e.key: e.value.text,
  };

  bool get _invalid =>
      _sheet == null || _numbers.any((k) => !_validNumber(_draft[k]!));

  String? get _renameTo {
    final d = _draft;
    if (d.isEmpty) return null;
    final artist = d['artist']!.trim(), title = d['title']!.trim();
    return artist.isEmpty || title.isEmpty ? null : '$artist - $title';
  }

  String get _ext {
    final name = _item.path.split(RegExp(r'[\\/]')).last;
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  void _fillFromName() {
    for (final e in tagsFromFileName(_item.path).entries) {
      _controllers[e.key]?.text = e.value;
    }
  }

  Future<void> _save() async {
    if (_invalid || _saving) return;
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.of(context);
    final toFile = (_sheet?.writable ?? false) && _writeToFile;
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(tagsApiProvider)
          .save(
            _item.id,
            _fieldsOf(_draft),
            writeToFile: toFile,
            renameTo: _rename ? _renameTo : null,
          );
      nav.pop(updated);
      messenger?.showSnackBar(
        SnackBar(content: Text(toFile ? t.tagsSavedFile : t.tagsSavedLibrary)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(SnackBar(content: Text(tagError(t, e))));
    }
  }

  Future<void> _cover(String from, {double? atSecs}) async {
    final t = L10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    String? image;
    if (from == 'image') {
      image = await ref.read(coverImagePickerProvider)(t.coverImageType);
      if (image == null) return;
    }
    setState(() => _coverBusy = true);
    try {
      final updated = await ref
          .read(tagsApiProvider)
          .cover(_item.id, from, image: image, atSecs: atSecs);
      if (!mounted) return;
      setState(() {
        _item = updated;
        _coverChanged = true;
      });
      // Applied at once: the newest result replaces the previous one.
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            updated.thumbnail == null ? t.coverRemoved : t.coverUpdated,
          ),
        ),
      );
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(tagError(t, e))));
    } finally {
      if (mounted) setState(() => _coverBusy = false);
    }
  }

  void _close() => Navigator.of(context).pop(_coverChanged ? _item : null);

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final sheet = _sheet;
    final original = _original;
    final renameTo = _renameTo;

    Widget field(String key, String label, {bool wide = false}) {
      final ctrl = _controllers[key]!;
      final bad = _numbers.contains(key) && !_validNumber(ctrl.text);
      final changed = ctrl.text != original![key];
      return SizedBox(
        width: wide ? double.infinity : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              style: MmType.captionStrong.copyWith(
                fontSize: 12,
                color: c.muted,
              ),
            ),
            const SizedBox(height: 5),
            TextField(
              key: ValueKey('tag-$key'),
              controller: ctrl,
              autofocus: key == 'title',
              keyboardType: _numbers.contains(key)
                  ? TextInputType.number
                  : TextInputType.text,
              style: MmType.label.copyWith(color: c.fg, fontSize: 13),
              cursorColor: c.accent,
              onSubmitted: (_) => _save(),
              decoration: _decoration(
                c,
                border: bad ? c.danger : (changed ? c.accent : c.lineStrong),
              ),
            ),
            if (bad) ...[
              const SizedBox(height: 4),
              Text(
                t.invalidNumber,
                style: MmType.caption.copyWith(fontSize: 11.5, color: c.danger),
              ),
            ],
          ],
        ),
      );
    }

    Widget pair(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 14),
        Expanded(child: b),
      ],
    );

    final video = _item.isVideo;
    final form = sheet == null || original == null
        ? const SizedBox(height: 160)
        : video
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field('title', t.fTitle, wide: true),
              const SizedBox(height: 12),
              pair(field('artist', t.fDirector), field('year', t.fYear)),
              const SizedBox(height: 12),
              pair(field('genre', t.fGenre), field('album', t.fSeries)),
              const SizedBox(height: 12),
              field('comment', t.fLicense, wide: true),
              const SizedBox(height: 10),
              Text(
                _rename && renameTo != null
                    ? t.renameNote('$renameTo.$_ext')
                    : t.tagNote,
                style: MmType.caption.copyWith(fontSize: 12, color: c.muted),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field('title', t.fTitle, wide: true),
              const SizedBox(height: 12),
              pair(
                field('artist', t.fArtist),
                field('albumArtist', t.fAlbumArtist),
              ),
              const SizedBox(height: 12),
              pair(field('album', t.fAlbum), field('year', t.fYear)),
              const SizedBox(height: 12),
              pair(field('genre', t.fGenre), field('trackNo', t.fTrack)),
              const SizedBox(height: 12),
              pair(field('discNo', t.fDisc), field('comment', t.fComment)),
              const SizedBox(height: 12),
              Text(
                t.fLyrics,
                style: MmType.captionStrong.copyWith(
                  fontSize: 12,
                  color: c.muted,
                ),
              ),
              const SizedBox(height: 5),
              TextField(
                key: const ValueKey('tag-lyrics'),
                controller: _controllers['lyrics'],
                minLines: 3,
                maxLines: 3,
                style: MmType.label.copyWith(color: c.fg, fontSize: 13),
                cursorColor: c.accent,
                decoration: _decoration(
                  c,
                  hint: t.fLyricsPh,
                  border: _controllers['lyrics']!.text != original['lyrics']
                      ? c.accent
                      : c.lineStrong,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _rename && renameTo != null
                    ? t.renameNote('$renameTo.$_ext')
                    : t.tagNote,
                style: MmType.caption.copyWith(fontSize: 12, color: c.muted),
              ),
            ],
          );

    final coverActions = [
      (
        PhosphorRegular.images,
        t.coverChoose,
        () => _cover('image'),
        false,
        null as String?,
      ),
      (
        PhosphorRegular.downloadSimple,
        t.coverSource,
        (sheet?.hasSourceCover ?? false) ? () => _cover('source') : null,
        false,
        (sheet?.hasSourceCover ?? false) ? null : t.coverNoSource,
      ),
      if (video && widget.frameAt != null)
        (
          PhosphorRegular.camera,
          t.coverFrame(formatClock(widget.frameAt!)),
          () => _cover('frame', atSecs: widget.frameAt!.inMilliseconds / 1000),
          false,
          null as String?,
        ),
      if (_item.thumbnail != null)
        (
          PhosphorRegular.imageBroken,
          t.coverRemove,
          () => _cover('none'),
          true,
          null as String?,
        ),
    ];

    final coverColumn = SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              CoverArt(
                size: 220,
                aspectRatio: video ? 2 / 3 : 1,
                radius: MmRadius.md,
                seed: _item.id,
                imagePath: _item.thumbnail,
                shadow: false,
              ),
              if (_item.thumbnail == null)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Text(
                    t.coverNone,
                    textAlign: TextAlign.center,
                    style: MmType.monoStyle(size: 10.5, color: c.faint),
                  ),
                ),
              if (_coverBusy)
                Positioned.fill(
                  child: Semantics(
                    label: t.coverWorking,
                    child: ColoredBox(
                      color: c.scrim,
                      child: Center(
                        child: CircularProgressIndicator(color: c.fg),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          for (final (icon, label, onTap, danger, why) in coverActions) ...[
            const SizedBox(height: 10),
            Tooltip(
              message: why ?? '',
              child: Pressable(
                onTap: _coverBusy ? null : onTap,
                semanticLabel: label,
                borderRadius: BorderRadius.circular(MmRadius.sm),
                child: Opacity(
                  opacity: onTap == null ? 0.5 : 1,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(MmRadius.sm),
                      border: Border.all(color: c.lineStrong),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 17, color: danger ? c.danger : c.fg),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: MmType.captionStrong.copyWith(
                              fontSize: 12.5,
                              color: danger ? c.danger : c.fg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            t.coverNote,
            style: MmType.caption.copyWith(
              fontSize: 11.5,
              height: 1.45,
              color: c.muted,
            ),
          ),
        ],
      ),
    );

    Widget chip(
      IconData icon,
      String label, {
      required VoidCallback? onTap,
      bool on = false,
    }) => Pressable(
      onTap: onTap,
      selected: on,
      semanticLabel: label,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: on ? c.accentSubtle : c.surface,
            borderRadius: BorderRadius.circular(MmRadius.pill),
            border: Border.all(color: on ? c.chipBorder : c.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: on ? c.chipText : c.fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: MmType.captionStrong.copyWith(
                  fontSize: 12,
                  color: on ? c.chipText : c.fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final writable = sheet?.writable ?? false;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Dialog(
        backgroundColor: c.surface2,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MmRadius.xl),
          side: BorderSide(color: c.lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 14),
                child: Row(
                  children: [
                    Icon(
                      PhosphorRegular.notePencil,
                      size: 22,
                      color: c.accentStrong,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.editTags,
                            style: MmType.title.copyWith(
                              fontSize: 18,
                              color: c.fg,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Tooltip(
                            message: _item.path,
                            child: Text(
                              _item.path,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: MmType.monoStyle(
                                size: 11.5,
                                color: c.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(MmRadius.xs),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        _ext.isEmpty ? '—' : _ext.toUpperCase(),
                        style: MmType.monoStyle(size: 11.5, color: c.muted),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Pressable(
                      onTap: _close,
                      semanticLabel: t.cancel,
                      tooltip: t.cancel,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(PhosphorRegular.x, size: 18, color: c.fg),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    chip(
                      PhosphorRegular.magicWand,
                      t.tagFromName,
                      onTap: sheet == null ? null : _fillFromName,
                    ),
                    chip(
                      PhosphorRegular.pencilSimple,
                      t.tagRename,
                      on: _rename,
                      onTap: renameTo == null
                          ? null
                          : () => setState(() => _rename = !_rename),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      coverColumn,
                      const SizedBox(width: 24),
                      Expanded(child: form),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: Row(
                  children: [
                    if (writable)
                      Expanded(
                        child: Row(
                          children: [
                            Checkbox(
                              value: _writeToFile,
                              activeColor: c.accent,
                              onChanged: (v) =>
                                  setState(() => _writeToFile = v ?? false),
                            ),
                            Flexible(
                              child: Text(
                                t.tagWrite,
                                style: MmType.captionStrong.copyWith(
                                  fontSize: 12.5,
                                  color: c.fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Expanded(
                        child: Text(
                          sheet == null ? '' : t.tagWriteUnsupported,
                          style: MmType.caption.copyWith(
                            fontSize: 12.5,
                            color: c.muted,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: _close,
                      child: Text(
                        t.cancel,
                        style: MmType.labelStrong.copyWith(color: c.fg),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: const Color(0xFF062320),
                      ),
                      onPressed: _invalid || _saving ? null : _save,
                      child: Text(t.save, style: MmType.labelStrong),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _decoration(MmColors c, {required Color border, String? hint}) {
  OutlineInputBorder line(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(MmRadius.sm),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    isDense: true,
    hintText: hint ?? '—',
    hintStyle: MmType.label.copyWith(color: c.faint, fontSize: 13),
    filled: true,
    fillColor: c.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    border: line(border),
    enabledBorder: line(border),
    focusedBorder: line(border == c.lineStrong ? c.accent : border),
  );
}
