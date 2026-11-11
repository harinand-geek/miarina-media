# Handoff : Miarina Media — application Android v2

## Vue d'ensemble
Refonte UI/UX du client Android de Miarina Media (`apps/client`, `MobileShell.tsx` + écrans `features/*/Mobile*.tsx`) répondant au cahier des charges **CDC-MIARINA-001** (`docs/CAHIER-DES-CHARGES-AMELIORATIONS-MIARINA.md`), §5 (lecteur Android inspiré de Lark Player), §7 (téléchargements et navigateur), §4 (socle bibliothèque), §9 et §10.
Deux espaces d'usage :
- **Obtenir** (teal) — usages de type SnapTube : coller/partager un lien, navigateur intégré avec détection, feuille de formats, file de téléchargement.
- **Écouter** (corail) — usages de type Lark Player : bibliothèque musicale (Titres, Playlists, Albums, Artistes, Dossiers, Favoris), Vidéos, mini-lecteur permanent, En lecture, file, égaliseur, vitesse, minuteur, notification et écran verrouillé.

Lark, SnapTube, VLC sont des **références d'usage** : ne reprendre ni marque, ni ressources, ni interface à l'identique (CDC §1, DEP-04).

## À propos des fichiers
Les fichiers de ce dossier sont des **références de design en HTML**, pas du code de production. La tâche est de **recréer ces écrans dans `apps/client`** avec ses patterns existants : React 19, Tailwind 4 (`src/styles/theme.css`, tokens `--mm-*`), stores Zustand (`src/stores/*`), composants `src/components/*` (Button, IconButton, Controls, Icon, Menu, Overlay, ProgressBar, ToastHost, Logo), écrans `src/features/*`. La lecture native reste côté Kotlin/Media3 (`MediaSessionService`) ; React n'est qu'un contrôleur (CDC §5 « Orientation technique », §11). Ne pas embarquer le HTML.

Ouvrir `Miarina Media Android v2.dc.html` dans un navigateur (avec `support.js` à côté). C'est un canevas de 18 écrans 412 × 892 dp (un écran paysage 892 × 412). Le prop `showNotes` affiche ou masque les annotations CDC sous chaque écran.

## Fidélité
**Haute fidélité.** Couleurs, typo, espacements, rayons définitifs ; tokens identiques à `docs/design-system.md` §2 et §15 (Windows v2). Les zones hachurées sont des placeholders (pochettes, miniatures, surface vidéo, page web). Titres/artistes fictifs.

## Shell Android (412 dp de référence, 360 dp toléré)
- **Barre d'état** 36 dp ; **barre de geste** 20 dp (`sidebar`).
- **Barre de navigation basse** 72 dp, fond `sidebar` `#0D141B`, bordure haute `divider` `#1B2935`, 5 onglets égaux : **Accueil** (`home`), **Navigateur** (`travel_explore`), **Téléch.** (`download`, badge nb actifs), **Musique** (`library_music`), **Vidéos** (`video_library`). Libellé 11.5/600 `muted` ; actif 11.5/700 `fg`. Pastille active 56 × 32 radius 16, icône 24 FILL 1 : **teal** (`accent-subtle #1F3A3C` / `#5FE0D5`) pour Accueil/Navigateur/Téléch., **corail** (`coral-subtle #3A2620` / `#FF9166`) pour Musique/Vidéos. Badge 16 dp radius 8 `accent` / `accent-ink` 10/800.
  - Changement vs code actuel (4 onglets Home/Browser/Downloads/Library) : Library est scindée en Musique + Vidéos. Le navigateur masque la barre (il a sa propre barre, cf. écran 02).
- **Mini-lecteur** (COM-05) : 64 dp, marge 0 8 8, radius 14, `surface-2 #1F2F3B`, padding 0 6 0 10, gap 12. Pochette 44 radius 8 ; titre 14/700 + artiste · album 12 `muted` ; bouton `pause_circle` 32 FILL corail-strong `#FF9166` (pas de remplissage plein : un seul bouton corail plein par vue) ; `skip_next` (Accueil) ou `queue_music` (Musique). Filet de progression 2 dp en bas : piste `#2A3D4E`, lecture `#FF7A45`. Tap → En lecture (07). Masqué sur Navigateur, En lecture, Vidéo plein écran, Réglages.
- **Sheets** : radius 24 24 0 0, `surface-2`, poignée 36 × 4 `#3A4D5E`, scrim `#05090D` 62 %, ombre 0 24px 64px rgba(0,0,0,.5). Entrée slide-up 24 px 220 ms `cubic-bezier(.2,0,0,1)`.

