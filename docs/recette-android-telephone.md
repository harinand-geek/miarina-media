# Recette Android sur téléphone réel — tâches en revue (2026-11-13)

Trois tâches Flow attendent un essai sur un téléphone ARM64 physique : **L03 Audio Android durable**, **splash screen et écrans de démarrage**, **lecteur vidéo paysage (écran 13, L07)**. L'émulateur ne permet pas de les valider (Bluetooth, appels, verrouillage, gestes au doigt, restrictions des constructeurs, mémoire).

## APK de test

`builds/test/MiarinaMedia-android-test-f596bc1.apk` (dossier local, non versionné), construit le 2026-11-13 depuis la révision `f596bc1`.

- Taille : 134 478 644 octets.
- SHA-256 : `c268ecbcde07117925548c6d4d2d9b8ea796ed264a61840cac41a7ceafa9642d`
- Universel ARM64 + x86_64. Certificat de signature identique à celui de la 0.1.7 publiée (SHA-256 `11de8715…6479e1`, vérifié avec apksigner) : s'installe par-dessus, données conservées.
- Remplace `MiarinaMedia-0.1.7-L03-arm64-test.apk` du 2026-11-11, plus ancien.
- Contrôlé sur l'émulateur (Android 15) : installation par-dessus l'app existante, démarrage en 3,7 s sans plantage ; dans ce build optimisé, lecture vidéo, pistes, niveaux volume / luminosité, plein écran aller-retour et fermeture répondent. Non contrôlés sur l'émulateur : sélecteur de sous-titres, image dans l'image, et tout ce qui suit.
- La version Android reste **0.1.7** (code 1007, fixée dans `tauri.android.conf.json`) : c'est un build de test qui contient le code plus récent sous le même numéro. **Ne pas publier** ce fichier ; Réglages › À propos affiche 0.1.7, ce n'est pas une erreur.
- Installation : copier l'APK sur le téléphone, l'ouvrir, autoriser l'installation depuis cette source si Android le demande.

## Avant de commencer

Noter : modèle, version d'Android, constructeur (surcouche), batterie au départ. Avoir dans le téléphone : quelques MP3, une vidéo, idéalement un MKV avec deux pistes audio et un fichier `.srt` (par exemple `mkv multipistes.mkv` et `mkv multipistes.srt` du corpus de référence, voir `docs/lots/LOT-L00-reference.md`), copiés dans Téléchargements ou Films.

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

## Résultats

| Étape | OK / défaut | Remarque (modèle, version, capture si défaut) |
|---|---|---|
| 1 Démarrage | | |
| 2 Audio durable | | |
| 3 Vidéo plein écran | | |
| 4 Clair / anglais | | |
