# Builds de test

Préversions publiées sur https://media.miarina.org. Depuis la 0.1.7, recherche automatique et téléchargement des mises à jour dans les réglages, puis installation à la demande. L’installateur Windows n’est pas signé avec Authenticode.

## Windows et Android 0.1.7 — 2026-11-10

Sources : révision 0ccc620. Recherche automatique des nouvelles versions ; téléchargement et installation depuis les réglages sur action utilisateur. Une installation manuelle depuis la 0.1.6 est nécessaire.

| Fichier | Octets | SHA-256 |
|---|---:|---|
| MiarinaMedia-0.1.7-x64-setup.exe | 73603463 | f083a6ee5aa85bedd8d131ce97864342c905866bcbe3d3b7fe53c0472c00a767 |
| MiarinaMedia-0.1.7.apk | 132922457 | b9a04fba921bffa60eca104adc219af25de2814aaf1507a52ca7a9b85c8eba23 |
| MiarinaMedia-0.1.7-source.tar.gz | 33828715 | bf36e137a8bffb2eea50e965686308e76f0768aa3bbb86e173d034fb702049f6 |

Validation : 79 tests frontend, TypeScript et ESLint ; trois tests Rust de version, signature et altération du manifeste. Builds release Windows et Android réussis. Intégrité NSIS, signature APK v2 (certificat inchangé), versionCode 1007, ARM64/x86_64 et alignement vérifiés. Pas de validation de bout en bout d’une installation depuis l’interface, ni de test sur téléphone réel. Windows reste sans signature Authenticode. Voir app-updates.md pour le protocole et les limites : application ouverte pendant le téléchargement, pas de reprise par octets ni de téléchargement automatique Wi-Fi.

## Windows et Android 0.1.6 — 2026-11-09

Révision application : `4fb262f05fa16d75e1d60844f0c0d72506f33386`. Moteur HTTP MDM expérimental désactivé.

| Fichier | Octets | SHA-256 |
|---|---:|---|
| MiarinaMedia-0.1.6-x64-setup.exe | 73556226 | 3acfbbea71b4a268d45c4a62b4b36be53ac22dec4fc91ae1e78c42916c0192d8 |
| MiarinaMedia-0.1.6.apk | 132841589 | ac237f14819fd57c977b5aa1ff819b3c8bcb3edae310d8adab3e95269bb7a7f0 |
| MiarinaMedia-0.1.6-source.tar.gz | 33819407 | 3a4b22047f0dfed8e0b1c8c99701d9eded5a63af7dda242a449883ad90d0910d |

Windows : compilation release et paquet NSIS réussis ; intégrité du paquet vérifiée avec 7-Zip. L’extension Chrome/Edge, sa passerelle native, les outils multimédias et les notices sont présents. Installateur non signé ; installation et interface de ce paquet non rejouées.

Android : APK universel signé, versionCode 1006, Android 7+, ARM64 et x86_64. Signature v2 et alignement vérifiés. Certificat SHA-256 : `11de871564b14382fd46a210ea06327e6d260101125ad2b545159e8b1c6479e1`. Aucun appareil connecté lors de cette publication : essais téléphone, cycle de vie en arrière-plan et lecture native restent à effectuer. Avertissements de compilation non bloquants (imports inutilisés et API Gradle dépréciées).

L’audit automatisé et le transfert torrent local sont décrits dans `prebuild-audit-2026-11-09.md`. La connexion de l’extension dans Chrome/Edge reste à valider manuellement ; distribution en mode développeur, sans publication en magasin. Les fonctions torrent sont Windows uniquement.

L’archive source inclut la révision application et le sous-module Mister Download Manager épinglé ; elle ne constitue pas un ensemble complet des sources natives Android tierces (voir `android-extractor-validation.md`).

## Android 0.1.4 — instruction de publication du 2026-10-28

APK : `MiarinaMedia-0.1.4.apk`, 132 808 453 octets (126,7 Mio), code 1004.
SHA-256 : `9468d53eae471013bcc91154559450050061003612f2febfacc4e1863a64183d`.
Même certificat de publication, arm64-v8a et x86_64, Android 7+.
Parcours YouTube testé sur émulateur sur un build de développement précédent.
Conversion MP3 complète et téléphone physique non validés. Inventaire des sources
natives incomplet : voir `android-extractor-validation.md`. Publication explicitement
demandée par le propriétaire après information de ces limites.

