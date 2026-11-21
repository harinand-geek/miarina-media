# Plan — première version Flutter publique pour Windows

État : **validé le 2026-11-20** (décisions ci-dessous). Rien de public n'est fait avant l'accord final du propriétaire (point 5).

## Point de départ

- Version publique : **0.1.11** (app Tauri), Windows et Android, installateur NSIS `MiarinaMedia-0.1.11-x64-setup.exe`.
- Mise à jour intégrée depuis 0.1.7 (`docs/app-updates.md`) : manifeste signé Ed25519 sur `/updates/stable.json` (et `beta.json`), installateur téléchargé, vérifié (taille, SHA-256) puis lancé par l'app. L'adresse doit être `https://media.miarina.org/downloads/MiarinaMedia-VERSION-x64-setup.exe`. Le script de signature accepte une version Android différente de la version Windows.
- Données 0.1.x : `%APPDATA%\org.miarina.media\` (`miarina.db` schéma 9, miniatures, pochettes, copies de sauvegarde, réglages, torrents).
- App Flutter : tous les écrans Windows portés (`docs/flutter-implementation-map.md`), schéma 10, données aujourd'hui dans un dossier à part (`%APPDATA%\MIARINA\Miarina Media`), pas d'installateur, pas d'écran Mises à jour, outils (FFmpeg, yt-dlp) non inclus dans un paquet.

## Ce qui sera fait (choix techniques, délégués)

1. **Numéro : 0.2.0 pour Windows seulement.** Android reste en 0.1.11 (le manifeste porte une version par plateforme) jusqu'à la fin de l'app Flutter Android.
2. **Mêmes données que la 0.1.x.** L'app Flutter publiée utilise `%APPDATA%\org.miarina.media\` : bibliothèque, playlists, favoris, historique, reprises, réglages, téléchargements et torrents sont repris tels quels. L'ouverture passe par `open_upgrading` (copie de sauvegarde avant le passage au schéma 10, refus d'une base plus récente, migration en une transaction), comme la 0.1.x. Les clés de réglages déjà partagées sont vérifiées une à une ; tout écart est documenté.
3. **Outils inclus** comme aujourd'hui (décision 0002) : FFmpeg et yt-dlp dans `tools\` à côté de l'app, mêmes versions et mêmes licences que la 0.1.11 ; bibliothèques d'exécution Microsoft (Visual C++) copiées à côté de l'exécutable (licence de redistribution Microsoft) ; WebView2 déjà requis par la 0.1.x.
4. **Licences** : relecture de ce que l'app Flutter ajoute (moteur Flutter, paquets Dart, libmpv de media_kit, polices) ; `docs/licenses.md` et l'écran Licences mis à jour. Si une bibliothèque impose une obligation nouvelle (par exemple GPL pour libmpv), elle est expliquée simplement avant publication.
5. **Mises à jour intégrées** : le mécanisme de la 0.1.x est repris à l'identique dans le cœur Rust (même manifeste, même clé publique épinglée, mêmes refus, reprise de téléchargement, canal Stable / Bêta, installation jamais automatique) et l'écran Réglages › Mises à jour est porté de la maquette Windows v2. Ainsi la 0.2.x saura se mettre à jour elle-même.
6. **Installateur NSIS qui remplace la 0.1.x sur place** : même dossier d'installation, même entrée « Programmes et fonctionnalités », mêmes raccourcis, même habillage (`brand.nsh`, français et anglais). Une 0.1.x qui se met à jour lance cet installateur comme d'habitude ; aucune désinstallation, aucune donnée touchée par l'installateur.
7. **Recette sans rien publier** : canal de test local (fonction `update-test-channel` existante, serveur `127.0.0.1`, clé de test), avec une 0.1.11 de recette installée sous un autre identifiant. Vérifié : mise à jour 0.1.11 → 0.2.0, reprise des données (sur une **copie** de données réelles fournie par le propriétaire, jamais le dossier en service), retour arrière refusé proprement, désinstallation. Mesures (démarrage à froid, mémoire, taille de l'installeur) comparées à la 0.1.11 dans `docs/performance.md`.
8. **Notes de version** rédigées pour validation, sans nommer d'autres applications.

## Étapes

| Lot | Contenu | Public ? |
|---|---|---|
| R1 | Données partagées avec la 0.1.x, migration avec sauvegarde, test sur données de démonstration — **fait le 2026-11-21** | non |
| R2 | Outils et bibliothèques inclus, licences — **fait le 2026-11-21** (libmpv récente épinglée ; source GPL à publier avec chaque version, voir `docs/licenses.md` §5) | non |
| R3 | Mises à jour intégrées et écran Réglages › Mises à jour — **fait le 2026-11-21** | non |
| R4 | Installateur NSIS 0.2.0 remplaçant la 0.1.x — **fait le 2026-11-21** (112,9 Mio ; détails ci-dessous) | non |
| R5 | Recette complète sur canal de test local, mesures — **fait le 2026-11-21** (détails ci-dessous) | non |
| R6 | Publication (après accord) : artefact, manifeste, site | **oui** |

Chaque lot est commité et poussé sur `main` comme les précédents.

## Décisions du propriétaire (2026-11-20)

1. **Bêta d'abord** : la 0.2.0 sort sur le canal Bêta, puis sur Stable après quelques jours sans problème.
2. **Pas de signature Authenticode pour l'instant** : l'avertissement SmartScreen reste comme pour la 0.1.x.
3. **La 0.1.12 (app Tauri) n'est pas publiée** : remplacée par la 0.2.0 ; ses fichiers en cours restent dans l'arbre de travail, non commités.
4. **Recette sur données de démonstration** : une base 0.1.11 de démonstration est fabriquée ; les vraies données du propriétaire ne sont jamais utilisées.
5. **Accord final avant R6** : rien n'est envoyé sur le serveur ni sur le site sans cet accord.
6. **Code source** (2026-11-21) : le dépôt GitHub est public ; chaque version publiée reçoit une étiquette `vVERSION` sur le commit construit (R6), indiquée dans la notice.

## Installateur (R4, 2026-11-21)

- `apps/flutter_client/tool/stage_windows.ps1` puis `tool/build_installer.ps1` : `build\windows\installer\MiarinaMedia-<version>-x64-setup.exe`. Modèle `windows/installer/installer.nsi`, dérivé du modèle NSIS de tauri-bundler (MIT OR Apache-2.0) qui a construit les 0.1.x : même nom de produit, même dossier (`%LOCALAPPDATA%\Miarina Media`, installation pour l'utilisateur), même entrée « Programmes et fonctionnalités », mêmes clés, mêmes raccourcis, même habillage (`brand.nsh`, textes français corrigés). Listes de fichiers générées depuis l'app assemblée. Outils NSIS : la copie installée par Tauri (`%LOCALAPPDATA%\tauri\NSIS`, extension `nsis_tauri_utils`).
- Exécutable renommé `miarina-media.exe` comme en 0.1.x (raccourcis, épingles et « Ouvrir avec » gardés).
- À l'installation, ce que seule la 0.1.x utilisait est retiré : libVLC, l'extension navigateur et sa passerelle, et les inscriptions de la passerelle pour Chrome, Edge et Firefox (l'extension n'existe pas dans l'app Flutter). Les données ne sont jamais touchées par l'installateur ; la désinstallation les garde sauf si « Supprimer les données » est coché (comme 0.1.x).
- Taille : **112,9 Mio** (0.1.11 : 91,2 Mio), 334 Mio installés. Le produit réel a été construit pour mesure puis supprimé, jamais lancé (il remplacerait l'installation 0.1.12 du propriétaire).
- Vérifié avec l'identité de recette (`-Recette` ; app compilée avec `MM_APP_ID`) : installation silencieuse, entrée « Programmes et fonctionnalités » (éditeur MIARINA, 0.2.0, taille), raccourcis menu Démarrer et bureau, lancement de l'app installée et fermeture propre, désinstallation silencieuse (dossier, entrée et raccourcis retirés, données gardées par défaut) ; installation réelle 0.1.12 du propriétaire inchangée.
- **Incident** : l'essai a utilisé l'identité de la recette L09 (`org.miarina.media.recette`), dont les données de test étaient conservées sur ce PC ; le nettoyage les a supprimées (non récupérables ; données réelles non touchées). Correctif : identité neuve `org.miarina.media.recette.flutter`, et scripts qui s'arrêtent si une trace de l'identité existe déjà et ne suppriment que ce qu'ils ont créé.
- Reste pour R5 : le passage 0.1.11 → 0.2.0 par l'installateur et par la mise à jour intégrée, sur une installation de recette.

## Recette (R5, 2026-11-21)

Montage : 0.1.11 recompilée depuis son commit (`9793497`, dossier de travail séparé) avec l'identité de recette `org.miarina.media.recette.flutter` et le canal de test (serveur en boucle locale `127.0.0.1:8743` avec ETag et plages, clé de test jetable) ; 0.2.0 de recette (`MM_APP_ID`, installateur `-Recette`) ; base 0.1.11 de démonstration (schéma 9). Scripts arrêtés si une trace de l'identité existe, nettoyage limité à ce qu'ils créent ; installation réelle et données du propriétaire vérifiées inchangées à chaque essai.

| Scénario | Résultat |
|---|---|
| A. 0.1.11 installée, lancée, puis installateur 0.2.0 par-dessus (silencieux) ; trois fois | entrée « Programmes et fonctionnalités » 0.2.0, même exécutable, raccourcis gardés ; libVLC, passerelle et extension de la 0.1.x retirées ; premier lancement : copie `backups/miarina-schema9-….db`, base au schéma 10, mêmes comptes (19 médias, 5 positions, 5 réglages) ; accueil avec reprise, favoris et écoutes ; fermeture propre ; désinstallation complète |
| B. Mise à jour intégrée de 0.1.11 | manifeste signé lu, 0.2.0 proposée, téléchargée (118 385 419 octets) et vérifiée (SHA-256 identique à l'installateur 0.2.0), « Installer maintenant » : l'installateur part du fichier téléchargé et 0.1.11 se ferme ; le même fichier, lancé en silencieux (l'assistant attend des clics, ses pages ont été vérifiées en L09), installe 0.2.0 ; au premier lancement, le cache de mise à jour de 0.1.11 est nettoyé et la base migrée (schéma 10, 19 médias) |
| Mesures | voir `docs/performance.md` (section du 2026-11-21) |

Non couvert ici : une mise à jour 0.2.0 → 0.2.x par la mise à jour intégrée de l'app Flutter sur le canal de test (même code et mêmes tests que 0.1.x, vérifié en R3 sur le vrai manifeste public) ; à refaire à la première 0.2.x. Point à suivre en bêta : un accueil encore vide à 10 s au premier lancement après mise à jour, vu une fois sur trois.

## R6 publié (2026-11-21) — 0.2.0 sur le canal Bêta

Revue du propriétaire avant publication (corrigée et recompilée) : icône Miarina dans l'exécutable (l'icône du modèle Flutter restait), numéro de version intégré (`MM_VERSION` ; sans lui, « Version de développement » et mises à jour intégrées coupées ; `stage_windows.ps1` refuse désormais une telle build), pochettes sans image = logo Miarina Media en faible opacité, À propos (écosystème Miarina, miarina.org ; développeur © 2026 Harinjaka, cv.harinjaka.org), mode clair (carte Reprendre, En lecture, compteurs des listes automatiques), l'app nommée « Miarina Media » dans tous les textes.

Construit depuis `1d4e6d7` (étiquette `v0.2.0`, poussée) :

| Fichier | Taille | SHA-256 |
|---|---|---|
| `MiarinaMedia-0.2.0-x64-setup.exe` | 118 398 995 octets (112,9 Mio) | `eca6587a6dcf4b7b3e3877603c619a425b51b04bc4b26866edd7884b85d82acb` |
| `MiarinaMedia-0.2.0-source.tar.gz` (dépôt au commit construit et sous-module `46bb3bcd`) | 36 Mo | `8dc85eaf86edf4fe2dc8dd17987c50d3384771cfaf09fdfb59c112b516c95645` |

- `/updates/beta.json` publié (Windows 0.2.0, Android 0.1.11 inchangé), vérifié à son adresse publique avec `verify-app-update.mjs` ; `/updates/stable.json` inchangé (0.1.12).
- Site publié (sauvegarde de l'ancien : `/root/miarina-site-before-0.2.0-20261121-092353.tar.gz`) : couleurs et typographie de l'app, section et téléchargement 0.2.0 bêta, captures 0.2.0, Licences.
- Installé sur le PC du propriétaire par-dessus sa 0.1.12 (bibliothèque migrée avec copie `backups/miarina-schema9-….db`).
- Suite : passage sur Stable après quelques jours sans problème (nouveau `stable.json` signé, notes, site).
