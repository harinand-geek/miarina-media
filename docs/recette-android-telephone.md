# Recette Android sur téléphone réel — tâches en revue (2026-11-13)

Sept tâches Flow attendent un essai sur un téléphone ARM64 physique : **L03 Audio Android durable**, **splash screen et écrans de démarrage**, **lecteur vidéo paysage (écran 13, L07)**, **médias locaux du téléphone (AND-06)**, **Playlists et Favoris (écran 06)**, **égaliseur (écran 09)**, **réglages de lecture**. L'émulateur ne permet pas de les valider (Bluetooth, appels, verrouillage, gestes au doigt, restrictions des constructeurs, mémoire).

## APK de test — navigation « lecteur d'abord » (2026-11-15)

À utiliser : `builds/test/MiarinaMedia-android-test-lark.apk` (non versionné), construit le 2026-11-15 depuis `f00511f` + modifications non commitées de la décision [0006](decisions/0006-android-player-first.md), réinstallé par adb sur le Redmi Note 10 Pro à 16:10 (2e version : morphing lecteur ↔ mini-lecteur, glisser le mini-lecteur vers le haut, vrais logos des sites dans la recherche, bouton plein écran vidéo sous l'image et appui sur l'image, réduction vidéo immédiate, écran d'attente de l'analyse). Premier essai (15:48) : retours pris en compte.

- ARM64 seulement, 70 258 796 octets, SHA-256 `9ebecdb532c1186dd60b82928d19f87f0fb3127c17167a841c3cfa8ed8bf5ef6`.
- **3e version, réinstallée à 17:12** : menu collant en haut (Musique, Vidéos), bouton « Lecture aléatoire » retiré de Titres, animations d'appui et de changement d'onglet, arrondis plus marqués, vrais logos sur la page de départ du navigateur, une seule copie de yt-dlp (même version 2026.08.19). 67 089 176 octets (−3 Mo), SHA-256 `ee83a9a46f1fe5189739424d3aa14386bfe937dbc1758eaea8ffe803332a3871`. **À vérifier en priorité** : analyser un lien YouTube et télécharger en MP3 (contrôle que yt-dlp et FFmpeg se préparent bien avec le nouveau nom de ressource).

Windows (même jour) : `builds/test/MiarinaMedia-0.1.10-x64-setup-test.exe`, 95 685 900 octets, SHA-256 `cc021b194cc821faf9578d03b054d62e80b7435aae725f42ad4dd32e9f2f04b7`, installé en silencieux par-dessus la 0.1.10 locale sur ce PC à 17:05 et lancé. Ouverture sur Écouter, recherche Ctrl K, arrondis, mini-lecteur flottant, écran d'attente, pages du navigateur au thème de l'app (clair/sombre).
- versionCode 1009, version affichée 0.1.9 (build de test, **ne pas publier**) ; certificat `11de8715…6479e1` vérifié avec apksigner, installé par-dessus la 0.1.9.
- Contrôlé : 217 tests frontend, TypeScript, ESLint ; sur le téléphone, démarrage sans plantage ni erreur JavaScript dans logcat. Aucune capture d'écran faite.
- À essayer : ouverture sur Musique ; barre Musique · Vidéos · Téléch. ; loupe (sites, résultats du téléphone, Entrée sans résultat → YouTube, coller un lien) ; navigateur et retour à l'onglet d'origine ; carte « Coller un lien » dans Téléchargements ; « Reprendre » en tête de Vidéos ; cartes Dossiers / Artistes / Albums / Playlists ; mini-lecteur ; **glisser le grand lecteur vers le bas** (suivi du doigt, fluidité, petit mouvement = tap) ; Paramètres groupés ; mode Éco (réduction sans animation).

## APK de test précédent

Précédent : `builds/test/MiarinaMedia-android-test-and12.apk` (dossier local, non versionné), construit le 2026-11-13 depuis la révision `d897182`, déjà installé sur le Redmi Note 10 Pro (Android 13 / MIUI 14) à 12:14.

