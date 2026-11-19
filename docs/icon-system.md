# Système d'icônes — Phosphor

Décision : [0007](decisions/0007-flutter-migration.md). Jeu retenu le 2026-11-19 sur planche comparative (Material Symbols Rounded, Phosphor, Fluent, Hugeicons) : **Phosphor 2.1.1** (`@phosphor-icons/core`, licence MIT, copyright Phosphor Icons).

## Règles d'usage

| Usage | Graisse | Exemple |
|---|---|---|
| Interface courante (barres, listes, menus, réglages) | **Regular** | loupe, réglages, dossier |
| État actif (onglet ou entrée de sidebar sélectionnés, favori actif) | **Fill**, couleur corail `#FF7A45` ou teal `#35C9BD` pour Obtenir | onglet Musique actif, cœur rempli |
| Transport (lire, pause, précédent, suivant) | **Fill** | bouton lire 44 corail |
| Écrans vides et illustrations d'état | **Duotone** (opacité secondaire 20 %) | « Aucune musique », « Hors ligne » |

- Tailles : 16, 20, 24, 28 (logiques) ; les cibles tactiles restent ≥ 32 px Windows et ≥ 48 dp Android, l'icône est centrée dedans.
- Couleur : héritée du texte (`fg`, `muted`, `faint`), jamais de dégradé sur une icône.
- Changement d'état Regular → Fill : fondu croisé 120 ms, sans rotation ni rebond, sauf le cœur (échelle 1 → 1,15 → 1 en 180 ms, voir le handoff § 03).
- Aucun emoji ni icône de marque tierce dans l'interface. Logo Miarina inchangé (`design/brand/`).

## Intégration Flutter

Police d'icônes générée depuis les SVG officiels, une par graisse utilisée (regular, fill, duotone en deux couches), limitée aux glyphes de la table ci-dessous, avec une classe Dart `MmIcons` générée. Pas de dépendance au paquet `phosphor_flutter` (dernière publication il y a environ deux ans, ancien jeu de 772 icônes). Le script de génération et les SVG source sont versionnés avec l'application pour que la police soit reproductible.

## Glyphes à dessiner

Phosphor n'a pas de version chiffrée de « reculer / avancer de N secondes ». Trois glyphes sont dessinés sur la grille Phosphor (viewBox 256, trait 16, extrémités et jonctions arrondies), en regular et fill : `replay-10`, `forward-10`, `forward-30` (flèche circulaire `arrow-counter-clockwise` / `arrow-clockwise` ouverte + chiffre en Manrope 700). L'indicateur « en lecture » est animé (trois barres dessinées) ; le glyphe `equalizer` sert de repli statique quand le mouvement réduit est actif.

## Correspondance des 127 icônes de la maquette

Les noms de gauche sont ceux des prototypes `design/design_handoff_lecture_ecouter/*.dc.html` (Material Symbols). Colonne « Fill » : le glyphe existe aussi en version pleine. Les lignes marquées « Maquette » ne servent qu'aux maquettes (barre d'état simulée, documentation) et ne sont pas embarquées.

