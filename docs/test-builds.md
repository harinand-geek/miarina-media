# Builds de test

Préversions publiées sur https://media.miarina.org. Pas encore de mise à jour automatique ; l’installateur Windows n’est pas signé.

## Version 0.1.0 — 2026-10-14

| Plateforme | Fichier (dossier `builds/`, non versionné) | Taille | Contenu |
|---|---|---|---|
| Windows 10/11 x64 | `MiarinaMedia-0.1.0-x64-setup.exe` | 8,2 Mo | Installateur NSIS, exécutable **non signé** (Windows SmartScreen affichera un avertissement) |
| Android 7.0+ (arm64 téléphones, x86_64 émulateurs) | `MiarinaMedia-0.1.0.apk` | 31,3 Mo | Rust en release (≈ 14 Mo par architecture), signé avec la **clé de publication** (voir ci-dessous) |

Les outils yt-dlp et FFmpeg ne sont pas inclus : sous Windows, l'application propose de les télécharger (version et SHA-256 épinglés) au premier besoin.

## Installer

- **Windows** : lancer l'installateur ; si SmartScreen bloque, « Informations complémentaires » → « Exécuter quand même ».
- **Android (téléphone)** : copier l'APK sur le téléphone et l'ouvrir (autoriser « Installer des applications inconnues » pour le gestionnaire de fichiers), ou `adb install MiarinaMedia-0.1.0.apk`.
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
- Android (mode développeur Windows activé) : `pnpm tauri android build --apk --target aarch64 --target x86_64` produit directement `app-universal-release.apk`, signé et aligné.

## Clé de signature Android

- Clé de publication créée le 2026-10-14 : `%USERPROFILE%\.miarina\miarina-release.jks` (RSA 4096, valable 30 ans, alias `miarina-media`), mot de passe dans `miarina-release.pass` à côté. Empreinte SHA-256 du certificat : `11de871564b14382fd46a210ea06327e6d260101125ad2b545159e8b1c6479e1`.
- Gradle la lit via `src-tauri/gen/android/keystore.properties` (ignoré par Git). Sans ce fichier, l'APK release n'est pas signé.
- **À sauvegarder hors de ce PC** (clé et mot de passe, séparément) : sans elle, aucune mise à jour ne pourra s'installer par-dessus les versions publiées.
- La clé de test du tout premier APK (`miarina-test.jks`) n'est plus utilisée.
- La signature du code Windows (certificat Authenticode) reste à décider avant une version stable.