- ARM64 seulement (téléphones ; pas l'émulateur x86_64). Taille : 70 257 236 octets.
- SHA-256 : `35a9c353647584f894b49559da14e438de01770d3d546f5db3a3105a95aaad1c`
- Certificat de signature identique à celui de la 0.1.7 publiée (SHA-256 `11de8715…6479e1`, vérifié avec apksigner) : s'installe par-dessus, données conservées.
- Contrôlé avant installation : tests Rust et frontend, clippy, ESLint, TypeScript, compilation Android sans nouvel avertissement. Pas encore d'essai à l'écran sur le téléphone.

Version précédente : `builds/test/MiarinaMedia-android-test-f596bc1.apk` (universel ARM64 + x86_64, 134 478 644 octets, SHA-256 `c268ecbc…a9642d`, sans AND-06 ni le § 6) ; contrôlée sur l'émulateur Android 15 (installation, démarrage en 3,7 s, lecture vidéo, pistes, niveaux, plein écran). `MiarinaMedia-0.1.7-L03-arm64-test.apk` du 2026-11-11 est plus ancien.
- La version Android reste **0.1.7** (code 1007, fixée dans `tauri.android.conf.json`) : c'est un build de test qui contient le code plus récent sous le même numéro. **Ne pas publier** ce fichier ; Réglages › À propos affiche 0.1.7, ce n'est pas une erreur.
- Installation : copier l'APK sur le téléphone, l'ouvrir, autoriser l'installation depuis cette source si Android le demande.

## Avant de commencer

Noter : modèle, version d'Android, constructeur (surcouche), batterie au départ.

Médias : avec la nouvelle version (AND-06, § 5), la musique et les vidéos déjà présentes sur le téléphone apparaissent après « Autoriser l'accès » dans Musique. Le fichier `.srt` peut être copié n'importe où : il est choisi avec le sélecteur Android. Pour le changement de piste audio (étape 3.5), copier une vidéo multipiste (par exemple `mkv multipistes.mkv` du corpus de référence, voir `docs/lots/LOT-L00-reference.md`) dans Films ou Téléchargements.

## 1. Démarrage (splash)

1. Fermer l'app (balayer depuis les apps récentes), la relancer : logo 4d sur fond sombre, barres teal qui glissent puis triangle corail (Android 12+), « Miarina Media / MIARINA » en bas, fondu vers l'Accueil ; le logo de l'en-tête arrive depuis le centre, le contenu monte.
2. Android 7 à 11 si un appareil est disponible : logo 4d fixe, sans texte en bas, pas d'écran blanc.
3. Réglages › PERFORMANCE › mode Éco (le résumé indique animations « réduites »), ou Android › Accessibilité › supprimer les animations ; relancer : pas de glissement de l'interface, fondus seulement. Remettre ensuite le mode habituel.
4. Noter le temps jusqu'à l'Accueil ; si « Le démarrage prend plus de temps » apparaît, le noter avec le contexte.

## 2. Audio durable (L03)

1. Musique › « Tout lire », verrouiller 30 min : la musique continue, les titres s'enchaînent.
2. Écran verrouillé : pause / suivant / précédent depuis les commandes système.
3. Casque Bluetooth : lecture / pause et suivant.
4. Appel entrant pendant la lecture : pause, aucun son pendant l'appel ; noter si la lecture reprend seule à la fin de l'appel.
5. Retrait du casque filaire ou déconnexion Bluetooth : pause.
6. Utiliser d'autres apps 30 min : la musique continue.
7. Fermer l'app puis la rouvrir : la file et la position sont retrouvées.

## 3. Lecteur vidéo plein écran (écran 13, L07)

1. Ouvrir une vidéo, bouton plein écran : paysage, barres système masquées, image bord à bord (encoche comprise), commandes par-dessus l'image.
2. Bouton rotation : portrait puis paysage ; Retour : sortie du plein écran, le lecteur portrait reprend normalement.
3. Gestes : glisser à gauche = luminosité, à droite = volume, avec indicateur ; double appui à droite = +10 s, à gauche = −10 s ; Réglages › « Gestes vidéo » désactivé = plus de gestes.
4. Cadenas : seule l'icône de déverrouillage reste ; les autres appuis et gestes ne font rien.
5. Puce CC : panneau des pistes ; changer de piste audio sur un MKV multipiste (le son change) ; « Charger SRT / VTT… » : choisir le `.srt`, les sous-titres s'affichent ; choisir une image ou un autre fichier : message « non pris en charge ».
6. Image dans l'image (Android 8+) : la vidéo continue dans la petite fenêtre, sans les commandes ; la rouvrir en grand.
7. Laisser l'app ouverte en plein écran pendant une vidéo de 10 min : pas d'arrêt, pas de « ne répond pas ».

## 4. Thème clair et anglais (contrôle rapide)

Réglages › Thème : Clair, Langue : English. Relancer l'app : le thème clair et l'anglais sont conservés ; Accueil et Musique conformes aux écrans 17–18 de la maquette.

## 5. Musique du téléphone (AND-06)

1. Musique › Titres : la carte « Musique du téléphone » apparaît ; « Autoriser l'accès » : Android demande « Musique et audio » puis « Vidéos ». Accepter : la carte disparaît, les titres du téléphone arrivent dans Titres, Albums, Artistes, Dossiers ; les vidéos dans Vidéos.
2. Pas de sonneries ni de sons de notification dans la liste ; les pochettes et artistes s'affichent quand les fichiers en ont.
3. Lire un titre du téléphone : lecture, écran verrouillé et notification comme pour un téléchargement.
4. ⋮ › Retirer de la bibliothèque : le titre disparaît et ne revient pas après relance ; le fichier reste dans le téléphone.
5. ⋮ › Supprimer le fichier sur un titre du téléphone : message « Android ne permet pas… » (attendu), rien n'est supprimé.
6. Refus : Paramètres Android › Applications › Miarina Media › Autorisations › Musique et audio › Refuser ; revenir dans l'app : la carte revient avec « Ouvrir les réglages » ; autoriser depuis les réglages puis revenir : la carte disparaît.
7. Ajouter un MP3 dans le téléphone (par l'app Fichiers ou par câble), relancer l'app : il apparaît.

## 6. Playlists, favoris, égaliseur, réglages (2026-11-13)

1. Titres › ⋮ › « Ajouter aux favoris » : cœur corail sur la ligne ; onglet Favoris : le titre y est ; ⋮ › « Retirer des favoris » le retire.
2. Playlists › « + Nouvelle playlist », nommer ; Titres › ⋮ › « Ajouter à une playlist… » ; ouvrir la playlist : Tout lire, Aléatoire, ✕ retire un titre, ⋮ › Renommer / Supprimer (confirmation ; les fichiers restent).
3. En lecture › File › « Enregistrer en playlist » : la playlist contient toute la file.
4. Écouter quelques titres, puis Playlists › Récents (dernier écouté en haut) et Plus écoutés (« N écoutes »).
5. En lecture › Son : activer l'égaliseur, préréglage « Basses » puis « Voix » : le son change nettement ; bouger une bande : « Personnalisé » ; « Réinitialiser » ; couper l'égaliseur : son d'origine. Relancer l'app : réglage conservé. Si l'appareil n'a pas d'égaliseur, un texte l'explique.
6. Réglages › Lecture › « Pause au retrait du casque » désactivé : débrancher le casque, la musique continue (sur le haut-parleur) ; réactivé : pause.
7. Lecture sans blanc : un album continu en MP3 (encodé LAME), M4A ou FLAC : pas de silence entre deux pistes.

## Résultats

| Étape | OK / défaut | Remarque (modèle, version, capture si défaut) |
|---|---|---|
| 1 Démarrage | | |
| 2 Audio durable | | |
| 3 Vidéo plein écran | | |
| 4 Clair / anglais | | |
| 5 Musique du téléphone | | |
| 6 Playlists, égaliseur, réglages | | |
