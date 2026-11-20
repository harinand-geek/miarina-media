import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fonts and icons bundled with the app (OFL 1.1, MIT): their notices are
/// shipped as assets and listed in Settings › About › Component licenses,
/// next to the packages' own.
bool _licensesAdded = false;

void registerAssetLicenses() {
  if (_licensesAdded) return;
  _licensesAdded = true;
  LicenseRegistry.addLicense(() async* {
    for (final (names, asset) in const [
      (['Manrope (font)'], 'assets/fonts/OFL-Manrope.txt'),
      (['JetBrains Mono (font)'], 'assets/fonts/OFL-JetBrainsMono.txt'),
      (['Phosphor Icons'], 'assets/icons/LICENSE-Phosphor.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(
        names,
        await rootBundle.loadString(asset),
      );
    }
  });
}