## Écrans

### 01 Accueil (PAR-01, COM-04)
Padding 4 16 16, gap 20.
- En-tête 48 : logo 26 + « Miarina Media » 18/800 −1 % ; `search`, `settings` 44 × 44 (point teal 8 si mise à jour dispo).
- Carte lien (padding 16, radius 16, `surface`) : « Coller un lien » 15/700 ; champ 52 radius 10 fond `bg`, mono 14, focus bordure teal + halo `0 0 0 3px rgba(53,201,189,.16)` ; bouton « Coller » 40, `surface-2`, radius 6, 13/600 ; primaire pill 52 radius 26 teal « Analyser le lien → » 15/700 ; aide 12 `muted` centrée « Ou partagez un lien vers Miarina depuis n'importe quelle app. ».
- Actions rapides 4 colonnes : tuile 52 radius 16 `surface`, icône 24 teal ; libellé 12/600 : Audio seul, Playlist (désactivée, badge PRÉVU mono 9/700 `#E8B04B` sur `#1A1204`), Navigateur, Fichiers.
- Carte téléchargements (padding 14, radius 16) : « 2 en cours · 1 en attente » 13/700 + vitesse mono teal ; titre + % mono `muted` ; barre 6 dp radius 3.
- « Reprendre » 15/700 + « Tout voir » 13/600 corail-strong ; carrousel horizontal de cartes 168, miniature 94 radius 10, barre de position 3 dp corail, bouton play rond 28 corail sur la première ; titre 13/600, temps mono 12 `muted`.

### 02 Navigateur (NAV-01..05)
- Barre haute `sidebar` : pill d'adresse 44 radius 22 `surface` (cadenas 18 teal, hôte mono 14 `fg` + chemin `muted`, chip médias 30 radius 15 `#1F3A3C`/bordure `#2E6A68`/`#5FE0D5` « movie 2 ») ; compteur d'onglets (carré 24 bordure 2 radius 6) ; `more_vert`. Ligne de chargement 3 dp teal en bas.
- Page web (placeholder `#F4F4F1`).
- **Bouton flottant** centré, 16 dp au-dessus de la barre : h 52 radius 26 teal, « download Télécharger · 2 » 15/800 + séparateur + chevron `expand_less`. Tap → 03 ; appui long → téléchargement direct au format par défaut. N'apparaît qu'avec un média détecté.
- Barre basse 60 : back, forward (désactivé `#64748B`), home, bookmarks, `apps` teal (= retour à Miarina).

### 03 Feuille de formats (DL-04/05/08/10)
Sheet pleine largeur, padding 10 16 0, gap 14. Vignette 96 × 54 + titre 16/800 + source mono 12. Chips médias (32 radius 16 ; actif teal-subtle). Segmented Vidéo / Audio seul / Sous-titres (padding 3, radius 20, fond `bg`, actif `#2A3D4E` radius 17, 13/700). Lignes format 60 radius 12 : sélectionnée fond `#16302F` bordure `#35C9BD`, radio teal, tag « Recommandé » 10.5/700 ; sinon `surface` bordure `line`. Libellé 14.5/700 + détail mono 12 + taille mono 13. Dossier (`sd_card`, « Movies/Miarina · 18,2 Go libres », « Changer » teal). Règle réseau mesuré (toggle 38 × 22). Boutons : « À la file » secondaire pill 52 + primaire « Télécharger · 372 Mo ». Audio seul : MP3 320/256/192/128 (convertis), M4A original, FLAC si supporté.