## Windows 0.1.4 — 2026-10-28

Installateur : `MiarinaMedia-0.1.4-x64-setup.exe`, 72 483 476 octets (69,13 Mio).
SHA-256 : `a86968b36c9ce9cf272a563bdc8a11c4df0340aca343847f385cb4ab7aed75d9`.

Binaire Windows compilé en release puis paquet NSIS terminé. Interface de fin
vérifiée dans un aperçu sans installation : textes clairs, accents corrects,
icône officielle dans la barre de titre. Le paquet contient aussi le logo
discret pour les miniatures absentes et les corrections de fiabilité décrites
dans `desktop-audit-2026-10-28.md` (170 tests Rust et 65 tests frontend).
L'installation complète de ce paquet n'a pas été rejouée.

Le second passage du bundler signale que le marqueur de type de paquet a déjà
été remplacé dans le binaire ; aucune mise à jour automatique n'est configurée.
Windows reste non signé. Voir la mise à jour Android 0.1.4 ci-dessus pour la
décision de publication et les limites restantes des sources natives.

## Version 0.1.3 — 2026-10-18

| Plateforme | Fichier | Taille | SHA-256 |
|---|---|---|---|
| Windows 10/11 x64 | `MiarinaMedia-0.1.3-x64-setup.exe` | 69,1 Mo (72 478 784 octets) | `d9b545b13735630700427e507fe20fd7e2a465652296a8276788772ff56e564c` |
| Android 7.0+ | `MiarinaMedia-0.1.3.apk` | 35 Mo (36 928 485 octets) | `1bcfd16e46c24a7c1b7aecb8be2c80d895d124d2b2d4e97f746a8326c2e21008` |

APK signé avec la clé de publication (certificat `11de8715…c6479e1`, vérifié avec `apksigner`), versionCode 1003 ; aucune permission ajoutée. Nouveautés : navigateur intégré Android (M1/M3) ; navigateur Windows dans la fenêtre principale, même présentation qu'Android ; favoris ; recherche depuis le champ de l'accueil ; présélection ≤ 1080p ; fond flou dans le lecteur. Vérifié : Windows sur une variante de test isolée (identifiant `org.miarina.media.test`, données supprimées ensuite) — navigateur, favoris, recherche depuis l'accueil, retour arrière, bouton flottant, lecteur vidéo/MP3 ; APK de publication sur l'émulateur Android 15 (recherche depuis l'accueil, étoile). Pas d'appareil physique.

## Version 0.1.2 — 2026-10-18

| Plateforme | Fichier | Taille | SHA-256 |
|---|---|---|---|
| Windows 10/11 x64 | `MiarinaMedia-0.1.2-x64-setup.exe` | 69,1 Mo (72 472 445 octets) | `2ae0daae2bf5433fe8108956f5bd695c19c0809e2736dff6b4ada33459d26098` |
| Android 7.0+ | `MiarinaMedia-0.1.2.apk` | 35 Mo (36 751 269 octets) | `2480eb7f8057bfcfc393ae78eb7dae4b6b27c55fed5e9e36c2c125278ae11dd1` |

APK signé avec la clé de publication (certificat `11de8715…c6479e1`), versionCode 1002. APK de publication vérifié sur l'émulateur Android 15 (partage d'un lien, téléchargement avec notification, galerie, miniature, lecture). Permissions : INTERNET, FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC, POST_NOTIFICATIONS, plus ACCESS_NETWORK_STATE et WAKE_LOCK ajoutées par Media3. Nouveautés : correction des titres accentués et mise à jour vérifiée de yt-dlp (Windows) ; lecteur Media3, miniatures/durées, Films/Musique (Android 11+), notifications et téléchargements en arrière-plan, partage entrant/sortant, icône et écran de démarrage (Android).

## Version 0.1.1 — 2026-10-17

