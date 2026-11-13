# Fiche LOT-L07 (tranche 1) — Android : lecteur vidéo plein écran paysage

- Statut : tranche 1 faite et vérifiée sur émulateur Android 15 ; téléphone réel et Android 7–11 non vérifiés
- Exigences CDC : AND-07 (vrai plein écran), AND-08 (image dans l'image), AND-13 (pistes et sous-titres), AND-14 (gestes et verrouillage)
- Maquette : `design/design_handoff_android_v2` écran 13

## Réalisé

| Élément | Réalisation |
|---|---|
| Image sous les commandes | La vue Media3 était une SurfaceView au-dessus de la WebView : rien ne pouvait s'y superposer. Elle devient une TextureView (`res/layout/mm_player_texture.xml`) : au-dessus de la page en portrait comme avant, **derrière** la WebView rendue transparente en plein écran ; la page masque alors son contenu (`html[data-video-fullscreen]`) et seule la couche de commandes reste visible |
| Plein écran (AND-07) | `player_fullscreen` : barres système masquées (glissement pour les revoir), orientation paysage (bascule portrait / paysage par le bouton rotation), bord à bord y compris l'encoche (`layoutInDisplayCutoutMode`, marges du `MainActivity` levées) ; Retour Android quitte le plein écran ou ferme le panneau ; la luminosité réglée par le geste revient à celle du système en sortie |
| Commandes (écran 13) | En-tête dégradé : retour, titre, infos techniques réelles (conteneur, codec et hauteur vidéo, codec et canaux audio, nombre de pistes et de sous-titres), image dans l'image si prise en charge, rotation ; centre −10 s / lecture 68 corail / +10 s ; bas : temps, barre de lecture, cadenas, puce CC (langue active), vitesse (0,5× → 2×, mémorisée) ; masquées après 3 s de lecture, un appui les montre / cache |
| Pistes (AND-13) | `player_tracks` / `player_select_track` : pistes audio et sous-titres réels (Media3), coche teal, codec ; « Désactivés » ; « Charger SRT / VTT… » ouvre le sélecteur système, le format est reconnu au contenu (`WEBVTT`, horodatages SRT ; nom et type en repli), fichier refusé avec un message sinon ; ajouté au média en cours à la même position |
| Gestes (AND-14) | Glisser vertical à gauche : luminosité de la fenêtre ; à droite : volume média ; indicateur (rail et valeur) ; double appui ±10 s avec repère ; cadenas : seul son bouton reste ; « Gestes vidéo » devient un réglage réel (activé par défaut, `mm:gestures` mémorisé) |
| Image dans l'image (AND-08) | `player_pip` : Android 8+ et appareil compatible ; ratio de la vidéo ; la lecture continue, les commandes se masquent (événement `pip`) ; `supportsPictureInPicture` dans le manifeste ; pas de pause à la sortie de l'app quand l'image dans l'image est active |

## Écarts

- **Décalage des sous-titres** : PRÉVU dans le panneau (Media3 n'offre pas de décalage des sous-titres) ;
- **Bouton ratio** non fait ;
- pouce du seek 12 dp au lieu de 14 (tailles du composant existant).

## Vérifications

- Tests : `MobileVideoFullscreen.test.tsx` (plein écran natif et page transparente, rotation, double appui et appui simple, verrouillage, pistes réelles et changement), validation Rust des pistes et niveaux (`player::check_track` / `check_level`), réglage « Gestes vidéo » dans `mobile-settings.test.tsx` ; 197 tests frontend, TypeScript, ESLint, clippy.
- Émulateur Android 15 (APK release x86_64) : plein écran paysage bord à bord avec l'image derrière les commandes ; ligne d'infos « WEBM · VP9 480p · Opus 5.1 » ; panneau pistes ; SRT chargé par le sélecteur système et affiché avec ses accents ; image dans l'image avec la vidéo et sans les commandes.
- Défauts trouvés et corrigés pendant la recette : bande d'encoche à gauche ; infos en double ; SRT refusé (nom absent du sélecteur → reconnaissance au contenu) ; sous-titre ignoré (le contrôleur ne transmet pas la configuration, ExoPlayer garde la source si l'URI ne change pas → ajout au lecteur du service, nouvel élément puis retrait de l'ancien) ; image absente en image dans l'image (la page se déclare masquée → la vue reste visible en plein écran).
- Émulateur : l'application a été arrêtée une fois par le gestionnaire de mémoire de l'émulateur (2 Go) pendant le sélecteur de fichiers, et un « ne répond pas » est apparu au démarrage sous forte charge (charge 19,5) ; à revoir sur téléphone réel.
- Non vérifié : téléphone réel, Android 7–11, gestes luminosité / volume à la main (seulement par les tests), MKV multipistes (les fichiers poussés par adb ne sont pas visibles par l'application).
