# Fiche LOT-AND12 — Android : lecture sans blanc et fondu entre titres

- Statut : lecture sans blanc décrite et affichée ; fondu non fait (PRÉVU) ; vérification d'écoute sur téléphone à faire
- Exigence CDC : AND-12 (P2) — « Gapless et fondu optionnel : étude séparée, corpus validé, modes compatibles décrits ; fondu off par défaut »

## Lecture sans blanc (gapless)

- Le lecteur Android (Media3 ExoPlayer, `PlaybackService`) reçoit toute la file comme une liste d'éléments (`player_queue` → `setQueue`) : il prépare le titre suivant pendant la lecture du courant et enchaîne sans arrêt du flux audio.
- La suppression du silence d'encodage dépend du fichier : MP3 avec en-tête LAME/Xing (délai et remplissage d'encodeur), AAC/M4A avec métadonnées iTunSMPB, FLAC, Opus et WAV sans remplissage. Un MP3 sans en-tête d'encodeur garde le court silence ajouté par l'encodeur.
- Rien à activer : la ligne de Réglages affiche « ACTIVE » au lieu d'un interrupteur, pour ne pas promettre un mode « avec blanc » qui n'existe pas.
- Corpus à valider sur téléphone : un album continu (par exemple un live ou un album concept) en MP3 LAME, en M4A et en FLAC ; écouter la transition entre deux pistes. Non fait à ce jour.

## Fondu entre titres

- Media3 ne propose pas de fondu enchaîné : il faudrait deux lecteurs simultanés (et deux sessions audio, l'égaliseur sur chacune) et une gestion de la notification et de l'écran verrouillé pendant le chevauchement.
- Conforme au CDC (« fondu off par défaut ») : le réglage reste PRÉVU, désactivé ; aucune lecture n'est modifiée.

## Pause au retrait du casque (AND-03, même groupe de réglages)

- Réglage réel : `mm:headset` (activé par défaut), envoyé au service par `player_headset` (`setHandleAudioBecomingNoisy`), gardé pour les lecteurs suivants et appliqué au démarrage de l'app.
