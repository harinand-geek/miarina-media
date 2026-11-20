import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../app/router.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/logo.dart';
import '../../design/widgets/pressable.dart';
import '../../l10n/app_localizations.dart';
import '../search/search_screen.dart' show searchUri;

/// Windows title bar of the mockup: 40 px, logo, central search, window
/// buttons. The empty area drags the window; double-click maximizes.
class TitleBar extends StatefulWidget {
  const TitleBar({
    super.key,
    required this.sideWidth,
    required this.location,
    this.search = true,
  });

  /// False on the first-launch screens.
  final bool search;

  final double sideWidth;

  /// Current route, so the search field can follow it.
  final String location;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> {
  final Window? _window = _currentWindow();

  // Null where no native window exists (widget tests).
  static Window? _currentWindow() {
    try {
      return WindowManager.instance.getCurrent();
    } catch (_) {
      return null;
    }
  }

  ListenerId? _listener;
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    final w = _window;
    if (w != null) {
      _maximized = w.isMaximized;
      _listener = w.addListener((e) {
        if (!mounted) return;
        if (e is WindowMaximizedEvent) setState(() => _maximized = true);
        if (e is WindowRestoredEvent) {
          setState(() => _maximized = w.isMaximized);
        }
      });
    }
  }

  @override
  void dispose() {
    final id = _listener;
    if (id != null) _window?.removeListener(id);
    super.dispose();
  }

  void _toggleMaximize() {
    final w = _window;
    if (w == null) return;
    w.isMaximized ? w.restore() : w.maximize();
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.sidebar,
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                // The empty title bar moves the window; the search field
                // sits above it so typing never drags.
                Positioned.fill(
                  child: DragToMoveArea(
                    child: GestureDetector(
                      onDoubleTap: _toggleMaximize,
                      behavior: HitTestBehavior.translucent,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IgnorePointer(
                      child: SizedBox(
                        width: widget.sideWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              const MiarinaLogo(),
                              if (widget.sideWidth > 100) ...[
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    t.appTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: MmType.heading.copyWith(
                                      fontSize: 13,
                                      color: c.fg,
                                      fontWeight: FontWeight.w800,
                                      fontVariations: const [
                                        FontVariation.weight(800),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: widget.search
                            ? SearchField(location: widget.location)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _WindowButton(
            icon: PhosphorRegular.minus,
            label: t.windowMinimize,
            onTap: () => _window?.minimize(),
          ),
          MaximizeButtonArea(
            child: _WindowButton(
              icon: _maximized
                  ? PhosphorRegular.cornersIn
                  : PhosphorRegular.square,
              iconSize: 13,
              label: _maximized ? t.windowRestore : t.windowMaximize,
              onTap: _toggleMaximize,
            ),
          ),
          _WindowButton(
            icon: PhosphorRegular.x,
            label: t.windowClose,
            close: true,
            onTap: () => _window?.close(),
          ),
        ],
      ),
    );
  }
}

/// Focus of the title bar search field; Ctrl K anywhere in the window
/// requests it.
final searchFocusProvider = Provider<FocusNode>((ref) {
  final node = FocusNode(debugLabel: 'search');
  ref.onDispose(node.dispose);
  return node;
});

/// Global search of the title bar (W-02): typing shows the results screen
/// (after 200 ms without a key), Esc clears it and returns to the screen
/// the search started from.
class SearchField extends ConsumerStatefulWidget {
  const SearchField({super.key, required this.location});

  final String location;

  @override
  ConsumerState<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<SearchField> {
  final _text = TextEditingController();
  Timer? _debounce;
  String? _before;

  bool get _onSearch => widget.location == Routes.search;

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    // Leaving the results (sidebar, back) empties the field.
    if (!_onSearch && old.location == Routes.search) {
      _text.clear();
      _before = null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _show(String value) {
    final router = GoRouter.of(context);
    if (value.trim().isEmpty) {
      if (_onSearch) router.go(_before ?? Routes.listenHome);
      return;
    }
    if (!_onSearch) _before = widget.location;
    router.go(searchUri(value));
  }

  void _escape() {
    _debounce?.cancel();
    _text.clear();
    ref.read(searchFocusProvider).unfocus();
    if (_onSearch) GoRouter.of(context).go(_before ?? Routes.listenHome);
  }

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    final focus = ref.watch(searchFocusProvider);
    return SizedBox(
      width: 420,
      height: 30,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _escape},
        child: ListenableBuilder(
          listenable: focus,
          builder: (context, _) => Container(
            padding: const EdgeInsets.only(left: 12, right: 6),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(MmRadius.pill),
              border: Border.all(color: focus.hasFocus ? c.accent : c.line),
            ),
            child: Row(
              children: [
                Icon(PhosphorRegular.magnifyingGlass, size: 16, color: c.faint),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _text,
                    focusNode: focus,
                    style: MmType.caption.copyWith(fontSize: 12.5, color: c.fg),
                    cursorColor: c.accent,
                    cursorHeight: 14,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration.collapsed(
                      hintText: t.searchPlaceholder,
                      hintStyle: MmType.caption.copyWith(
                        fontSize: 12.5,
                        color: c.faint,
                      ),
                    ),
                    onChanged: (v) {
                      _debounce?.cancel();
                      _debounce = Timer(
                        const Duration(milliseconds: 200),
                        () => mounted ? _show(v) : null,
                      );
                    },
                    onSubmitted: (v) {
                      _debounce?.cancel();
                      _show(v);
                    },
                  ),
                ),
                ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) => _text.text.isEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: c.lineStrong),
                            borderRadius: BorderRadius.circular(MmRadius.xs),
                          ),
                          child: Text(
                            'Ctrl K',
                            style: MmType.monoStyle(size: 11, color: c.faint),
                          ),
                        )
                      : Pressable(
                          onTap: _escape,
                          tooltip: t.searchClear,
                          semanticLabel: t.searchClear,
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: Icon(
                              PhosphorRegular.x,
                              size: 14,
                              color: c.muted,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.close = false,
    this.iconSize = 16,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool close;
  final double iconSize;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final hoverBg = widget.close ? const Color(0xFFC8423B) : c.surface2;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: MmMotion.of(context).hover,
            width: 46,
            height: 40,
            color: _hover ? hoverBg : Colors.transparent,
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              size: widget.iconSize,
              color: _hover && widget.close ? Colors.white : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}
