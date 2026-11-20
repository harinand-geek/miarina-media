import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miarina_media/app/database_problem.dart';
import 'package:miarina_media/src/rust/api/app.dart';

DatabaseOpen problem(
  String issue, {
  String? backup,
  String? detail,
  int found = 0,
  int supported = 0,
}) => DatabaseOpen(
  issue: issue,
  dbPath: r'C:\Users\Hery\AppData\Roaming\org.miarina.media\miarina.db',
  from: 9,
  to: 10,
  found: found,
  supported: supported,
  backup: backup,
  detail: detail,
);

void main() {
  Future<int> pump(WidgetTester tester, DatabaseOpen open) async {
    var closed = 0;
    tester.platformDispatcher.localesTestValue = const [Locale('fr')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(
      DatabaseProblemApp(open: open, onClose: () => closed++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fermer'));
    return closed;
  }

  testWidgets('a library from a newer version is left untouched', (
    tester,
  ) async {
    final closed = await pump(
      tester,
      problem('too_new', found: 11, supported: 10),
    );
    expect(find.text('Votre bibliothèque n’a pas été ouverte'), findsOneWidget);
    expect(find.textContaining('schéma 11'), findsOneWidget);
    expect(find.textContaining('s’arrête au schéma 10'), findsOneWidget);
    expect(
      find.textContaining('Vos données n’ont pas été modifiées'),
      findsOneWidget,
    );
    expect(closed, 1);
  });

  testWidgets('a failed upgrade names the copy kept', (tester) async {
    await pump(
      tester,
      problem(
        'upgrade_failed',
        backup: r'C:\Data\backups\miarina-schema9-1.db',
        detail: 'disk full',
      ),
    );
    expect(
      find.textContaining(r'Copie de sauvegarde : C:\Data\backups'),
      findsOneWidget,
    );
    expect(find.textContaining('Détail : disk full'), findsOneWidget);
  });
}
