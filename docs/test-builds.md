# Builds de test

Builds produits localement pour tester l'application. **Ce ne sont pas des versions publiables** : non signés pour la distribution, sans mise à jour automatique.

## Version 0.1.0 — 2026-10-14

| Plateforme | Fichier (dossier `builds/`, non versionné) | Taille | Contenu |
|---|---|---|---|
| Windows 10/11 x64 | `Miarina Media_0.1.0_x64-setup.exe` | 8,2 Mo | Installateur NSIS, exécutable **non signé** (Windows SmartScreen affichera un avertissement) |
| Android 7.0+ (arm64 téléphones, x86_64 émulateurs) | `MiarinaMedia-0.1.0-test.apk` | 31,4 Mo | Rust en release (≈ 14 Mo par architecture), signé avec une **clé de test locale** |

Les outils yt-dlp et FFmpeg ne sont pas inclus : sous Windows, l'application propose de les télécharger (version et SHA-256 épinglés) au premier besoin.

## Installer

- **Windows** : lancer l'installateur ; si SmartScreen bloque, « Informations complémentaires » → « Exécuter quand même ».
- **Android (téléphone)** : copier l'APK sur le téléphone et l'ouvrir (autoriser « Installer des applications inconnues » pour le gestionnaire de fichiers), ou `adb install MiarinaMedia-0.1.0-test.apk`.
- Un APK signé avec une autre clé (build debug) doit d'abord être désinstallé.

## Ce qui fonctionne / limites connues

| | Windows | Android |
|---|---|---|
| Analyse de lien, formats, téléchargement HTTP direct | ✅ | ✅ (vérifié sur émulateur) |
| Pages web via yt-dlp (YouTube, etc.), conversion audio | ✅ | ❌ (extracteur Android à évaluer) |
| File, pause/reprise, historique, reprise après redémarrage | ✅ | ✅ (non vérifié en arrière-plan) |
| Bibliothèque, miniatures, métadonnées | ✅ | partiel : pas de miniatures ni de durée |
| Lecture | ✅ | ❌ — lecteur natif à venir |
| Navigateur intégré | ✅ (un onglet) | ❌ — à venir |
| Fichiers visibles dans la galerie / Téléchargements | — | ❌ stockage privé de l'app (MediaStore à venir) |
| Partage de lien depuis une autre app, notifications | — | ❌ à venir |

## Reproduire

- Windows : `pnpm tauri build` (dans `apps/client`).
- Android (mode développeur Windows activé) : `pnpm tauri android build --apk --target aarch64 --target x86_64`, puis `zipalign -p 4` et `apksigner sign` avec la clé de test (`%USERPROFILE%\.miarina\`, hors du dépôt). La clé de publication et la signature du code Windows restent à décider (Phase 6).
