# Spike — Android sur émulateur (Phase 4)

Date : 2026-10-14 · Environnement : émulateur `voakajy_test` (Android 15 / API 35, image Google APIs **x86_64**), Android System WebView 124, NDK 27.1, JDK 17, Tauri 2.12.3, build **debug**.

> Un émulateur x86_64 ne remplace pas un appareil physique (CLAUDE.md) : mémoire, batterie, débit réel, comportement en arrière-plan, constructeurs (ARM, surcouches) **non validés** ici.

## Résultats

| # | Question | Résultat |
|---|---|---|
| 1 | Le cœur Rust partagé compile-t-il pour Android ? | ✅ `x86_64-linux-android` : storage (SQLite bundled), resource-manager, download-engine (reqwest/rustls, aws-lc), library, media-core — **sans modification**. Seul le code desktop a dû être isolé (voir « Adaptations »). |
| 2 | L'app démarre-t-elle avec le vrai backend ? | ✅ shell mobile approuvé, SQLite créé, gestionnaire et bibliothèque démarrés. |
| 3 | HTTPS | ❌ puis ✅ : `rustls-platform-verifier` **panique** s'il n'est pas initialisé côté JVM. Corrigé : initialisation JNI au démarrage + composant Kotlin officiel (magasin de certificats Android). |
| 4 | Analyse + téléchargement HTTP direct | ✅ fichier Wikimedia 240p : analyse (29 Mo), téléchargement complet, **30 448 117 octets** (taille identique à celle observée sous Windows), affiché dans « Done ». |
| 5 | Emplacement du fichier | ⚠️ `Android/data/org.miarina.media/files/Movies/Miarina/` (stockage **privé** de l'app : invisible pour la galerie, supprimé à la désinstallation). → MediaStore requis pour Films/Téléchargements publics. |
| 6 | Lecture `<video>` via le protocole d'asset | ❌ `PIPELINE_ERROR_READ: FFmpegDemuxer: data source error` : la lecture en flux (requêtes Range) ne passe pas par l'interception Android. → **lecteur natif Media3** (déjà prévu, architecture §7). Le lecteur mobile affiche « Pause » au lieu d'une erreur : à corriger. |
| 7 | Miniatures / ffprobe / yt-dlp | ⛔ non disponibles (binaires Windows) ; la bibliothèque fonctionne sans métadonnées enrichies. Extracteur Android : toujours à évaluer (`android-feasibility.md`). |
| 8 | Affichage | ⚠️ Android 15 impose l'edge-to-edge : la barre d'état recouvre l'en-tête → gérer les insets (Kotlin ou CSS). Barre de navigation encore Home/Downloads/Library/Settings (M5 à appliquer). |
| 9 | Navigateur intégré | non commencé (WebView native via plugin Kotlin). Les commandes `browser_*` répondent « indisponible » sur mobile. |

## Adaptations faites pour compiler

- `browser` : module découpé en `desktop.rs` (fenêtre + webviews, inchangé) et `mobile.rs` (mêmes commandes, réponse « indisponible ») — `generate_handler!` ne gère pas `cfg` par commande.
- Sélecteur de dossier (`blocking_pick_folder`) réservé au desktop ; sur mobile : `unsupported_platform` (le stockage passera par SAF/MediaStore).
- `android_tls.rs` : `rustls_platform_verifier::android::init_with_env` à partir de `ndk_context` ; dépendances Android `jni` 0.22.4, `ndk-context` 0.1.1, `rustls-platform-verifier` 0.7.1 — **déjà présentes** dans le lockfile.
- Gradle : dépôt Maven officiel rustls (GitHub) restreint au groupe `org.rustls`, `org.rustls:rustls-platform-verifier:0.2.0` (= `rustls-platform-verifier-android` du lockfile), règle Proguard JNI.

## Outillage

- `tauri android build` échoue sous Windows sans **mode développeur** (lien symbolique vers la `.so`). Contournement utilisé : compiler la `.so` via Tauri, la copier dans `jniLibs/x86_64`, puis `gradlew assembleX86_64Debug -x rustBuildX86_64Debug`. Activer le mode développeur rétablit le flux standard (`tauri android dev`).
- APK debug x86_64 : 231 Mo (symboles de débogage de la `.so` : 235 Mo). **Taille release non mesurée.**
- Premier build Gradle : ~14 min (téléchargement de Gradle/AGP) ; suivants : quelques minutes.

## Suite proposée (Android)

1. ✅ Insets edge-to-edge + navigation M5 (Home / Browser / Downloads / Library, Settings dans Home) — commit 64018a5.
2. Plugin Kotlin « media » : ✅ lecteur Media3 sous les contrôles React (2026-10-18, vérifié sur émulateur : vidéo et audio, pause, ±10 s, vitesse, reprise de position, pause vidéo en arrière-plan, audio qui continue ; question 6 ci-dessus résolue) ; à faire : enregistrement MediaStore (Films / Musique), miniatures et durées (MediaMetadataRetriever), partage et « ouvrir avec ».
3. Plugin Kotlin « browser » : WebView native, détection via `shouldInterceptRequest` + relevé DOM, bouton flottant (M1/M3).
4. Build release arm64 + mesure de taille ; validation sur appareil physique.
