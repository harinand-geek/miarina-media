# Miarina Media — client Flutter

Migration de l'interface vers Flutter (décision [0007](../../docs/decisions/0007-flutter-migration.md)). État : **phase 2, fondations** ([preuve de concept](../../docs/flutter-poc.md), [correspondance maquette ↔ code](../../docs/flutter-implementation-map.md)). L'app Tauri (`apps/client`) reste celle qui est publiée.

## Contenu

- `lib/engine/` : contrat `MediaEngine` et ses adaptateurs (`MpvEngine` Windows via libmpv, `Media3Engine` Android).
- `android/app/src/main/kotlin/org/miarina/media/` : `PlaybackService` (session Media3, arrière-plan) et `Media3EnginePlugin` (pont vers Dart, texture vidéo).
- `rust/` : crate `miarina_bridge` (flutter_rust_bridge) vers le cœur Rust partagé (`crates/`).
- `lib/src/rust/` et `rust/src/frb_generated.rs` : code généré, ne pas modifier (`flutter_rust_bridge_codegen generate`).
- `lib/design/` : tokens, thème, composants de base ; `mm_icons.g.dart` est généré par `dart run tool/gen_icons.dart <@phosphor-icons/web>`.
- `lib/features/` : shell (Windows, Android), lecture (file d'attente, minuteur, égaliseur), En lecture (paroles, file, son ; lecteur Android), bibliothèque.
- Capture automatisée sans saisie : `--dart-define=MM_START_ROUTE=/now?tab=lyrics` fixe l'écran de départ.
- `lib/l10n/` : textes FR (référence) et EN ; les `app_localizations*.dart` sont générés par `flutter pub get`.

## Prérequis

Flutter 3.50 stable, Rust (cibles `x86_64-pc-windows-msvc` et `*-linux-android`), Visual Studio Build Tools (C++), SDK et NDK Android, `flutter_rust_bridge_codegen` 2.13.0.

## Commandes

En développement, faire pointer l'app vers un dossier de travail ou une **copie** d'un dossier de données 0.1.x, jamais vers celui de l'app Tauri en service :

```powershell
flutter run -d windows --dart-define=MM_DATA_DIR=<dossier>
```

```powershell
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release --target-platform android-arm64
```

Tests d'intégration (vrais moteurs). Les médias de test sont générés avec FFmpeg (MP3, FLAC, MP4, MKV à deux pistes audio et sous-titres, `externe.srt`, et `chanson.flac` avec `chanson.lrc` à côté), voir le rapport :

```powershell
flutter test integration_test -d windows `
  --dart-define=POC_MEDIA=<dossier des médias> `
  --dart-define=POC_WORK=<dossier inscriptible> `
  --dart-define=POC_DB=<copie d'une base miarina.db>   # facultatif, jamais la base en service
```

Sur Android, les médias doivent être dans le stockage de l'app (`run-as org.miarina.media.poc cp …`), et `POC_MEDIA` pointe vers `/data/user/0/org.miarina.media.poc/files/poc-media`.

L'identifiant Android de test est `org.miarina.media.poc` : il ne remplace pas l'app `org.miarina.media` installée.
