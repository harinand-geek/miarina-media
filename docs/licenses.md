# Miarina Media — Composants tiers et licences

> État au 2026-10-14 (Phase 2). Revue complète des dépendances Rust/npm et notices de redistribution : Phase 6, avant toute release.

## 1. Outils inclus dans l'installeur Windows (décision 0002, remplace D3)

Ils sont **livrés dans l'installeur** (`<dossier d'installation>\tools\`), avec `THIRD-PARTY-TOOLS.txt`, `LGPL-3.0.txt` et `GPL-3.0.txt`. Au build, chaque archive est vérifiée contre une **empreinte SHA-256 épinglée dans le code** ; une archive différente fait échouer le build. S'ils manquent, l'application propose encore de les télécharger (même vérification, accord explicite de l'utilisateur).

| Composant | Version épinglée | Source | SHA-256 de l'archive | Taille | Licence |
|---|---|---|---|---|---|
| yt-dlp | 2026.08.19 (`yt-dlp.exe`) | github.com/yt-dlp/yt-dlp (release officielle) | `66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a` (publié dans `SHA2-256SUMS`) | 17,8 Mo | Unlicense ; l'exécutable PyInstaller embarque un runtime Python et des bibliothèques sous leurs propres licences (PSF, MIT, BSD, MPL…) |
| QuickJS-NG | 0.17.0 (`qjs.exe`, x86_64) | github.com/quickjs-ng/quickjs (release officielle) | `2aeabf0092c3262d6b2609824418f7dd7ed1f1df939f73b2b15645230cac0d77` (empreinte publiée par GitHub pour l'asset) | 2,1 Mo | MIT (texte livré : `tools\QuickJS-NG-LICENSE.txt`) |
| FFmpeg | n8.1.2-50-g1a748fe2cd, build **LGPL « shared »** (`autobuild-2026-08-31-13-27`) | github.com/BtbN/FFmpeg-Builds | `e9712ffbdb03ef71bbab660c75b835bfe698ef6fad0247c76d8d394a39a3db63` (publié dans `checksums.sha256`) | 70,8 Mo (138 Mo installé) | **LGPL-3.0-or-later** (configuré avec `--enable-version3`, sans `--enable-gpl`) |

Points de conformité :
- FFmpeg est utilisé **comme processus séparé** (pas de liaison avec Miarina Media) ; seuls `ffmpeg.exe`, `ffprobe.exe` et les DLL du dossier `bin/` sont extraits.
- Les sources correspondantes de cette build sont publiées par BtbN/FFmpeg-Builds ; le lien et les textes de licence sont livrés dans `tools\` et devront aussi figurer dans l'écran « À propos / Licences » (Phase 6). Comme nous redistribuons FFmpeg, vérifier avant une version stable que ces sources restent disponibles (sinon les héberger nous-mêmes).
- Encodeurs vérifiés présents dans la build : `libmp3lame` (LGPL), `aac`, `flac`, `libopus`.
- Mise à jour : nouvelles empreintes livrées avec une nouvelle version de l'app ; aucune mise à jour automatique d'exécutables non vérifiés (`yt-dlp -U` n'est jamais appelé).

## 2. Polices et icônes embarquées

| Ressource | Licence |
|---|---|
| Manrope (variable) | SIL Open Font License 1.1 |
| JetBrains Mono | SIL Open Font License 1.1 |
| Material Symbols Rounded | Apache-2.0 |

Client Flutter (`apps/flutter_client`, décision 0007) : Manrope et JetBrains Mono en TTF variables du dépôt google/fonts (OFL 1.1, textes livrés dans `assets/fonts/OFL-*.txt`) ; icônes **Phosphor** 2.1.2 (`@phosphor-icons/web`, MIT, texte dans `assets/icons/LICENSE-Phosphor.txt`), sous-ensemble choisi au build par Flutter. Les fichiers de licence sont déclarés comme ressources pour l'écran « À propos / Licences ».

Client Flutter, moteurs de lecture : `media_kit` / `media_kit_video` (MIT). **libmpv** (Windows, plan R2, 2026-11-21) : la build de 2023 téléchargée par `media_kit_libs_windows_video` (contrôle MD5 seulement, FFmpeg ancien) est **remplacée** à l'assemblage par la build officielle `mpv-dev-x86_64-20261111-git-bcde6b93cc` de shinchiro/mpv-winbuild-cmake, épinglée par SHA-256 (`273c079b…8452`, empreinte publiée par GitHub) dans `examples/fetch_tools.rs --flutter` ; licence **GPL-2.0-or-later** (configuration par défaut de mpv), utilisée sous GPL-3.0, compatible avec la licence GPL-3.0-only de Miarina Media ; sources correspondantes : révision mpv `bcde6b93cc` et scripts de build au tag `20261111` (à recopier sur notre serveur avec chaque version publiée, comme FFmpeg). Lecture vérifiée avec media_kit dans l'app assemblée ; AndroidX Media3 1.11.1 (Apache-2.0) ; `flutter_rust_bridge` 2.13.0 (MIT) ; `window_manager` 0.7.0 / `nativeapi` 0.6.1 (MIT) ; `flutter_riverpod` 3.5 (MIT) ; `go_router` 18.1 et `file_selector` 1.1 (BSD-3-Clause, The Flutter Authors). Licences relevées dans les paquets le 2026-11-19.

## 3. Principales dépendances applicatives (à auditer en Phase 6)

Tauri 2, tokio, reqwest (rustls, aws-lc-rs), pgp/rPGP (vérification des mises à jour de yt-dlp), rusqlite (SQLite bundled, domaine public), zip, sha2, React, Zustand, TanStack Virtual, Tailwind CSS — licences MIT / Apache-2.0 / ISC / BSD majoritairement. Un inventaire automatisé (`cargo about` / `license-checker`) sera produit avant la release.

Ajouts du lot L06 (2026-11-11, vérifiés sur crates.io le jour même) :

| Crate | Version | Licence | Usage | Plateformes |
|---|---|---|---|---|
| `lofty` | 0.25.5 (MSRV 1.89) | MIT OR Apache-2.0 | Lecture et écriture des tags audio (ID3v2, Vorbis, MP4 ilst, APE, RIFF) | Windows, Android |
| `trash` | 5.3.0 (MSRV 1.87) | MIT | « Supprimer le fichier » envoie à la Corbeille | Windows (non compilé pour Android) |

Ajout du lot C3 (Outils PC › Enregistrer l'écran, 2026-11-24, vérifié sur crates.io le jour même) :

| Crate | Version | Licence | Usage | Plateformes |
|---|---|---|---|---|
| `wasapi` | 0.27.0 (MSRV 1.85) | MIT | Son du PC (capture « loopback ») et micro pendant un enregistrement d'écran ; s'appuie sur le crate `windows` 0.62 déjà présent | Windows (non compilé pour Android) |

L'image est filmée par le FFmpeg déjà livré (entrée `gdigrab`) : pas de nouvel outil dans l'installeur.

Ajout du lot L03 (2026-11-11) : `androidx.media3:media3-session` 1.11.1 (Apache-2.0), même famille et même version que `media3-exoplayer` / `media3-ui` déjà embarqués ; fournit `MediaSessionService`, la notification média et les commandes écran verrouillé / Bluetooth (CDC §5).

## 4. Contenus

Miarina Media ne contourne ni DRM, ni paywall, ni authentification : les formats marqués DRM sont exclus des propositions, les pages privées ou nécessitant un compte sont signalées comme non supportées. Les tests de bout en bout utilisent exclusivement des contenus sous licence libre (Blender Foundation, CC BY 3.0).

## 5. Version Flutter Windows (plan R2, 2026-11-21)

Assemblage : `apps/flutter_client/tool/stage_windows.ps1` (après `flutter build windows --release`, jamais une build pointée sur un dossier de test).

- Outils dans `tools\` comme la 0.1.x : yt-dlp, FFmpeg (LGPL), QuickJS-NG, mêmes versions et empreintes (`fetch_tools --flutter`, sans libVLC : le lecteur Flutter utilise libmpv). Notice propre à l'app Flutter : `apps/flutter_client/windows/notices/THIRD-PARTY-TOOLS.txt`, avec `LGPL-3.0.txt`, `GPL-3.0.txt`, `QuickJS-NG-LICENSE.txt` et `MDM-NOTICE.txt` (moteur torrent mdm-torrent, GPL-3.0-or-later).
- Bibliothèques d'exécution Visual C++ (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`) copiées à côté de l'exécutable, depuis le dossier Redist de Visual Studio (« Distributable Code » de la licence Visual Studio) ; chargées depuis ce dossier (vérifié).
- Outil de build ajouté : `sevenz-rust2` 0.25.0 (Apache-2.0, sans fonctionnalités par défaut), dépendance de développement de `download-engine` pour ouvrir l'archive .7z de libmpv ; il n'entre dans aucune application.
- Taille installée : 333,5 Mio (dont FFmpeg ~138 Mio).
- **Code source** : Miarina Media est sous GPL-3.0-only, ainsi que libmpv et mdm-torrent : toute version binaire publiée doit être accompagnée de sa source correspondante. Le dépôt https://github.com/harinand-geek/miarina-media est public (GPL-3.0, vérifié le 2026-11-21) : la notice renvoie à l'étiquette `vVERSION` de la version publiée (à créer au lot R6 sur le commit construit), qui contient aussi les scripts de build (`fetch_tools`, `stage_windows.ps1`, `build_installer.ps1`). Les sources de libmpv et de FFmpeg restent chez leurs projets (liens dans la notice) ; à recopier sur notre serveur si un lien venait à disparaître.