| Plateforme | Fichier | Taille | SHA-256 |
|---|---|---|---|
| Windows 10/11 x64 | `MiarinaMedia-0.1.1-x64-setup.exe` | 68,8 Mo (72 109 015 octets) | `1836fac49c4e4d7dd0ccafdf64b34867d0e2f2c26a0ba12aba9ece0e90763dc0` |
| Android 7.0+ | `MiarinaMedia-0.1.1.apk` | 31,4 Mo (32 885 379 octets) | `0054ec0802d4d88cf6e0de8a3771174682c3194483adb876b7a8c3fe689fa8ce` |

APK signé avec la clé de publication (certificat `11de8715…c6479e1`, vérifié avec `apksigner`), versionCode 1001 : s'installe par-dessus la 0.1.0. Nouveautés : outils inclus dans l'installeur Windows (yt-dlp, FFmpeg, QuickJS-NG), MP3 320/256/192/128 kbps et FLAC, miniatures source pendant l'analyse et le téléchargement, retour plus clair sur le champ de lien (Windows et Android).

## Version 0.1.0 — 2026-10-14

| Plateforme | Fichier (dossier `builds/`, non versionné) | Taille | Contenu |
|---|---|---|---|
| Windows 10/11 x64 | `MiarinaMedia-0.1.0-x64-setup.exe` | 8,2 Mo | Installateur NSIS, exécutable **non signé** (Windows SmartScreen affichera un avertissement) |
| Android 7.0+ (arm64 téléphones, x86_64 émulateurs) | `MiarinaMedia-0.1.0.apk` | 31,3 Mo | Rust en release (≈ 14 Mo par architecture), signé avec la **clé de publication** (voir ci-dessous) |

Depuis le 2026-10-17 (décision 0002), yt-dlp et FFmpeg sont **inclus dans l'installeur Windows** : 68,8 Mo au lieu de 8,2 Mo (avec QuickJS-NG pour YouTube), plus aucun téléchargement d'outils au premier usage. Le build les prépare automatiquement (téléchargement vérifié par SHA-256, ~88 Mo la première fois).

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
| Bibliothèque, miniatures, métadonnées | ✅ | ✅ via les API Android (vérifié sur émulateur ; version suivante) |
| Lecture | ✅ | ✅ lecteur natif Media3 (vérifié sur émulateur ; version suivante) |
| Navigateur intégré | ✅ (un onglet) | ❌ — à venir |
| Fichiers visibles dans la galerie / Téléchargements | — | ✅ Android 11+ : vidéo dans `Movies/Miarina`, audio dans `Music/Miarina` (vérifié sur émulateur ; version suivante). Android 7–10 : stockage de l'app |
| Partage de lien depuis une autre app | — | ✅ « Partager → Miarina Media » (vérifié sur émulateur ; version suivante) |
| Partager / ouvrir un fichier avec une autre app | — | ✅ (vérifié sur émulateur ; version suivante) |
| Notifications, téléchargement en arrière-plan | — | ✅ service au premier plan + notification de progression (Pause, Cancel, Pause all) et « Download complete · tap to play » (vérifié sur émulateur ; version suivante) |

## Reproduire

- Windows : `pnpm tauri build` (dans `apps/client`).
- Android (mode développeur Windows activé) : `pnpm tauri android build --apk --target aarch64 --target x86_64` produit directement `app-universal-release.apk`, signé et aligné.

## Clé de signature Android

- Clé de publication créée le 2026-10-14 : `%USERPROFILE%\.miarina\miarina-release.jks` (RSA 4096, valable 30 ans, alias `miarina-media`), mot de passe dans `miarina-release.pass` à côté. Empreinte SHA-256 du certificat : `11de871564b14382fd46a210ea06327e6d260101125ad2b545159e8b1c6479e1`.
- Gradle la lit via `src-tauri/gen/android/keystore.properties` (ignoré par Git). Sans ce fichier, l'APK release n'est pas signé.
- **À sauvegarder hors de ce PC** (clé et mot de passe, séparément) : sans elle, aucune mise à jour ne pourra s'installer par-dessus les versions publiées.
- La clé de test du tout premier APK (`miarina-test.jks`) n'est plus utilisée.
- La signature du code Windows (certificat Authenticode) reste à décider avant une version stable.
