# 0007 — Migration de l'interface vers Flutter, icônes Phosphor

Date : 2026-11-19 · Statut : **acceptée pour la direction** (décision du propriétaire du produit) ; **la bascule reste conditionnée à la preuve de concept** (§ Critères) · Complète la décision D3 du handoff `design/design_handoff_lecture_ecouter/`

## Contexte

La refonte de l'espace Écouter (handoff « Lecteur Miarina », direction 3a) a été livrée avec un mapping Flutter en prévision d'une migration (D3), hors périmètre de ce lot. Le propriétaire a demandé la migration pour deux raisons :

- sur Android, une interface rendue nativement plutôt que dans une WebView : animations plus fluides, pochette partagée entre mini-lecteur et lecteur ;
- un rendu identique sur Windows et Android.

Il a aussi jugé les icônes de la maquette (Material Symbols Rounded) peu professionnelles et demandé un jeu premium, avec des animations fluides et un design moderne qui ne paraisse pas généré.

État de départ (0.1.11) : interface React/TypeScript de 140 fichiers (environ 23 000 lignes hors tests) ; cœur Rust de 77 fichiers (environ 21 000 lignes : téléchargements, yt-dlp/FFmpeg, SQLite, bibliothèque, torrents, libVLC) ; plugins Android en Kotlin (Media3, `PlaybackService`, égaliseur, MediaStore, navigateur, extracteur).

## Décisions

1. **Flutter remplace l'interface React à terme.** Le produit reste Miarina Media (le nom « Nova Player » du cahier des charges est abandonné) ; logo 4d et charte inchangés.
2. **Emplacement : `apps/flutter_client/`** dans ce dépôt. L'application Tauri continue d'être livrée jusqu'à la bascule ; aucun nouveau dépôt.
3. **Le cœur Rust est conservé** et appelé depuis Dart via `flutter_rust_bridge`. Les commandes Tauri deviennent des fonctions FFI ; la base SQLite et ses migrations restent celles des crates, pour que les données des utilisateurs de la 0.1.x soient reprises telles quelles.
4. **Moteurs de lecture :** Windows passe à libmpv via `media_kit` (rendu en texture Flutter), sous réserve de l'audit de licence (builds LGPL ou GPL de libmpv et FFmpeg) ; Android garde Media3, en réutilisant le code Kotlin existant sous forme de plugin Flutter. Contrat `MediaEngine` commun avec matrice de capacités : une fonction absente est masquée ou désactivée, jamais simulée.
5. **Icônes : Phosphor 2.x** (MIT), choisi sur planche comparative face à Material Symbols, Fluent et Hugeicons. Regular pour l'interface, Fill pour l'état actif et le transport, Duotone pour les écrans vides. Intégration par une **police d'icônes générée** depuis les SVG officiels (sous-ensemble des icônes utilisées), sans dépendre d'un paquet Flutter (`phosphor_flutter` n'est plus publié depuis environ deux ans). Les glyphes manquants (−10 s, +30 s chiffrés…) sont dessinés sur la grille Phosphor (256, trait 16). Correspondance des 127 icônes de la maquette : `docs/icon-system.md`.
6. **Mouvement :** durées du handoff comme base (160 / 220 / 240 / 320 ms, courbe `cubic(0.2, 0, 0, 1)`), ressorts physiques pour ce qui suit le doigt (mini-lecteur, feuilles), pochette partagée (Hero), morphose lecture/pause, retour haptique sur Android. Le réglage système « réduire les animations » remplace les mouvements par des fondus de 120 ms. Pas d'effets décoratifs continus (dégradés animés, lueurs, flous animés).

## Critères de la preuve de concept (avant toute bascule)

Mesurés sur les appareils de référence (ce PC Windows 11 ; Redmi Note 10 Pro, Android 13), comparés à la 0.1.11 et consignés dans `docs/performance.md` :

- lecture MP3, FLAC, MP4 et MKV sur Windows et Android ; vidéo affichée dans Flutter ; position, durée, erreurs et sous-titres de base remontés par le contrat `MediaEngine` ;
- lecture en arrière-plan Android avec notification et écran verrouillé (MediaSession) ;
- un appel au cœur Rust (lecture de la bibliothèque SQLite existante) depuis Dart sur les deux plateformes ;
- une WebView Windows capable de détecter un média (condition du navigateur intégré, décision 0001) ;
- démarrage à froid, RAM au repos et en lecture, taille de l'installeur et de l'APK.

Si un critère échoue sans solution raisonnable, la décision est réexaminée avant d'aller plus loin.

## Conséquences

- Deux interfaces coexistent pendant la migration ; les corrections urgentes continuent dans l'app Tauri.
- L'espace Obtenir (accueil, analyse, téléchargements, navigateur, torrents) devra aussi être porté avant la bascule ; il ne doit pas régresser.
- Le mécanisme de mise à jour (aujourd'hui celui de Tauri) et l'installeur Windows sont à refaire ; ils seront traités avant la première version Flutter publique.
- Le README du handoff indiquait « ne pas démarrer d'app Flutter » pour ce lot ; cette décision du propriétaire le remplace sur ce point. Le reste du handoff (écrans, tokens, comportements) s'applique tel quel, à l'exception du jeu d'icônes.
