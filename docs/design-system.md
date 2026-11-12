# Miarina Media — Design System (extrait du handoff Claude Design)

> Note (2026-11-12) : les anciennes maquettes citées ici (`design/*.dc.html` v1, `design/design_handoff_landing_v3/`) ont été retirées du dépôt sur décision du propriétaire ; elles restent consultables dans l'historique git (`git show 63f712a:design/…`). Les maquettes en vigueur sont `design/design_handoff_windows_v2`, `design_handoff_android_v2` et `design_handoff_splash`.

> Source de vérité : `design/Miarina Media - Design System.dc.html` (v1.0), `design/Miarina Media - Windows.dc.html`, `design/Miarina Media - Android.dc.html`.
> Ce document **transcrit** le design approuvé. Il n'invente rien ; les manques sont listés en §13.

## 1. Marque

| Élément | Spécification |
|---|---|
| Nom produit | **Miarina Media** (wordmark Manrope ExtraBold 800, tracking −2 %) |
| Entreprise | MIARINA (overline 13 px / 600, tracking +8 %) |
| Logo « Flow mark » | Tuile 32×32, radius 8, fond `#35C9BD` ; triangle play `M13 9.5v13l10-6.5z` + 3 barres de mouvement (4×2.5, 6×2.5, 4×2.5, radius 1.25) en `#101820`. Taille min 16 px. Zone de protection = 1 longueur de barre (4 unités). |
| Logo sur fond clair | Inversé : tuile `#101820`, glyphes `#35C9BD` |
| Tagline | « Your media. Your freedom. » — site web, installeur, store uniquement, **jamais dans l'UI de l'app** |

Le SVG du logo est inline dans le handoff ; il sera extrait tel quel en `apps/client/src/assets/logo.svg` + icônes d'app (ico/png) générées depuis ce SVG.

## 2. Couleurs

### Dark (défaut)

| Token | Hex | Usage |
|---|---|---|
| `bg` | `#101820` | Fond d'application |
| `surface` | `#182530` | Cartes, panneaux |
| `surface-2` | `#1F2F3B` | Surélevé, menus, hover |
| `sidebar` | `#0D141B` | Barre de titre, navigation, bottom bar |
| `border` | `#243545` | Séparateurs, pistes de progression |
| `border-strong` | `#2A3D4E` | Inputs, boutons secondaires |
| `accent` | `#35C9BD` | Action primaire, progression, focus |
| `accent-hover` | `#4FD6CB` | Hover primaire |
| `accent-press` | `#2BB0A5` | Pressed primaire |
| `accent-ink` | `#062320` | Texte sur accent |
| `accent-subtle` | `#1F3A3C` | Chips sélectionnés, badges |
| `text` | `#F5F7FA` | Texte principal |
| `text-muted` | `#94A3B8` | Texte secondaire |
| `text-faint` | `#64748B` | Placeholders, disabled uniquement |
| `warning` | `#E8B04B` | En pause, « planned » |
| `danger` | `#F07070` | Erreurs, échecs |

### Light

| Token | Hex | Usage |
|---|---|---|
| `bg` | `#F6F8FA` | Fond |
| `surface` | `#FFFFFF` | Cartes |
| `surface-2` | `#EEF2F5` | Surélevé, hover |
| `sidebar` | `#EDF1F4` | Barre de titre, nav |
| `border` | `#DDE3E9` | Séparateurs |
| `border-strong` | `#C9D2DB` | Inputs |
| `accent` | `#35C9BD` | Remplissage primaire, progression |
| `accent-strong` | `#0F8579` | Texte/icônes teal, focus (4.6:1 sur blanc) |
| `accent-ink` | `#062320` | Texte sur accent |
| `accent-subtle` | `#DDF5F2` | Chips sélectionnés |
| `text` | `#101820` | Texte principal |
| `text-muted` | `#526072` | Texte secondaire |
| `warning` | `#A86F0A` | En pause |
| `danger` | `#C93C3C` | Erreurs |

### Couleurs secondaires observées dans les prototypes (à tokeniser)

