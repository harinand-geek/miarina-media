# Miarina Media — client Flutter

Migration de l'interface vers Flutter (décision [0007](../../docs/decisions/0007-flutter-migration.md)). État : **preuve de concept** ([rapport](../../docs/flutter-poc.md)). L'app Tauri (`apps/client`) reste celle qui est publiée.

## Contenu

- `lib/engine/` : contrat `MediaEngine` et ses adaptateurs (`MpvEngine` Windows via libmpv, `Media3Engine` Android).
- `android/app/src/main/kotlin/org/miarina/media/` : `PlaybackService` (session Media3, arrière-plan) et `Media3EnginePlugin` (pont vers Dart, texture vidéo).
- `rust/` : crate `miarina_bridge` (flutter_rust_bridge) vers le cœur Rust partagé (`crates/`).
- `lib/src/rust/` et `rust/src/frb_generated.rs` : code généré, ne pas modifier (`flutter_rust_bridge_codegen generate`).
- `lib/poc/` : écran de test, remplacé par les écrans de la maquette en phase 2.

## Prérequis

Flutter 3.50 stable, Rust (cibles `x86_64-pc-windows-msvc` et `*-linux-android`), Visual Studio Build Tools (C++), SDK et NDK Android, `flutter_rust_bridge_codegen` 2.13.0.

## Commandes

```powershell
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release --target-platform android-arm64
```

Tests d'intégration (vrais moteurs). Les médias de test sont générés avec FFmpeg (MP3, FLAC, MP4, MKV à deux pistes audio et sous-titres, `externe.srt`), voir le rapport :

```powershell
flutter test integration_test -d windows `
  --dart-define=POC_MEDIA=<dossier des médias> `
  --dart-define=POC_WORK=<dossier inscriptible> `
  --dart-define=POC_DB=<copie d'une base miarina.db>   # facultatif, jamais la base en service
```

Sur Android, les médias doivent être dans le stockage de l'app (`run-as org.miarina.media.poc cp …`), et `POC_MEDIA` pointe vers `/data/user/0/org.miarina.media.poc/files/poc-media`.

L'identifiant Android de test est `org.miarina.media.poc` : il ne remplace pas l'app `org.miarina.media` installée.
