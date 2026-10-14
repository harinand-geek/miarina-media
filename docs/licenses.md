# Miarina Media — Composants tiers et licences

> État au 2026-10-14 (Phase 2). Revue complète des dépendances Rust/npm et notices de redistribution : Phase 6, avant toute release.

## 1. Outils téléchargés au premier besoin (décision D3)

Ils ne sont **pas embarqués** dans l'installeur. L'utilisateur donne son accord explicite (écran « This page needs the media tools » ou Settings › Downloads › Media tools). Chaque archive est vérifiée contre une **empreinte SHA-256 épinglée dans le code** avant toute exécution ; une archive différente est rejetée.

| Composant | Version épinglée | Source | SHA-256 de l'archive | Taille | Licence |
|---|---|---|---|---|---|
| yt-dlp | 2026.08.19 (`yt-dlp.exe`) | github.com/yt-dlp/yt-dlp (release officielle) | `66674953fe251b89f4d08c5f0e35e0728679bd67ab3d7d05c0562af101dd3e7a` (publié dans `SHA2-256SUMS`) | 17,8 Mo | Unlicense ; l'exécutable PyInstaller embarque un runtime Python et des bibliothèques sous leurs propres licences (PSF, MIT, BSD, MPL…) |
| FFmpeg | n8.1.2-50-g1a748fe2cd, build **LGPL « shared »** (`autobuild-2026-08-31-13-27`) | github.com/BtbN/FFmpeg-Builds | `e9712ffbdb03ef71bbab660c75b835bfe698ef6fad0247c76d8d394a39a3db63` (publié dans `checksums.sha256`) | 70,8 Mo (138 Mo installé) | **LGPL-3.0-or-later** (configuré avec `--enable-version3`, sans `--enable-gpl`) |

Points de conformité :
- FFmpeg est utilisé **comme processus séparé** (pas de liaison avec Miarina Media) ; seuls `ffmpeg.exe`, `ffprobe.exe` et les DLL du dossier `bin/` sont extraits.
- Les sources correspondantes de cette build sont publiées par BtbN/FFmpeg-Builds ; le lien et le texte de licence devront figurer dans l'écran « À propos / Licences » (Phase 6).
- Encodeurs vérifiés présents dans la build : `libmp3lame` (LGPL), `aac`, `flac`, `libopus`.
- Mise à jour : nouvelles empreintes livrées avec une nouvelle version de l'app ; aucune mise à jour automatique d'exécutables non vérifiés (`yt-dlp -U` n'est jamais appelé).

## 2. Polices et icônes embarquées

| Ressource | Licence |
|---|---|
| Manrope (variable) | SIL Open Font License 1.1 |
| JetBrains Mono | SIL Open Font License 1.1 |
| Material Symbols Rounded | Apache-2.0 |

## 3. Principales dépendances applicatives (à auditer en Phase 6)

Tauri 2, tokio, reqwest (rustls, aws-lc-rs), rusqlite (SQLite bundled, domaine public), zip, sha2, React, Zustand, TanStack Virtual, Tailwind CSS — licences MIT / Apache-2.0 / ISC / BSD majoritairement. Un inventaire automatisé (`cargo about` / `license-checker`) sera produit avant la release.

## 4. Contenus

Miarina Media ne contourne ni DRM, ni paywall, ni authentification : les formats marqués DRM sont exclus des propositions, les pages privées ou nécessitant un compte sont signalées comme non supportées. Les tests de bout en bout utilisent exclusivement des contenus sous licence libre (Blender Foundation, CC BY 3.0).
