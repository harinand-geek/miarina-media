import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/router.dart';
import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../../design/widgets/states.dart';
import '../../l10n/app_localizations.dart';
import '../cinema/cinema_widgets.dart' show SectionHeader;
import '../library/groups.dart' show LibraryMessage;
import '../../src/rust/api/library.dart' show LibraryItem;
import 'online_data.dart';
import 'online_obtain.dart' show onlineLocalKey, onlineLocalProvider;
import 'online_widgets.dart';

/// Typing pause before searching YouTube: each search starts the extractor,
/// so it waits for the user to stop rather than following every letter.
const onlineSettle = Duration(milliseconds: 700);

const onlineFieldKey = Key('online-field');

/// The En ligne page (decision 0011): its own field, the recent searches,
/// then YouTube results in the style of the Titres list. The query lives in
/// the route (`?q=`) so Back returns to it.
class OnlineScreen extends ConsumerStatefulWidget {
  const OnlineScreen({super.key, required this.query});

  final String query;

  @override
  ConsumerState<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends ConsumerState<OnlineScreen> {
  late final _field = TextEditingController(text: widget.query);
  Timer? _debounce;
  int _limit = onlinePageSize;

  /// Results shown while « Plus de résultats » loads the longer list.
  List<OnlineTrack>? _shown;

  @override
  void didUpdateWidget(OnlineScreen old) {
    super.didUpdateWidget(old);
    if (old.query.trim() != widget.query.trim()) {
      _limit = onlinePageSize;
      _shown = null;
    }
    if (_field.text.trim() != widget.query.trim()) {
      _field.text = widget.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _go(String value, {bool now = false}) {
    _debounce?.cancel();
    void apply() {
      if (mounted && value.trim() != widget.query.trim()) {
        context.replace(onlineUri(value.trim()));
      }
    }

    if (now) {
      apply();
    } else {
      _debounce = Timer(onlineSettle, apply);
    }
  }

  void _submit(String value) {
    _go(value, now: true);
    ref.read(recentOnlineProvider.notifier).add(value);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final mobile = !ref.watch(desktopShellProvider);
    final pad = mobile ? 16.0 : 32.0;
    final q = widget.query.trim();
    final status = ref.watch(onlineStatusProvider);

    final field = TextField(
      key: onlineFieldKey,
      controller: _field,
      autofocus: q.isEmpty,
      textInputAction: TextInputAction.search,
      style: MmType.body.copyWith(color: c.fg),
      cursorColor: c.accent,
      decoration: InputDecoration(
        isDense: true,
        hintText: t.onlinePlaceholder,
        hintStyle: MmType.body.copyWith(color: c.faint),
        prefixIcon: Icon(PhosphorRegular.globe, size: 20, color: c.muted),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MmRadius.pill),
          borderSide: BorderSide(color: c.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MmRadius.pill),
          borderSide: BorderSide(color: c.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MmRadius.pill),
          borderSide: BorderSide(color: c.accent),
        ),
      ),
      onChanged: _go,
      onSubmitted: _submit,
    );

    final header = mobile
        ? Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              MediaQuery.paddingOf(context).top + 8,
              16,
              8,
            ),
            child: Row(
              children: [
                Pressable(
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.listenHome),
                  semanticLabel: t.back,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(
                      PhosphorRegular.arrowLeft,
                      color: c.fg,
                      size: 22,
                    ),
                  ),
                ),
                Expanded(child: field),
              ],
            ),
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.navOnline, style: MmType.display.copyWith(color: c.fg)),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: field,
                ),
              ],
            ),
          );

    Widget body;
    if (status == OnlineStatus.starting) {
      body = SkeletonList(padding: pad);
    } else if (status == OnlineStatus.noTools) {
      body = OnlineProblemView(
        kind: OnlineFailureKind.tools,
        onRetry: () => ref.invalidate(onlineStatusProvider),
      );
    } else if (q.isEmpty) {
      body = _Recent(pad: pad, onPick: _submit);
    } else {
      final key = (query: q, limit: _limit);
      final results = ref.watch(onlineSearchProvider(key));
      final failure = results.hasError && !results.isLoading
          ? OnlineFailure.of(results.error!)
          : null;
      final tracks = results.value ?? _shown;
      if (results.hasValue) _shown = results.value;
      if (failure != null && failure.kind != OnlineFailureKind.canceled) {
        body = OnlineProblemView(
          kind: failure.kind,
          onRetry: () => ref.invalidate(onlineSearchProvider(key)),
        );
      } else if (tracks == null) {
        body = SkeletonList(padding: pad);
      } else if (tracks.isEmpty) {
        body = LibraryMessage(
          icon: PhosphorRegular.magnifyingGlass,
          title: t.onlineNoResult(q),
          body: '',
        );
      } else {
        final local =
            ref
                .watch(
                  onlineLocalProvider(
                    onlineLocalKey(tracks.map((x) => x.videoId)),
                  ),
                )
                .value ??
            const <String, LibraryItem>{};
        final more =
            !results.isLoading &&
            tracks.length >= _limit &&
            _limit < onlineMaxResults;
        body = ListView(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 24),
          children: [
            for (final tr in tracks)
              OnlineTile(
                track: tr,
                tracks: tracks,
                local: local,
                // A search the user listened from is worth finding again.
                onPlay: () => ref.read(recentOnlineProvider.notifier).add(q),
              ),
            if (results.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: _Spinner()),
              ),
            if (more)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Center(
                  child: Pressable(
                    onTap: () => setState(() => _limit = onlineMaxResults),
                    semanticLabel: t.onlineMore,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        t.onlineMore,
                        style: MmType.labelStrong.copyWith(
                          fontSize: 13,
                          color: c.fgSoft,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(child: body),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: MmColors.of(context).muted,
    ),
  );
}

/// The page before any search: recent searches, or what the page does.
class _Recent extends ConsumerWidget {
  const _Recent({required this.pad, required this.onPick});

  final double pad;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final recent = ref.watch(recentOnlineProvider).value ?? const [];
    if (recent.isEmpty) {
      return LibraryMessage(
        icon: PhosphorRegular.globe,
        title: t.onlineHintTitle,
        body: '',
      );
    }
    final notifier = ref.read(recentOnlineProvider.notifier);
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(t.onlineRecent)),
            Pressable(
              onTap: notifier.clear,
              semanticLabel: t.onlineClearRecent,
              child: Text(
                t.onlineClearRecent,
                style: MmType.label.copyWith(fontSize: 13, color: c.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final q in recent)
          Pressable(
            onTap: () => onPick(q),
            semanticLabel: q,
            borderRadius: BorderRadius.circular(MmRadius.md),
            hoverColor: c.cardHover,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    PhosphorRegular.clockCounterClockwise,
                    size: 18,
                    color: c.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      q,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MmType.body.copyWith(color: c.fg),
                    ),
                  ),
                  Pressable(
                    onTap: () => notifier.remove(q),
                    semanticLabel: t.onlineRemoveRecent(q),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(PhosphorRegular.x, size: 16, color: c.muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
