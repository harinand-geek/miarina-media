import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../design/mm_icons.g.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import '../src/rust/api/app.dart';

/// What happened, in words (the Tauri app's UPD-10 messages).
String databaseProblemText(L10n t, DatabaseOpen d) => switch (d.issue) {
  'too_new' => t.dbTooNew('${d.found}', '${d.supported}'),
  'upgrade_failed' => t.dbUpgradeFailed(
    d.backup ?? t.dbNoBackup,
    d.detail ?? '',
  ),
  'backup' => t.dbBackupFailed(d.detail ?? ''),
  _ => t.dbOpenFailed(d.dbPath, d.detail ?? ''),
};

/// Shown instead of the app when its database cannot be opened safely: it
/// says why and that nothing was changed; the only action is to close.
class DatabaseProblemApp extends StatelessWidget {
  const DatabaseProblemApp({super.key, required this.open, this.onClose});

  final DatabaseOpen open;

  /// Tests replace leaving the process.
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Miarina Media',
    debugShowCheckedModeBanner: false,
    theme: buildMmTheme(MmColors.dark),
    localizationsDelegates: const [
      L10n.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: L10n.supportedLocales,
    home: _Problem(open: open, onClose: onClose ?? () => exit(1)),
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.open, required this.onClose});

  final DatabaseOpen open;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = MmColors.of(context);
    final t = L10n.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorRegular.database, size: 40, color: c.warning),
                const SizedBox(height: 16),
                Text(
                  t.dbProblemTitle,
                  style: MmType.title.copyWith(fontSize: 22, color: c.fg),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  databaseProblemText(t, open),
                  style: MmType.body.copyWith(color: c.fgSoft, height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: const Color(0xFF062320),
                  ),
                  onPressed: onClose,
                  child: Text(t.windowClose, style: MmType.labelStrong),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