| Maquette (Material) | Phosphor | Fill | Usage |
|---|---|---|---|
| `add` | `plus` | oui | Ajouter |
| `album` | `vinyl-record` | oui | Albums |
| `arrow_back` | `arrow-left` | oui | Retour |
| `arrow_forward` | `arrow-right` | oui | Suivant / flux |
| `arrow_upward` | `arrow-up` | oui | Monter (réordonner) |
| `aspect_ratio` | `frame-corners` | oui | Ratio vidéo |
| `audio_file` | `file-audio` | oui | Fichier audio |
| `audiotrack` | `music-note` | oui | Piste audio |
| `auto_awesome` | `magic-wand` | oui | Smart Queue (P1) |
| `battery_full` | `battery-full` | oui | Maquette : barre d’état Android (non embarquée) |
| `bedtime` | `moon` | oui | Minuteur de sommeil |
| `bluetooth` | `bluetooth` | oui | Sortie Bluetooth |
| `bookmark_add` | `bookmark-simple` | oui | Ajouter un signet (Focus) |
| `broken_image` | `image-broken` | oui | Pochette illisible |
| `call` | `phone` | oui | Maquette : interruption d’appel |
| `cast` | `screencast` | oui | Diffuser (FUTUR) |
| `check` | `check` | oui | Validé |
| `check_box` | `check-square` | oui | Case cochée (fill) |
| `check_box_outline_blank` | `square` | oui | Case vide |
| `check_circle` | `check-circle` | oui | Terminé / vu |
| `chevron_left` | `caret-left` | oui | Retour compact |
| `chevron_right` | `caret-right` | oui | Ligne cliquable |
| `close` | `x` | oui | Fermer |
| `closed_caption` | `subtitles` | oui | Sous-titres |
| `content_copy` | `copy` | oui | Copier les détails |
| `content_cut` | `scissors` | oui | Boucle A–B |
| `contrast` | `circle-half` | oui | Thème / contraste |
| `create_new_folder` | `folder-plus` | oui | Ajouter un dossier |
| `crop_square` | `crop` | oui | Recadrage vidéo |
| `dark_mode` | `moon-stars` | oui | Thème sombre |
| `database` | `database` | oui | Base à réparer |
| `delete` | `trash` | oui | Supprimer (Corbeille) |
| `description` | `file-text` | oui | Fichier .nfo / texte |
| `download` | `download-simple` | oui | Obtenir |
| `download_done` | `check-circle` | oui | Téléchargé |
| `drag_handle` | `equals` | oui | Poignée de feuille |
| `drag_indicator` | `dots-six-vertical` | oui | Poignée de réordonnancement |
| `drag_pan` | `hand-grabbing` | oui | Glisser-déposer |
| `drive_file_move` | `folder-simple-dashed` | oui | Localiser un fichier déplacé |
| `edit` | `pencil-simple` | oui | Modifier |
| `edit_note` | `note-pencil` | oui | Éditer les tags |
| `equalizer` | `sliders-horizontal` | oui | Réglages du son / égaliseur |
| `error` | `warning-circle` | oui | Erreur |
| `expand_more` | `caret-down` | oui | Déplier / réduire le lecteur |
| `favorite` | `heart` | oui | Favori (fill quand actif) |
| `file_open` | `file-plus` | oui | Ouvrir des fichiers |
| `filter_list` | `funnel-simple` | oui | Filtres |
| `folder` | `folder` | oui | Dossier |
| `folder_off` | `folder-dashed` | oui | Dossier indisponible |
| `folder_open` | `folder-open` | oui | Ouvrir le dossier |
| `forward_10` | *forward-10* (dessiné) | — | Avancer 10 s (glyphe dessiné) |
| `forward_30` | *forward-30* (dessiné) | — | Avancer 30 s (glyphe dessiné) |
| `fullscreen` | `corners-out` | oui | Plein écran |
| `fullscreen_exit` | `corners-in` | oui | Quitter le plein écran |
| `graphic_eq` | `equalizer` | oui | Indicateur « en lecture » ; animé en 3 barres dessinées, glyphe en repli si mouvement réduit |
| `grid_view` | `squares-four` | oui | Vue grille |
| `headphones` | `headphones` | oui | Casque |
| `headset_off` | `plugs` | oui | Pause au débranchement du casque |
| `history` | `clock-counter-clockwise` | oui | Historique |
| `home` | `house` | oui | Accueil Écouter |
| `info` | `info` | oui | Information |
| `ios_share` | `export` | oui | Exporter (M3U, JSON) |
| `keyboard` | `keyboard` | oui | Raccourcis |
| `keyboard_arrow_down` | `caret-down` | oui | Menu déroulant |
| `layers` | `stack` | oui | Doublons |
| `library_music` | `music-notes` | oui | Musique (section) |
| `light_mode` | `sun` | oui | Thème clair |
| `link_off` | `link-break` | oui | Lien cassé / hors ligne |
| `lock` | `lock-simple` | oui | Verrou des gestes vidéo |
| `lock_open` | `lock-simple-open` | oui | Déverrouiller |
| `lyrics` | `quotes` | oui | Paroles |
| `more_horiz` | `dots-three` | oui | Plus d’actions |
| `more_vert` | `dots-three-vertical` | oui | Menu de ligne (Android) |
| `mouse` | `mouse` | oui | Maquette : documentation des interactions |
| `movie` | `film-slate` | oui | Cinéma (section) |
| `music_note` | `music-note` | oui | Titre |
| `music_off` | `music-notes-minus` | oui | Aucune musique (vide) |
| `new_releases` | `seal-check` | oui | Nouveautés |
| `notifications` | `bell` | oui | Notifications |
| `offline_bolt` | `lightning` | oui | Mode Éco / performance |
| `open_in_full` | `arrows-out-simple` | oui | Agrandir (mini-lecteur → fenêtre) |
| `pause` | `pause` | oui | Pause (fill) |
| `perm_media` | `images` | oui | Accès aux médias (autorisation) |
| `person` | `user` | oui | Artiste (repli) |
| `photo_camera` | `camera` | oui | Capture d’image |
| `photo_library` | `images-square` | oui | Choisir une image |
| `picture_in_picture_alt` | `picture-in-picture` | oui | Image dans l’image |
| `play_arrow` | `play` | oui | Lire (fill) |
| `play_circle` | `play-circle` | oui | Lire (cartes) |
| `playlist_add` | `list-plus` | oui | Ajouter à une playlist |
| `playlist_play` | `playlist` | oui | Playlists |
| `podcasts` | `microphone` | oui | Podcasts |
| `push_pin` | `push-pin` | oui | Épingler |
| `queue_music` | `queue` | oui | File de lecture |
| `radio_button_checked` | `radio-button` | oui | Option choisie (fill) |
| `radio_button_unchecked` | `circle` | oui | Option |
| `record_voice_over` | `user-sound` | oui | Voix renforcée (P1) |
| `remove` | `minus` | oui | Retirer |
| `remove_circle` | `minus-circle` | oui | Retirer de la file |
| `repeat` | `repeat` | oui | Répéter (repeat-once pour un titre) |
| `replay_10` | *replay-10* (dessiné) | — | Reculer 10 s (glyphe dessiné) |
| `rule` | `list-checks` | oui | Règles (playlist intelligente) |
| `schedule` | `clock` | oui | Durée / fin estimée |
| `school` | `graduation-cap` | oui | Cours |
| `sd_card_alert` | `hard-drive` | oui | Carte SD / disque retiré (avec pastille d’alerte) |
| `search` | `magnifying-glass` | oui | Recherche |
| `search_off` | `magnifying-glass-minus` | oui | Aucun résultat |
| `settings` | `gear-six` | oui | Réglages |
| `shield` | `shield-check` | oui | Confidentialité |
| `shuffle` | `shuffle` | oui | Aléatoire |
| `signal_cellular_alt` | `cell-signal-full` | oui | Maquette : barre d’état Android (non embarquée) |
| `skip_next` | `skip-forward` | oui | Suivant (fill) |
| `skip_previous` | `skip-back` | oui | Précédent (fill) |
| `sort` | `sort-ascending` | oui | Trier |
| `sort_by_alpha` | `text-aa` | oui | Tri alphabétique |
| `speed` | `gauge` | oui | Vitesse de lecture |
| `subject` | `text-align-left` | oui | Texte / transcription (FUTUR) |
| `touch_app` | `hand-tap` | oui | Maquette : documentation des gestes |
| `trending_up` | `trend-up` | oui | Les plus écoutés |
| `upload_file` | `file-arrow-up` | oui | Importer un fichier |
| `usb` | `usb` | oui | Disque amovible |
| `usb_off` | `usb` | oui | Disque débranché (état atténué) |
| `view_carousel` | `slideshow` | oui | Vue carrousel |
| `view_list` | `list` | oui | Vue liste |
| `volume_down` | `speaker-low` | oui | Volume bas |
| `volume_up` | `speaker-high` | oui | Volume (speaker-slash si muet) |
| `wifi_off` | `wifi-slash` | oui | Hors ligne |
