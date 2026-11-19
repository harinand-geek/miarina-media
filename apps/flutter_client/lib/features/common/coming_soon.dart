import 'package:material_ui/material_ui.dart';

import '../../design/mm_icons.g.dart';
import '../../design/tokens.dart';
import '../../l10n/app_localizations.dart';

/// Placeholder for a screen of the handoff that is not built yet. It says so
/// plainly; it never shows sample data or controls that do nothing.
class ComingSoon extends StatelessWidget {
  const ComingSoon({super.key, required this.screenId});

  final String screenId;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PhosphorRegular.hourglassSimple,
                size: 40,
                color: c.faintIcon,
              ),
              const SizedBox(height: 16),
              Text(
                t.comingSoonTitle,
                style: MmType.title.copyWith(color: c.fg),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                t.comingSoonBody,
                style: MmType.bodySm.copyWith(color: c.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(screenId, style: MmType.monoStyle(color: c.faint)),
            ],
          ),
        ),
      ),
    );
  }
}
