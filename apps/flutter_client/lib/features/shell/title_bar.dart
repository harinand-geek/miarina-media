import 'package:material_ui/material_ui.dart';
import 'package:window_manager/window_manager.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../design/widgets/logo.dart';
import '../../l10n/app_localizations.dart';

/// Windows title bar of the mockup: 40 px, logo, central search, window
/// buttons. The empty area drags the window; double-click maximizes.
class TitleBar extends StatefulWidget {
  const TitleBar({super.key, required this.sideWidth});

  final double sideWidth;

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
            child: DragToMoveArea(
              child: GestureDetector(
                onDoubleTap: _toggleMaximize,
                behavior: HitTestBehavior.translucent,
                child: Row(
                  children: [
                    SizedBox(
                      width: widget.sideWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const MiarinaLogo(),
                            if (widget.sideWidth > 100) ...[
                              const SizedBox(width: 10),
                              Text(
                                t.appTitle,
                                style: MmType.heading.copyWith(
                                  fontSize: 13,
                                  color: c.fg,
                                  fontWeight: FontWeight.w800,
                                  fontVariations: const [
                                    FontVariation.weight(800),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: _SearchPill(
                          placeholder: t.searchPlaceholder,
                          tooltip: t.comingSoonShort,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

/// Global search (Ctrl K) comes with the W-02 screen; until then the field is
/// shown as in the design but inert, and says so.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.placeholder, required this.tooltip});

  final String placeholder;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 420,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(MmRadius.pill),
          border: Border.all(color: c.line),
        ),
        child: Row(
          children: [
            Icon(PhosphorRegular.magnifyingGlass, size: 16, color: c.faint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                placeholder,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: MmType.caption.copyWith(fontSize: 12.5, color: c.faint),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                border: Border.all(color: c.lineStrong),
                borderRadius: BorderRadius.circular(MmRadius.xs),
              ),
              child: Text(
                'Ctrl K',
                style: MmType.monoStyle(size: 11, color: c.faint),
              ),
            ),
          ],
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