### 04 Téléchargements (DL-01/02/06/09)
Titre 22/800 + bouton « Tout » pause (pill 40 secondaire). Segmented En cours · 5 / Terminés · 24 / Échecs · 1. Bandeau warning (fond `#2B2616`, bordure `#4A3F1F`, radius 12) « Réseau mobile. 1 fichier attend le Wi-Fi… » + action « Lancer ». Ligne : vignette 72 × 44 ; titre 14/700 + format mono 11 ; barre 6 dp ; état **icône + texte** (jamais couleur seule) :
- Téléchargement — teal, `downloading`, « 62 % · 1 min »
- Conversion MP3 · étape 2/2 — teal, `autorenew` (distincte du téléchargement, DL-06)
- Connexion perdue · nouvel essai 8 s — danger `#F07070`, `wifi_off`, « reprise 34 % » (octets vérifiés, DL-02)
- En pause — barre `#5B6B7C`, texte warning, `pause_circle`
- En attente du Wi-Fi — `muted`, `wifi`
Action droite 40 : pause / close / refresh / play_arrow / more_vert.

### 05 Musique · Titres (COM-07/09, AND-06, PAR-07)
Titre 22/800 + `search` + `create_new_folder` (importer dossier SAF). Onglets scrollables Titres / Playlists / Albums / Artistes / Dossiers / Favoris (14/600, actif 14/700 `fg` + soulignement 2 dp **corail**). Bouton « shuffle Lecture aléatoire » pill 40 corail plein 14/800 + « 248 titres » + tri « Ajout récent ». Ligne 64 : pochette 48 radius 8 ; titre 14.5/700 ; « artiste · durée » 12.5 `muted` ; cœur 20 FILL `#FF9166` si favori ; `more_vert`. **En cours** : titre `#FF9166` + overlay `equalizer` sur la pochette. **Fichier introuvable** : opacité .72, « folder_off Fichier introuvable · **Localiser** » `#E8B04B`.

### 06 Musique · Playlists (COM-06/11/13)
3 tuiles auto 88 radius 14 : Favoris (fond `#3A2620`, cœur corail), Récents, Plus écoutés (`surface`). « Mes playlists · 5 » + bouton M3U (import/export). « + Nouvelle playlist » (tuile 56 pointillée `#3A4D5E`). Ligne 64 : mosaïque 2×2 56 radius 10, nom 14.5/700, « N titres · durée » ; une playlist importée affiche « 2 manquants ».

### 07 En lecture (COM-02/12, AND-09/11/15)
Fond dégradé `#2A2320 → #141C24 (45 %) → #0A0F14` (teinté par la pochette ; neutre si absente). En-tête 56 : `keyboard_arrow_down`, « LECTURE DEPUIS » 11/700 +6 % `muted` + source 13/700, `more_vert`. Pochette carrée marge 36, radius 20, ombre niveau 3. Titre 24/800 + artiste · album 15 `muted` + cœur 28. Seek : piste 4 dp `rgba(245,247,250,.18)`, lecture corail, pouce 14 ; temps mono 12. Commandes : shuffle 48 (actif corail + point 4), prev 56 (icône 38), **play/pause 76 corail** (icône 42 `#1F0C03`), next 56, repeat 48 (off → file → titre `repeat_one`). Barre d'accès : Vitesse (valeur mono 14/700 « 1,25× »), Égaliseur (`graphic_eq`), Minuteur (`bedtime`, libellé = temps restant « 28 min »), Paroles (`lyrics`, LRC local), File · N. Actif = corail + libellé.

### 08 File de lecture (COM-03, AND-05)
Sheet depuis top 120. En-tête « File de lecture » 18/800 + « 12 titres · 47 min restantes » + shuffle/repeat. Ligne 60 radius 10 : `drag_indicator`, pochette 40, titre/artiste, `close` (retirer) ; titre courant fond `#3A2620`, texte corail, icône `equalizer`. Pied : « Enregistrer en playlist » (pill 48 secondaire) + « Vider » ghost ; mention 11.5 `#64748B` « Vider la file ne supprime aucun fichier. ». Gestes : glisser = réordonner, balayer = retirer ; menu titre → « Lire ensuite » insère après le courant.

