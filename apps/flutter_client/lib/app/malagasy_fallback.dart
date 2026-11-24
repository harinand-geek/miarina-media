import 'package:material_ui/material_ui.dart';

/// Flutter has no Malagasy for its own widgets (dialog buttons, date and
/// time pickers, text selection menu): with the app in Malagasy they use
/// French, the app's other language there. The app's texts are Malagasy
/// (app_mg.arb).
final malagasyFallbacks = <LocalizationsDelegate<dynamic>>[
  for (final d in GlobalMaterialLocalizations.delegates) _Fallback(d),
];

class _Fallback extends LocalizationsDelegate<dynamic> {
  const _Fallback(this.inner);

  final LocalizationsDelegate<dynamic> inner;

  /// Looked up under the real type (MaterialLocalizations…).
  @override
  Type get type => inner.type;

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'mg';

  @override
  Future<dynamic> load(Locale locale) => inner.load(const Locale('fr'));

  @override
  bool shouldReload(_Fallback old) => false;
}

/// The locale for intl's DateFormat and NumberFormat, which have no
/// Malagasy data (they throw on 'mg'): French dates and numbers instead.
String intlLocale(String locale) =>
    locale == 'mg' || locale.startsWith('mg_') ? 'fr' : locale;

/// [intlLocale] of the interface language.
String intlLocaleOf(BuildContext context) =>
    intlLocale(Localizations.localeOf(context).toString());
