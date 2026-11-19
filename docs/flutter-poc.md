# Preuve de concept Flutter — rapport (Phase 1 de la décision 0007)

Date : 2026-11-19 · Code : `apps/flutter_client/` · Décision : [0007](decisions/0007-flutter-migration.md)

Objet : vérifier, avant de construire les écrans, que les parties les plus risquées de la migration fonctionnent en Flutter sur Windows et Android. L'écran de test (`lib/poc/poc_app.dart`) n'est pas un écran du produit ; il sera remplacé par les écrans de la maquette `design/design_handoff_lecture_ecouter/`.

## Environnement

| Élément | Valeur |
|---|---|
| Flutter / Dart | 3.50.0 stable / 3.13 (`C:\apps\flutter`) |
| Windows | Windows 11 Pro 10.0.22000, Intel Core i5-8300H, 16 Go, Visual Studio Build Tools 2026 |
| Android | émulateur `voakajy_test` (Android 15, x86_64). **Pas de mesure sur téléphone réel** |
| Lecture Windows | `media_kit` 1.2.6 + `media_kit_video` 2.0.1 + `media_kit_libs_windows_video` 1.0.11 (libmpv) |
| Lecture Android | Media3 1.11.1 (même version que l'app Tauri publiée), `PlaybackService` + `MediaController` |
| Cœur Rust | `flutter_rust_bridge` 2.13.0, crate `apps/flutter_client/rust` (`miarina_bridge`) dans l'espace de travail Cargo |

## Résultats

| Critère (0007) | Windows | Android (émulateur) | Preuve |
|---|---|---|---|
| Lecture MP3 et FLAC, position, pause, volume | oui | oui | `integration_test/engine_contract_test.dart` |
| Lecture MP4, image affichée dans Flutter, déplacement, vitesse | oui (1280×720) | oui (1280×720) | idem + captures |
| MKV : 2 pistes audio, changement de piste | oui | oui | idem |
| Sous-titres intégrés (activer, couper, rétablir) et externes (.srt) | oui (rendus par libmpv) | oui (rendus par Flutter au-dessus de la texture) | idem + captures |
| Répéter un titre, fichier introuvable → erreur sans blocage | oui | oui | idem |
| Lecture en arrière-plan, notification média, session active | sans objet | oui : service au premier plan `mediaPlayback`, notification `MediaStyle`, session active | `dumpsys` après retour à l'écran d'accueil |
| Appel du cœur Rust (`crates/storage`) depuis Dart | oui, y compris une **copie** de la vraie bibliothèque : schéma v9, 17 éléments | oui (base neuve migrée, écrite, relue) | `integration_test/rust_bridge_test.dart` |
| WebView qui détecte un média | oui : WebView2 dans la fenêtre Flutter, détection `media_core::detect` (mêmes règles que la 0.1.11) | non testé (le navigateur Android reste la WebView native, déjà en Kotlin) | `integration_test/webview_spike_test.dart` |

Le même test de contrat (`engine_contract_test.dart`) passe sur les deux moteurs : l'interface ne dépend d'aucun moteur.

## Mesures relevées

Une seule machine, peu d'essais : ce sont des ordres de grandeur, pas des objectifs.

| Mesure | Résultat | Méthode |
|---|---|---|
| Windows, dossier release | 72,8 Mo (libmpv 28,4 ; moteur Flutter 20,3 ; ANGLE 7,6 ; d3dcompiler 4,7 ; SwiftShader 4,6) | taille des fichiers de `build\windows\x64\runner\Release` avant ajout du cœur Rust |
| Windows, fenêtre visible | 1,87 s puis 1,41 s (2 essais) | `Start-Process` → `MainWindowHandle ≠ 0` |
| Windows, lecture MKV 1080p H.264 + sous-titres externes | 318–320 Mo working set, ~323 Mo privés, CPU 2,9–5,4 % (tous cœurs) | `Get-Process`, ~6 s après l'ouverture |
| Android, APK release ARM64 | 15,9 Mo | sans le cœur Rust ni yt-dlp/FFmpeg (la 0.1.11 ARM64 fait 64 Mo avec eux) : pas comparable tel quel |
| Android, démarrage à froid (release x86_64, émulateur) | 1 515 ms | `am start -W` (TotalTime), 1 essai |
| Android, mémoire au repos (release, émulateur) | 69 Mo PSS | `dumpsys meminfo` |

Comparaison avec la 0.1.11 (`docs/performance.md`) : à faire **à contenu identique** (même vidéo, même durée) ; la mesure de la 0.1.11 portait sur une vidéo 240p VP9, celle-ci sur du 1080p H.264.

## Constats et décisions prises

1. **libmpv de `media_kit` daté du 2023-09-24** (`mpv-dev-x86_64-20230924-git-652a1dd.7z`, téléchargé par `media_kit_libs_windows_video`). Acceptable pour la preuve de concept, **pas pour une version publique** (trois ans de correctifs FFmpeg manquants). Avant la première version Flutter publique : fournir notre propre build libmpv récente (même interface `libmpv-2.dll`) et documenter sa provenance dans `docs/licenses.md`. Licence : l'app est GPL-3.0, une build GPL de mpv/FFmpeg est compatible ; obligations de fourniture des sources à respecter.
2. **Android : Media3 ne dessine pas les sous-titres dans la texture.** Les répliques (`onCues`) sont envoyées à Dart et dessinées au-dessus de l'image (`Media3Engine.buildVideoView`). Le style final suivra la maquette (réglages taille et décalage du lot Cinéma).
3. **Android : la taille de l'image n'est connue qu'après l'arrivée des images sur une surface.** L'interface n'attache la surface que si le moteur annonce une image : la taille est donc lue d'abord sur la piste vidéo. Test de non-régression dans `engine_contract_test.dart`.
4. **Windows : `media_kit` renvoie « auto » pour une piste choisie par mpv.** L'adaptateur lit `current-tracks/audio/id` et `current-tracks/sub/id`, cohérents avec la liste des pistes, y compris pour un sous-titre externe.
5. **Navigateur Windows : aucun plugin WebView Flutter n'expose les réponses réseau.** La voie retenue est la même que la 0.1.11 : WebView2 pilotée depuis Rust (`webview2-com` 0.39.1), fenêtre enfant de la fenêtre Flutter. Dans Flutter 3.50, l'appel `sync` du pont s'exécute sur le fil de la fenêtre : les événements WebView2 passent par la boucle de messages de Flutter, sans fil dédié. Restent à faire : position et taille suivant la mise en page, masquage sous les menus Flutter (même contrainte qu'aujourd'hui), onglets, historique.
6. **Flutter 3.50 définit `RepeatMode` dans ses widgets** : le contrat utilise `RepeatSetting`.
7. **Moteur choisi par plateforme** : `media_kit_libs_windows_video` seulement (pas `media_kit_libs_video`), pour ne pas embarquer libmpv dans l'APK.
8. Profil release Cargo `panic = "abort"` (hérité de l'espace de travail) : une panique Rust arrête l'app au lieu de lever une exception Dart. Le code du pont renvoie des `Result` ; à garder en tête en phase 2.

## Limites et points ouverts

- **Rien n'a été mesuré sur le téléphone de référence** (Redmi Note 10 Pro, Android 13). À faire : lecture, écran verrouillé, Bluetooth, casque, coupure par appel, restrictions batterie MIUI, mémoire et démarrage réels.
- **Test instable observé une fois** sur Windows : un MP3 « en lecture » sans durée ni position pendant 10 s, au premier test d'une exécution complète ; non reproduit sur les 6 exécutions suivantes. À instrumenter en phase 2 (journal libmpv).
- Comparaison mémoire et démarrage avec la 0.1.11 à contenu identique : à faire.
- Le cœur Rust n'est pas encore dans l'APK mesuré (taille à remesurer).
- L'écran de test n'a ni accessibilité ni design ; aucun écran de la maquette n'est encore construit.

## Suite (phase 2 : fondations)

1. Kit de design Flutter : tokens `--mm-*` de `theme.css`, polices Manrope et JetBrains Mono, police d'icônes Phosphor générée (`docs/icon-system.md`), mouvements du handoff.
2. Navigation (shell Windows à barre latérale + barre de lecture ; shell Android à onglets + mini-lecteur), i18n FR/EN.
3. Pont Rust complet pour la bibliothèque, les playlists, l'historique et la reprise (mêmes tables que la 0.1.x).
4. Build libmpv récente pour Windows.
5. Puis les écrans Écouter dans l'ordre du handoff.