### 09 Son (AND-09/10/11)
Sheet depuis top 96, gap 18. Égaliseur : titre 18/800 + « Réinitialiser » + toggle Android 52 × 32 **corail** (knob `#1F0C03`). Préréglages chips 34 radius 17 : Neutre, Basses (actif : `#3A2620`, bordure `#7A4330`, `#FF9166`), Voix, Rock, Classique, Personnalisé. 6 bandes verticales (60, 230, 910, 3,6k, 9k, 14k Hz) : rail 4 × 140 `#2A3D4E`, remplissage corail, pouce 20 blanc bordure 3 corail, valeur dB mono 11. Si le périphérique ne supporte pas l'égaliseur : section remplacée par une explication. Vitesse : segmented mono 0,5× / 0,75× / 1× / 1,25× / 1,5× / 2× (persistée). Minuteur : Off / 15 / 30 / 60 min / Fin du titre + statut « La musique s'arrêtera dans **28:14**. L'app reste ouverte. »

### 10 Écran verrouillé · notifications (AND-01..04, DL-09)
Notification média (MediaSession) 380 radius 24 `rgba(31,47,59,.92)` : en-tête logo 16 + « Miarina Media » + sortie audio (« Casque BT ») ; pochette 64 + titre 16/800 + artiste ; cœur ; seek 4 dp corail + temps ; shuffle, prev, play 56 corail, next, close. Notification téléchargement séparée : `downloading` teal, « 2 téléchargements · 6,4 Mo/s », barre teal, « Pause ». Rendu final = gabarits système Android ; reprendre contenu et actions, pas le style exact.

