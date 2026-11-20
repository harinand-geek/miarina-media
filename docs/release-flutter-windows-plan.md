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
| R2 | Outils et bibliothèques inclus, licences | non |
| R3 | Mises à jour intégrées et écran Réglages › Mises à jour | non |
| R4 | Installateur NSIS 0.2.0 remplaçant la 0.1.x | non |
| R5 | Recette complète sur canal de test local, mesures | non |
| R6 | Publication (après accord) : artefact, manifeste, site | **oui** |

Chaque lot est commité et poussé sur `main` comme les précédents.

## Décisions du propriétaire (2026-11-20)

1. **Bêta d'abord** : la 0.2.0 sort sur le canal Bêta, puis sur Stable après quelques jours sans problème.
2. **Pas de signature Authenticode pour l'instant** : l'avertissement SmartScreen reste comme pour la 0.1.x.
3. **La 0.1.12 (app Tauri) n'est pas publiée** : remplacée par la 0.2.0 ; ses fichiers en cours restent dans l'arbre de travail, non commités.
4. **Recette sur données de démonstration** : une base 0.1.11 de démonstration est fabriquée ; les vraies données du propriétaire ne sont jamais utilisées.
5. **Accord final avant R6** : rien n'est envoyé sur le serveur ni sur le site sans cet accord.