| Hex | Usage observé |
|---|---|
| `#0A1016` | Fond hors-fenêtre du prototype (non utilisé dans l'app) |
| `#070B0F` / `#0A0F14` | Fond du lecteur vidéo (Windows / Android) |
| `#141F28` | Lignes de file d'attente, en-tête de tableau, input désactivé |
| `#1B2935` | Bordures de la barre de titre/sidebar/panneaux du lecteur |
| `#1B2A36` | Hover de carte |
| `#26384A` / `#2A3D4E` / `#2F4558` | Hover / pressed bouton secondaire, bordure menu/toast |
| `#16302F` + bordure `#35C9BD` | Ligne de format sélectionnée |
| `#2E6A68` / `#5FE0D5` | Bordure / texte de chip sélectionné |
| `#3A4D5E` | Icône d'état vide, ring radio inactif, buffer lecteur |
| `#5B6B7C` | Barre de progression en pause |
| `#8FB3D9` | Catégorie « Audio » (légende, icône note) |
| `#E05A5A` / `#EA6B6B` / `#C94B4B` | Bouton destructif default / hover / pressed |
| `#C8423B` | Hover du bouton fermer de la fenêtre |
| `#05090D` à 62 % | Scrim dialogue / sheet |
| `#2B2616` / `#4A3F1F` | Bannière « PLANNED » (fond / bordure) |
| `#1E2A22` / `#2E4235` | Bandeau « PLANNED » de l'écran Browser |

**Règle :** le teal est réservé à l'action primaire, la sélection, la progression et le focus. **Un seul bouton teal plein par vue.**

## 3. Typographie

Manrope pour toute l'UI ; JetBrains Mono uniquement pour les valeurs machine (URLs, chemins, tailles, vitesses, timecodes, raccourcis). Chiffres de progression en `tabular-nums`.

| Token | Taille / interligne · graisse · tracking |
|---|---|
| `display` | 28 / 34 · 800 · −2 % |
| `title-lg` | 24 / 30 · 700 · −2 % |
| `title` | 18 / 24 · 700 |
| `heading` | 14 / 20 · 700 |
| `body` | 14 / 21 · 500 |
| `body-sm` | 13 / 19 · 500 |
| `caption` | 12 / 16 · 500 |
| `overline` | 11.5 / 16 · 700 · +6 % (majuscules) |
| `mono` | 12.5 / 18 · 500 · JetBrains Mono |

Android : mêmes valeurs en sp, **body +1 (15 sp)**.
Note : les prototypes utilisent aussi 26 px (titre Home Windows), 13.5 px (labels de boutons, titres de lignes), 22 px (titres Android). Ils seront mappés sur les tokens les plus proches seulement si le design le confirme ; sinon valeurs reprises telles quelles (cf. §13).

**Polices** : Manrope (OFL), JetBrains Mono (OFL), Material Symbols Rounded (Apache 2.0) — chargées depuis Google Fonts dans le handoff ; **elles seront embarquées localement** (app offline, pas de requête réseau tierce). Material Symbols sera sous-ensemblé aux icônes utilisées.

## 4. Espacement, rayons, élévation

- **Espacement** base 4 px : `1=4, 2=8, 3=12, 4=16, 5=20, 6=24, 8=32, 10=40, 12=48` (+ `4.5=18`).
- **Rayons** : `xs 4` (badges, kbd) · `sm 6` (boutons, inputs) · `md 8` (lignes, toasts) · `lg 10` (cartes) · `xl 14` (dialogues) · `2xl 24` (sheets Android).
  Android utilise aussi 16 (cartes), 26 (pills primaires), 20/24 (segmented).
- **Élévation** : en dark, la profondeur s'exprime par paliers de surface, pas par ombres.
  `level-0 bg` · `level-1 surface` · `level-2 surface-2 + 0 12px 32px rgba(0,0,0,.4)` (menus, toasts) · `level-3 surface-2 + 0 24px 64px rgba(0,0,0,.5)` (dialogues, sheets).

## 5. Composants

| Composant | Spécification |
|---|---|
| **Bouton primaire** | h 40 (sm 32 / lg 48 desktop), radius 6, `accent` / texte `accent-ink` 13.5/700 ; hover `#4FD6CB`, pressed `#2BB0A5`, focus outline 2 px teal offset 2, disabled `#243545` / `#64748B` |
| **Bouton secondaire** | `surface-2` + bordure `border-strong`, 13.5/600 ; hover `#26384A`, pressed `#2A3D4E`/bordure `#2F4558`, disabled `surface`/`border`/`#64748B` |
| **Ghost icon** | 36×36, radius 6, icône 20, `text-muted` ; hover `#243545` + `text` ; pressed `#2A3D4E` ; disabled `#3A4D5E` |
| **Destructif** | `#E05A5A` / blanc 13.5/700 ; hover `#EA6B6B`, pressed `#C94B4B`, focus outline `#F07070` |
| Boutons Android | 48 tonal / 52 pill primaire radius 26 ; icône 18 px, gap 8 |
| **Input** | h 44, radius 6, fond `bg`, bordure `border-strong`, icône 18, texte mono 13 ; focus bordure teal + halo `0 0 0 3px rgba(53,201,189,.18)` ; erreur bordure `#F07070` + icône `error` + message 12 px danger — **champ de lien (2026-10-17, demande du propriétaire)** : champ vide = indication neutre (bordure teal, icône `info` teal, texte muted, `role=status`) ; lien inutilisable = encadré `warning` (fond 10 %, bordure 30 %, icône `link_off`, texte `fg`) avec bouton « Add https:// » quand cette correction suffit ; disabled fond `#141F28` |
| **Tabs** | 13.5/600, actif = soulignement 2 px teal, inactif `text-muted` |
| **Segmented** | padding 3, radius 7, fond `bg`, segment actif `#2A3D4E` radius 5, 12.5/600 |
| **Chips** | radius 15, 12.5/600 ; actif fond `#1F3A3C`, bordure `#2E6A68`, texte `#5FE0D5` |
| **Toggle** | 38×22 desktop · 52×32 Android ; on `accent` + knob `accent-ink` ; off `#2A3D4E` + knob `#94A3B8` |
| **Menu** | 240 px, padding 6, radius 10, `surface-2`, bordure `#2F4558`, ombre level-2 ; items 34 px, icône 18, raccourci mono 11 ; item destructif en `danger` |
| **Progress** | piste 4 px desktop / 6 px Android, `border` ; actif teal ; pause `#5B6B7C` + libellé warning ; erreur `#F07070` + libellé « Connection lost · retrying in 8 s » ; indéterminé = segment 30 % qui balaie en 1.4 s (statique à 35 % en reduce motion). Largeur interpolée linéairement 900 ms entre ticks de 1 s. |
| **Dialogue** | largeur 420, radius 14, scrim `#05090D` 62 %. Titre = action en question ; corps = conséquence ; boutons = nom de l'action. Esc / scrim = choix sûr ; **focus initial sur le bouton sûr**. |
| **Toasts** | bas-droite, 4 s, max 2 empilés, pause au survol, une action max ; les erreurs persistent jusqu'à fermeture |
| **Bannière PLANNED** | badge mono 10.5/700 `#E8B04B` sur `#1A1204` ; texte « Feature not available in this version. » |

## 6. États

- **Vide** : icône 40 `#3A4D5E`, titre 15/700, texte 13 muted, CTA primaire (ex. « Your library is empty » → « Paste a link »).
- **Chargement** : squelettes `surface-2`, pulse d'opacité .6↔1 en 1.2 s, **affichés seulement après 200 ms**.
- **Aucun média trouvé** : icône `link_off` danger, « No downloadable media found », texte explicatif, boutons « Try again » / « Report link ».
- **Hors ligne** : icône `wifi_off` warning, « You're offline », téléchargements mis en pause et reprise automatique au retour du réseau.

## 7. Motion

| Interaction | Durée | Easing | Note |
|---|---|---|---|
| Hover / press | 80 ms | linear | fond et couleur uniquement |
| Toggle, radio, chip | 150 ms | standard | |
| Repli sidebar | 200 ms | standard | largeur 232 ↔ 64, labels fondus à 40 % |
| Changement d'écran | 160 ms | standard | fondu + montée 8 px du contenu ; la nav ne bouge jamais |
| Dialogue / sheet entrée | 220 ms | standard | scale .98→1 / slide-up 24 px ; scrim 160 ms |
| Dialogue / sheet sortie | 140 ms | exit | inverse, sans scale |
| Toast | 200 ms in · 4 s · 140 ms out | standard | slide 12 px depuis la droite |
| Tick de progression | 900 ms | linear | interpolation entre mises à jour d'1 s |

Easing : `standard = cubic-bezier(.2,0,0,1)`, `exit = cubic-bezier(.3,0,1,1)`. N'animer que `transform`, `opacity` (+ largeur de progression). **Reduce motion et Low-resource mode remplacent tout mouvement par des fondus d'opacité de 120 ms.**

## 8. Accessibilité

- Contraste texte ≥ 4.5:1 (`#F5F7FA`/`#101820` 16.9:1 ; `#94A3B8`/`#182530` 6.3:1 ; `#062320`/`#35C9BD` 9.1:1). `#64748B` jamais pour du texte essentiel.
- Focus : outline 2 px `#35C9BD`, offset 2, via `:focus-visible`, jamais supprimé.
- Cibles : desktop ≥ 32 px avec 4 px d'espacement ; Android ≥ 48 dp.
- L'état d'un téléchargement est porté par texte + icône, jamais par la couleur seule.
- Lignes de progression : `role=progressbar`, `aria-valuenow`, `aria-label` du type « Tears of Steel, 62 percent, 1 minute left » ; annonces live limitées à chaque palier de 10 %.
- Clavier : app entièrement utilisable sans souris ; ordre sidebar → toolbar → contenu ; Esc ferme dialogues et menus.
- Texte à 200 % toléré sur Android ; les titres tronquent, les contrôles ne se chevauchent jamais.

## 9. Iconographie

Material Symbols Rounded, weight 400, grade 0 ; 20 px desktop, 24 px Android, optical size assortie. Outline par défaut ; `FILL 1` pour l'item de nav actif et les glyphes play/pause/skip. Couleur = couleur du texte ; teal seulement pour la sélection ou l'action primaire.

Icônes du handoff : `home download video_library play_circle history settings travel_explore link content_paste music_note playlist_play folder_open pause play_arrow close delete drag_indicator search grid_view view_list closed_caption fullscreen picture_in_picture_alt hard_drive sd_card wifi_off error check_circle more_horiz speed language palette` + celles utilisées dans les prototypes (`remove crop_square left_panel_open/close arrow_back skip_previous/next replay_10 forward_10 volume_up tune format_list_bulleted expand_more refresh lock movie more_vert sort download_done keyboard_arrow_down screen_rotation smartphone folder high_quality stacks notifications battery_saver dark_mode info signal_cellular_alt wifi battery_5_bar link_off`).

## 10. Raccourcis clavier (Windows)

| Action | Raccourci |
|---|---|
| Coller un lien et analyser | Ctrl V |
| Analyser | Enter |
| Rechercher dans la bibliothèque | Ctrl K |
| Afficher/masquer la sidebar | Ctrl B |
| Aller à la section 1–7 | Ctrl 1…7 (Home, Downloads, Library, Player, History, Browser, Settings) |
| Pause / reprise de tout | Ctrl P |
| Lecture / pause | Space |
| Avancer/reculer de 10 s | ← / → |
| Plein écran | F |
| Fermer dialogue / quitter plein écran | Esc |
| Menu contextuel : Play / Show in folder / Copy source link / Rename / Delete | Enter / Ctrl E / Ctrl C / F2 / Del |

## 11. Responsive

| Plage | Comportement |
|---|---|
| ≥ 1440 | Sidebar dépliée 232. Home : 4 actions rapides, grille 2:1 récents/aperçu. Grille bibliothèque auto-fill min 210. Fenêtre de référence 1440×900. |
| 1280–1439 | Même structure ; fenêtre 1280×800. Bibliothèque 4–5 colonnes. Panneau latéral du lecteur 300. |
| 1024–1279 | Sidebar repliée automatiquement à 64. Panneau du lecteur devient un tiroir activable. |
| < 1024 | **Fenêtre minimum 960×640.** L'aperçu Home passe sous les récents. |
| Android 360 dp | Marges 16 dp. Actions rapides 4 colonnes à 52 dp. Bibliothèque 2 colonnes. |
| Android 412 dp | Même grille ; la largeur en plus va au contenu, pas à plus de colonnes. Lecteur paysage = plein écran. |

## 12. Tokens Tailwind (fournis par le handoff)

Le handoff fournit un `tailwind.config.ts` (syntaxe Tailwind v3) fondé sur des variables CSS `--mm-*` en canaux RGB (`rgb(var(--mm-bg) / <alpha-value>)`), `darkMode: 'class'`. **Tailwind 4 (version stable actuelle 4.3.x) est configuré en CSS (`@theme`)** : ces tokens seront transcrits à l'identique dans `apps/client/src/styles/theme.css` (mêmes noms : `bg, surface, surface2, sidebar, line, lineStrong, accent.{DEFAULT,hover,press,ink,strong,subtle}, fg, muted, warn, danger`, mêmes tailles de police, rayons, ombres, easings et durées `fast 80 / base 150 / panel 200 / dialog 220`).

## 13. Manques et incohérences du handoff (à trancher — voir aussi `phase-0-report.md`)

1. **Domaine** : le handoff indique `play.miarina.org` (en-tête du design system, « About » Android) alors que `CLAUDE.md` indique `media.miarina.org`. → Je retiens **media.miarina.org** sauf avis contraire ; le design devra être corrigé.
2. **Thème clair** : tokens fournis, mais **aucun écran maquetté en clair**. Implémentation possible par substitution de tokens ; validation visuelle à faire.
3. **Modes de ressources Eco / Balanced / Performance** exigés par le cahier des charges : **absents du design**. Le design a un toggle « Low-resource mode » (Windows et Android). Il faut une maquette (proposition : segmented 3 valeurs dans Settings › Performance, remplaçant le toggle).
4. **Écran History Android** : absent ; l'onglet « Done » de Downloads joue ce rôle. **Écran Player Windows « vide »** (accès direct par la nav sans média) : non maquetté.
5. **Fonctionnalités hors MVP visibles dans le design** : actions rapides « Playlist » et « Batch links », item de nav « Browser » (déjà marqué PLANNED/Later). Pour Playlist et Batch, aucune maquette d'état « PLANNED » ni de flux — à décider (masquer ou badge PLANNED).
6. **« Report link »** (état « No downloadable media found ») : implique un canal de remontée, incompatible avec le principe local-first sans backend. → À définir (ex. ouvrir une page/issue dans le navigateur, ou retirer).
7. **Non maquettés** : menu contextuel « More » (history, recent Android `more_vert`), dialogue Rename, sélecteur de tri (options), dropdowns des Settings (options des `select`), écran d'erreur disque plein, état « Waiting for Wi-Fi » côté Windows, onglet Subtitles de l'analyse en Android, écran de premier lancement / consentement (téléchargement des composants yt-dlp/FFmpeg), écran « À propos / licences » (obligatoire pour la conformité GPL/LGPL), états light des composants Android.
8. **Langues** : 5 langues proposées (English, Français, Malagasy, Español, Português). Les textes ne sont fournis qu'en anglais. Périmètre i18n du MVP à confirmer.
9. **Échelles de police** hors tokens (26, 22, 13.5, 14.5 px) utilisées dans les prototypes : à confirmer ou à aligner sur les tokens.
10. **Miniatures** : uniquement des placeholders hachurés dans le design ; le rendu réel des miniatures (ratio, recadrage, fallback audio « cover art ») est à préciser.
11. **Fenêtre Windows sans décoration native** (barre de titre custom avec min/max/close) : implique `decorations: false` + zones de drag + gestion du snap Windows 11 (Snap Layouts sur le bouton maximiser) — à confirmer.

## 14. Navigateur intégré (handoff `design/Miarina Media - Browser.dc.html`, reçu le 2026-10-14)

Aucun nouveau token : toutes les couleurs des maquettes existent déjà (`#F4F4F1` n'est que le fond de la page web fictive).

| Élément | Windows (D1–D3, 1280 × 760) | Android (M1–M5, 412 dp) |
|---|---|---|
| Fenêtre / cadre | Fenêtre propre au navigateur : barre de titre `sidebar` 40 px = logo + onglets + min/max/close ; **pas de sidebar de l'app** | Mode plein écran : barre d'adresse en haut, barre de navigation navigateur en bas (back, forward, home, history, `apps` = retour à l'app) |
| Onglets | Bande style Chromium, 220 px (min 120), onglet actif `surface` relié à la barre d'outils, badge teal = médias détectés, bouton `add` | Compteur carré (ouvre M2) ; M2 = grille 2 colonnes de cartes 3:4, bordure teal sur l'onglet actif, chip « N media » |
| Barre d'outils | 48 px `surface` : back, forward, reload, home ; pill d'adresse 34 px (`bg`, bordure `line-strong`, mono 12.5 : hôte en `fg`, chemin en `muted`, cadenas teal) ; chip « 3 media » dans la barre (ouvre D2) ; étoile favori (ambre remplie si enregistré) ; favoris, historique, téléchargements (badge), menu | Pill 44 dp `surface`, hôte mono 14, chip compteur ; ligne de progression de chargement 3 dp teal |
| Barre de favoris | 34 px sous la barre d'outils, optionnelle (Settings → Browser → Show favorites bar) | — (favoris en tête de M4, servent de raccourcis du nouvel onglet) |
| Bouton flottant | Bas-droite du viewport web, retrait 24 px, h 52, radius 26, `accent` ; partie gauche = télécharger le format par défaut de tous les médias détectés, chevron = ouvrir D2 | Centré, 16 dp au-dessus de la barre du bas ; tap = M3 (1er média), appui long = téléchargement immédiat au format par défaut |
| États du bouton | Detecting (après 600 ms, `surface-2`, non cliquable) · 1 média (« Download ») · plusieurs (« Download · 3 ») · Downloading (fond `bg`, barre 3 px, « 62% · 6.4 MB/s », tap → Downloads) · Done (`#1F3A3C`/`#5FE0D5`, « Saved · Play », 4 s) ; masqué si rien n'est détecté ; entrée fondu 200 ms + montée 12 px ; réduit à un cercle 52 px au défilement vers le bas | idem |
| Feuille de formats | D2 : panneau 440 px ancré au-dessus du bouton (pas centré), radius 14, `surface-2`, scrim 62 % ; liste des médias à cases à cocher, onglets Video / Audio only / Subtitles, formats radio (tag « Recommended »), dossier + Change, « Add to queue » / « Download 2 · 728 MB » ; Esc ou scrim ferme | M3 : bottom sheet radius 24, chips pour passer d'un média à l'autre, segmented Video / Audio only, formats 60 dp, « Save to », bouton pill « Download · 372 MB » (réutilise la feuille d'analyse) |
| Historique & favoris | D3 : page interne `miarina://history` dans un onglet (icône `shield_with_heart`) ; nav 220 px Favorites / History / Downloaded from / Recently closed (compteurs) ; grille de favoris 6 colonnes ; historique groupé par jour (heure, initiale, titre, URL, chip « N media », étoile) ; « Clear browsing data » | M4 : via ⋮ → History ; onglets History / Favorites · N ; favoris 4 colonnes ; lignes 64 dp |
| Settings Android | — | M5 : la barre du bas devient Home · Browser · Downloads · Library ; Settings = engrenage dans la barre du haut de Home (et ⋮ du navigateur), plein écran avec flèche retour |

Raccourcis Windows : Ctrl+T nouvel onglet · Ctrl+W fermer · Ctrl+L adresse · Ctrl+H historique · Ctrl+D favori · Ctrl+Shift+S feuille de formats · Alt+←/→ · F5.

Icônes ajoutées : `progress_activity downloading bookmarks star shield_with_heart delete_sweep tab add apps expand_less travel_explore public`.

**Points d'interprétation / à confirmer**
1. D1 montre une fenêtre dédiée (pas de sidebar) : l'entrée « Browser » de la sidebar ouvrira ou focalisera cette fenêtre.
2. Le bouton flottant, la chip et la feuille D2 (avec scrim) **recouvrent la page web**. Techniquement, la page est une webview native distincte : l'UI de l'app ne peut pas dessiner par-dessus sans une couche dédiée → question centrale du spike (`docs/decisions/0001`). L'injection du bouton dans le DOM de la page est exclue (la page pourrait le masquer, l'imiter ou le déclencher).
3. Raccourcis : quand la page a le focus, c'est elle qui reçoit le clavier ; ils devront être interceptés au niveau de la webview (à valider dans le spike).
4. L'onglet « Subtitles » de D2 dépend de la prise en charge des sous-titres (🟡, cf. analyse).

## Landing v3 — 28 octobre 2026
Source approuvée : design/design_handoff_landing_v3/README.md. Coque latérale 232 px dès 900 px ; barre mobile 56 px, libellés masqués sous 400/360 px. Tokens clair/sombre et états repris du handoff. Préférence système par défaut, thème mémorisé ; CSS externe uniquement. Démo explicitement simulée, tailles fictives, reprise conditionnelle ; comparaison limitée aux versions publiques.

## 15. Windows v2 — handoff `design/design_handoff_windows_v2` (reçu le 2026-11-11)

Source : `README.md` du handoff, `Miarina Media Windows v2.dc.html` (prototype cliquable FR/EN) et `Charte Miarina Media.dc.html`. Haute fidélité ; répond au CDC-MIARINA-001.

### Ajouts de tokens (implémentés dans `apps/client/src/styles/theme.css`)

| Token Tailwind | Sombre | Clair | Usage |
|---|---|---|---|
| `coral` | `#FF7A45` | `#FF7A45` | Accent « lire » : bouton play plein, progression de lecture, mini-lecteur |
| `coral-hover` / `coral-press` | `#FF9166` / `#E8642E` | idem | États du bouton play |
| `coral-ink` | `#1F0C03` | idem | Glyphe sur fond corail |
| `coral-strong` | `#FF9166` | `#C2410C` | Texte/icône corail sur fond neutre (titre en cours, shuffle/repeat actifs) |
| `coral-subtle` | `#3A2620` | `#FFE8DE` | Pastilles « lire », badge ● En lecture |
| `warn-subtle` | `#2B2616` | `#FBF1DC` | Bandeau hors ligne |

Règle : teal = télécharger / sélectionner / progresser / focus ; corail = lire. Un seul bouton plein de chaque accent par vue.

### Marque
Logo « 4d » : tuile `#101820`, triangle play corail, trois barres teal (`components/Logo.tsx`, `assets/logo.svg`). Variante Windows avec liseré `#3A4D5E` dans la barre de titre (`<Logo outlined />`). Le jeu complet (PNG Windows, mipmaps Android, web) est dans `design/brand/miarina-media-logo/` ; les icônes d'installation sont remplacées depuis le 2026-11-12 : `src-tauri/icons` généré par `tauri icon` depuis `png/miarina-media-icon-1024.png` (ICO 16, 24, 32, 48, 64 et 256 px), bitmaps NSIS régénérés par `installer/generate-assets.ps1`, mipmaps Android du jeu de marque, icône adaptative Android (fond `#101820`, premier plan triangle corail + barres teal, couche monochrome blanche) en vecteurs dans `gen/android/.../res`.

### Adaptations techniques documentées
- **Bandeau hors ligne** : le texte du prototype annonce « les téléchargements reprendront au retour du réseau ». Le moteur actuel fait des tentatives bornées puis échoue ; le texte est donc « réessaient quelques fois puis s'arrêtent » tant que la reprise automatique au retour réseau (DL-02, L01) n'existe pas.
- **Langue par défaut** : anglais tant que tous les écrans ne lisent pas le catalogue (UX-01, pas de mélange par défaut). Le français est sélectionnable dans Réglages → Language, avec mention explicite de la migration partielle.
- **Fonctions non prêtes** (UX-06) : Albums, Artistes, Dossiers, Playlists, Favoris, égaliseur, « Enregistrer en playlist », pistes/sous-titres vidéo sont affichés désactivés avec badge PRÉVU/PLANNED. A–B, ratio et fenêtre compacte du lecteur vidéo ne sont pas affichés.
- **Supprimer le fichier** : sous Windows, le fichier part à la Corbeille (crate `trash`, approuvé le 2026-11-11), conforme à la maquette ; sous Android, suppression définitive (conforme à la maquette Android v2, écran 11). « Les playlists sont mises à jour » est remplacé par « retiré de la file de lecture » tant que les playlists n'existent pas.
- **Ligne secondaire « artiste »** : sans tags (COM-07, L06), on affiche le site source ou le nom du dossier.

## 16. Android v2 — handoff `design/design_handoff_android_v2` (reçu le 2026-11-11)

18 écrans 412 × 892 dp (Accueil, Navigateur, Formats, Téléchargements, Musique Titres/Playlists/Albums/Artiste, En lecture, File, Son, Notification, Retirer/Supprimer, Réglages, Vidéo paysage, Vidéos, clair/EN). Mêmes tokens que §15 ; nouveau token `coral-chip-border #7A4330` ajouté dans `theme.css` (valeur claire `#F2B8A0` dérivée, à valider). Barre basse à 5 onglets : Accueil, Navigateur, Téléch., Musique, Vidéos. Non implémenté à ce jour : voir `design-implementation-map.md`.

## 17. Splash Android — handoff `design/design_handoff_splash` (reçu le 2026-11-11)

Splash système AndroidX avec logo 4d animé (AVD 1000 ms : barres teal en cascade puis triangle corail), fond `#101820`, branding « Miarina Media » / « MIARINA », sortie en fondu 300 ms ; écran React « Mise à jour de votre bibliothèque » (> 400 ms de migration) et « Le démarrage prend plus de temps » (> 3 s). Correction attendue : `res/drawable/splash_icon.xml` dessine encore l'ancien logo teal. Non implémenté à ce jour.