### 11 Retirer ou supprimer (COM-10, P0)
Sheet. Titre « Retirer « <titre> » ? » 19/800 ; texte 14 `muted`. Deux options radio (radius 12, padding 14) : **Retirer de la bibliothèque** (défaut, « Le fichier reste sur l'appareil. ») / **Supprimer le fichier de l'appareil** (« Définitif. Le fichier suivant sera effacé : » + chemin mono 11.5 + taille). Boutons pill 52 : **Annuler** (focus initial, anneau 2 teal) / « Retirer » secondaire `#2A3D4E`. Si « Supprimer » est choisi, le bouton devient destructif `#E05A5A` blanc « Supprimer le fichier ». Aucune suppression en cascade.

### 12 Réglages (UPD-02/04/06, UX-06)
En-tête retour + « Réglages » 20/800. Carte mise à jour (radius 16, bordure `#2E6A68`) : icône `system_update_alt` 40 teal-subtle ; « 0.1.8 est prête » 15/700 + « Canal Stable · 128,4 Mio » ; « verified Signature et SHA-256 vérifiées » `#5FE0D5` ; avertissement `info` warning « 2 téléchargements en cours… mis en pause avant l'installation ; bibliothèque et playlists conservées. » ; « Installer maintenant » primaire pill 44 + « Plus tard ». États précédents : disponible → téléchargement (barre) → prêt. Jamais d'installation forcée.
PERFORMANCE : segmented Éco (`battery_saver`) / Équilibré (`balance`) / Performance (`speed`) + description de l'effet (remplace le toggle « Low-resource mode »).
LECTURE : lignes 60 (icône 22, titre 14.5/600, description 12.5) : Reprendre où j'en étais (on), Pause au retrait du casque (on), Gestes vidéo (on), Fondu entre titres (off par défaut), Lecture sans blanc gapless (badge PRÉVU, AND-12).

### 13 Lecteur vidéo plein écran, paysage (AND-07/08/13/14)
892 × 412, fond noir, surface native Media3. En-tête dégradé 96 : retour, titre 16/700 + infos techniques réelles mono 11 (« MKV · H.264 1080p · AAC 2.0 · 2 pistes · 3 ST »), PiP (`picture_in_picture_alt`, si supporté), rotation. Indicateur geste luminosité à gauche (rail 4 × 96, valeur mono) ; volume symétrique à droite. Centre : replay_10, **play/pause 68 corail**, forward_10. Sous-titre 20/600 fond `rgba(0,0,0,.65)` radius 4. Barre basse : temps mono 12, seek (buffer `#3A4D5E`, lecture corail, pouce 14), cadenas (verrouillage des commandes), chip CC « FR » (corail 18 %), vitesse mono, ratio. **Panneau pistes** 340 à droite `rgba(24,37,48,.96)` : PISTE AUDIO (✓ teal, libellé + codec mono), SOUS-TITRES (Désactivés / internes / « Charger SRT / VTT… » teal), Décalage −/+ 0,1 s (mono). Gestes : gauche luminosité, droite volume, double-tap ±10 s ; désactivables, doublés par boutons.

### 14 Vidéos (COM-04/09, AND-06)
Titre + recherche + bascule vue liste. Chips filtres : Toutes · 36 (actif teal), En cours · 4, dossiers MediaStore. Grille 2 colonnes gap 16/12 : miniature 16:9 radius 10, durée mono 10.5/700 sur `rgba(5,9,13,.8)`, barre de reprise 3 dp corail si entamée ; titre 13.5/700 + format mono 11.

### 15 Musique · Albums (COM-07, L06)
« 18 albums » + tri « A → Z ». Grille 2 colonnes : pochette carrée radius 12 + bouton play rond 36 `rgba(16,24,32,.85)` icône corail ; nom 14/700, « artiste · N titres » 12.5. Sans tag : « Album inconnu · Artistes divers ».

### 16 Fiche artiste (COM-07/09)
Avatar cercle 112 (placeholder `person` ; photo uniquement si fournie, aucune récupération distante). Nom 24/800 + « 3 albums · 27 titres · 1 h 48 ». « Tout lire » corail plein pill 48 + « Aléatoire » secondaire. Albums en carrousel (112). Titres : numéro mono 12 (▶ corail si en cours), titre 14.5/700, album · durée.

### 17–18 Thème clair · anglais (UX-01, UX-05)
Accueil et Musique › Titres en clair et en EN pour valider tokens et catalogue. Clair : bg `#F6F8FA`, surfaces `#FFFFFF` bordure `#DDE3E9`, nav `#EDF1F4`, texte `#101820` / `#526072`, teal texte `#0F8579` sur `#DDF5F2`, corail texte `#C2410C` sur `#FFE8DE`, warning `#A86F0A` / `#FBF1DC`. Remplissages teal/corail pleins inchangés. Libellés EN : Home, Browser, Downloads, Music, Videos ; Paste a link, Analyze link, Audio only, PLANNED, Continue watching, See all, Songs, Artists, Folders, Favorites, Shuffle play, Recently added, File not found · Locate.

## Règles d'interaction
- **Teal = obtenir / sélectionner / progresser / focus. Corail = lire.** Un seul bouton plein de chaque accent par vue.
- Cibles ≥ 48 dp (44 dp minimum sur icônes d'en-tête). Texte 200 % toléré : titres tronqués, contrôles jamais superposés.
- Android Back : ferme sheet → En lecture → Réglages → page précédente du navigateur → Accueil → quitte (cf. `useAndroidBack` existant).
- Motion : hover/press 80 ms ; toggles/chips 150 ms ; changement d'écran fondu + montée 8 px 160 ms ; sheet 220 ms in / 140 ms out ; progression interpolée 900 ms linéaire. Reduce motion / Éco : fondus 120 ms.
- Focus visible : outline 2 teal offset 2. TalkBack : état du téléchargement et de la lecture en texte (`aria-label` « Tears of Steel, 62 pour cent, 1 minute restante »).
- Toutes les chaînes via le catalogue FR/EN (`src/i18n`). Fonctions non validées : désactivées + badge PRÉVU/PLANNED (UX-06).
- Fichier : distinguer partout **Retirer** (bibliothèque) et **Supprimer** (disque).

## État (correspondance stores)
- `ui` : tab (`home|browser|downloads|music|videos`), musicView (`songs|playlists|albums|artists|folders|favorites`), nowPlayingOpen, sheet (`formats|queue|sound|remove|mediaActions|null`), settingsOpen.
- `player` (contrat COM-01, propriétaire = `MediaSessionService`) : mediaId, kind, state (`idle|loading|ready|playing|paused|buffering|ended|error`), position, duration, queue[], currentIndex, shuffle, repeat (`off|all|one`), rate, eq {supported, enabled, preset, bands[6]}, sleepTimer {mode, endsAt}, audioTrack, subtitle, subtitleDelay, controlsLocked.
- `library` : tracks, albums, artists, folders (scan state, availability), playlists, favorites, history (effaçable, COM-13), positions par média (COM-04).
- `downloads` : tasks (`queued|waiting_wifi|downloading|converting|paused|error|done`), bytesVerified, retryAt.
- `settings` : perfMode (`eco|balanced|performance`), meteredRule, resume, pauseOnUnplug, videoGestures, crossfade, theme, lang.
- `updates` : phase (`none|available|downloading|ready|installing`), channel, verified.

## Design tokens
Sombre : bg `#101820` · sidebar `#0D141B` · surface `#182530` · surface-2 `#1F2F3B` · line `#243545` · line-strong `#2A3D4E` · divider `#1B2935` · fg `#F5F7FA` · muted `#94A3B8` · faint `#64748B` · accent `#35C9BD` (ink `#062320`, subtle `#1F3A3C`, chip border `#2E6A68`, chip text `#5FE0D5`, ligne sélectionnée `#16302F`) · coral `#FF7A45` (strong `#FF9166`, ink `#1F0C03`, subtle `#3A2620`, chip border `#7A4330`) · warning `#E8B04B` (subtle `#2B2616`, bordure `#4A3F1F`, badge PRÉVU fond `#1A1204`) · danger `#F07070` · destructif `#E05A5A` · pause `#5B6B7C` · buffer/ring `#3A4D5E` · fond lecteur `#0A0F14` · scrim `#05090D` 62 %.
Nouveau token : `coral-chip-border #7A4330` (chips corail actifs) — à ajouter dans `theme.css`.
Clair : voir écrans 17–18 ci-dessus et `design-system.md` §2/§15.
Typo : Manrope (titres écran 22/800 −1 %, titre lecteur 24/800, section 15/700, ligne 14.5/700, body 14/500 — Android body 15 sp, caption 12.5/12, nav 11.5, overline 11.5/700 +6 %) ; JetBrains Mono 10–14 pour URL, chemins, tailles, vitesses, temps, codecs, dB (tabular-nums).
Rayons : 4 badges · 6 boutons compacts · 8 pochettes liste · 10 champs/miniatures · 12 lignes format/options · 14 mini-lecteur/tuiles · 16 cartes · 20 pochette En lecture / segmented · 24 sheets · pills = h/2.
Espacement : base 4 ; marges écran 16 dp ; gap sections 14–20.
Ombres : niveau 2 `0 12px 32px rgba(0,0,0,.4)` ; niveau 3 `0 24px 64px rgba(0,0,0,.5)`.

## Assets
- `assets/miarina-media-icon.svg`, `assets/miarina-media-glyph-mono-white.svg` (logo « 4d » : tuile `#101820`/`#0D141B`, triangle corail, barres teal — déjà dans `components/Logo.tsx`). Mipmaps Android complètes : `design/brand/miarina-media-logo/android/`.
- Icônes Material Symbols Rounded (sous-ensemble embarqué). À ajouter au sous-ensemble : `library_music queue_music equalizer graphic_eq bedtime lyrics shuffle repeat repeat_one skip_previous skip_next pause_circle favorite folder_off create_new_folder upload_file playlist_add clear_all trending_up person album downloading autorenew wifi_off bluetooth headphones system_update_alt verified battery_saver balance gesture blur_linear all_inclusive light_mode aspect_ratio expand_less apps bookmarks drag_indicator`.
- Polices : Manrope, JetBrains Mono (OFL), embarquées localement.

## Fichiers
- `Miarina Media Android v2.dc.html` — canevas des 18 écrans (template + données dans la classe `Component`). `support.js` requis pour l'ouvrir.
- Références : `design/design_handoff_windows_v2/` (tokens et règles partagés), `docs/design-system.md`, code actuel `apps/client/src/app/MobileShell.tsx`, `features/home/MobileHome.tsx`, `features/player/MobilePlayer.tsx`, `features/library/MobileLibrary.tsx`, `features/downloads/MobileDownloads.tsx`, `features/settings/MobileSettings.tsx`.

## Ordre de mise en œuvre conseillé (lots CDC)
L02 contrat lecteur + store `player` → L03 `MediaSessionService` + notification/écran verrouillé (10) + mini-lecteur → shell 5 onglets → L06 Musique (05, 06, 15, 16) + Vidéos (14) + dialogue Retirer/Supprimer (11) → En lecture / File (07, 08) → L07 Son (09) + vidéo plein écran (13) → L09 Réglages mise à jour (12) → L10/L11 formats, téléchargements, navigateur (02–04). Recette sur téléphone ARM64 physique obligatoire (Bluetooth, verrouillage, batterie).
