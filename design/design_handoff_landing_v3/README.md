# Handoff : Landing Miarina Media — v3 (« page-application »)

## Vue d'ensemble
Refonte de la page d'accueil de `media.miarina.org` (`apps/website/src/pages/Home.tsx`). Le contenu, les textes et les données sont **identiques** au site actuel (`release.ts`, `Home.tsx`) ; seule la présentation change. Direction : la page reprend le langage visuel de l'application (barre latérale, champ de lien, lignes de format, segmented, chips, barres de progression) et intègre une **démo interactive** du flux « lien → format → fichier ».

## À propos des fichiers
`Miarina Media - Landing v3.dc.html` et `Miarina Media - Landing.html` (autonome, hors ligne) sont des **références de design en HTML**, pas du code de production. Il faut **recréer** ce design dans `apps/website` (React + Vite, pré-rendu, `site.css`) en respectant ses contraintes :
- pas de script ni de style en ligne (CSP du vhost, `docs/decisions/0003`) → tout passe en classes dans `site.css` ;
- polices et icônes auto-hébergées ; toute nouvelle icône Material doit être ajoutée au sous-ensemble `icons.woff2` ;
- le HTML pré-rendu doit rester lisible sans JavaScript (la démo, le filtre plateformes, le scroll spy et le menu mobile sont des améliorations progressives).

Dans la référence, les styles sont en ligne et le thème passe par des variables CSS posées par JS : c'est propre au prototype, pas à reproduire tel quel.

## Fidélité
**Haute fidélité.** Couleurs, typographie, espacements et interactions sont définitifs. Exception : les tailles de fichiers de la démo (372 Mo, etc.) sont des **données d'exemple** et doivent rester présentées comme telles.

## Structure de la page

### Coque
- Racine : `display:flex; align-items:flex-start`.
- **≥ 900 px** : `aside` 232 px, `position:sticky; top:0; height:100vh`, fond `sidebar`, bordure droite `line`, padding 16/12, gap 4.
  - Marque : logo 28 px + « Miarina Media » 15.5/800, tracking −.02em, padding 6/8/20.
  - Nav : 9 items h 38, radius 6, padding 0 10, gap 12, icône 20, texte 13.5/600 `muted` ; hover `surface2` + `fg` ; **actif** (scroll spy) fond `accent-subtle`, texte `accent-text`, 700.
  - Ordre : Télécharger (download), Fonctionnalités (tune), Navigateur (link), Formats (movie), Bibliothèque (video_library), Confidentialité (visibility_off), Plateformes (desktop_windows), FAQ (add), Versions (schedule).
  - Pied : séparateur `line`, bouton « Thème clair/sombre » (icône contrast, h 36, 13/600 muted), puis `v0.1.3 · préversion` en mono 11.5 `faint`.
- **< 900 px** : pas d'aside. Barre sticky h 56 en haut de `main`, fond `sidebar` à 92 % + `backdrop-filter: blur(12px)`, bordure basse `line`, padding 0 16, gap 8.
  - Logo 26 + nom (masqué < 400 px, `nowrap`) · bouton « Télécharger » h 40 (texte masqué < 360 px, icône seule) · bouton menu 44×44 (bordure `line2`, fond `surface`, hamburger 3×18×2 px ; ouvert = icône `add` tournée de 45°).
  - Menu ouvert : grille `repeat(auto-fill,minmax(150px,1fr))`, items h 44 (icône 20 `accent-text`, 14/600), puis en dernière ligne pleine largeur le bouton **Thème** (séparé par une bordure haute `line`). Un clic sur un lien ferme le menu.
  - `scroll-margin-top: 56px` sur les sections (0 sur desktop).
- `main` : `flex:1 1 0; min-width:0`. Conteneur des sections : `max-width:1200px; margin:0 auto; padding: clamp(56px,9vw,96px) clamp(16px,4vw,56px)`.

### 1. Hero (`#top`, contient `#telecharger`)
- Flex wrap, gap 48, alignement centré ; colonne texte `flex:1 1 min(100%,400px)`, démo `flex:1 1 min(100%,420px); max-width:560px`.
- Pastille : mono 12, `accent-text`, padding 5/12, radius 14, bordure `chip`, fond `accent-subtle` — « Windows & Android · gratuit ».
- H1 : `clamp(48px,6.4vw,92px)` / 800 / tracking −.05em / interligne .92 — « Your media. » puis « Your freedom. » en `accent-text`.
- Intro : 18 / 1.6, `muted`, max 500 px.
- Boutons (gap 10, wrap) :
  - Primaire h 56, radius 8, padding 0 24 0 20, `accent` / `accent-ink`, hover `accent-hover` ; icône desktop_windows 24 ; « Télécharger pour Windows » 15.5/800 + mono 11.5 opacité .75 « Windows 10 / 11 · 64 bits · 69,1 Mo ».
  - Secondaire h 56, fond `surface`, bordure `line2` (hover bordure `accent`) ; icône android 22 `muted` ; « Android » 15/700 + mono « 7.0+ · APK · 35 Mo ».
  - Les liens et les tailles viennent de `RELEASE` / `downloadUrl()`. La logique actuelle de `Downloads.tsx` est conservée (APK en premier sur Android).
- `<details>` 12.5 `muted` : « Sans compte · sans publicité · vérifier les fichiers (SHA-256) », puis la liste nom / empreinte (dt 700 `fg`, dd mono 11.5, `overflow-wrap:anywhere`).

### Démo (panneau du hero)
- Panneau : `surface`, bordure `line`, radius 14, ombre `0 24px 64px shadow`.
- En-tête h 40 : fond `sidebar`, bordure basse, mono 11.5 `muted`. À gauche « Essayez · démo avec un exemple », à droite l'étape (« 1 · lien », « 1 · analyse », « 2 · format », « 3 · fichier », « 3 · terminé »).
- Corps : padding 20, gap 16, hauteur min 380.
- Champ (non éditable) h 44, radius 6, fond `bg`, bordure `accent` + halo `0 0 0 3px rgba(53,201,189,.18)` ; icône link 18 ; mono 13 : `commons.wikimedia.org` en `fg` puis `/wiki/File:Tears_of_Steel_1080p.webm` en `muted`, avec ellipsis. Bouton « Analyser » secondaire h 44.
- États :
  1. **idle** : zone en tirets `line2`, radius 10, avec « Le lien est collé. » (15/700) et une phrase d'aide (13 `muted`).
  2. **analyzing** (900 ms) : 3 squelettes `surface2` (h 64/52/52, opacités .8/.6/.45) et « Analyse de la page… ».
  3. **formats** :
     - Carte média : miniature 96×54 en placeholder hachuré, « Tears of Steel » 15/700, mono « Blender Foundation · CC BY 3.0 · 12:14 ».
     - Segmented Vidéo / Audio seul : padding 3, radius 7, fond `bg` ; segment actif `surface2` + `fg`.
     - 3 lignes radio h 52, radius 8 ; sélectionnée : bordure `accent` et fond `sel-bg`, sinon bordure `line`. Chaque ligne contient l'anneau 16 px avec son point de 6 px, la qualité (14/700), le codec (mono 12 `muted`, ellipsis), le badge « Recommandé » (mono 10.5/700, `accent-subtle` / `accent-text`, masqué < 520 px) et la taille (mono 12.5).
     - Pied : `→ Vidéos\Miarina` (ou `Musique\Miarina` en audio), puis le bouton primaire h 40 « Télécharger · {taille} ».
  4. **downloading** : carte `bg` avec le nom du fichier et le pourcentage en tabular-nums, une piste de 4 px (`line`, remplissage `accent`) et la ligne « {taille} · 6,4 Mo/s · reprise automatique si la connexion coupe ». La progression avance de +2.5 % toutes les 80 ms.
  5. **done** : carte `sel-bg`, bordure `accent`, icône check, « Enregistré dans la bibliothèque », le chemin en mono et le bouton « Recommencer ».
- Données d'exemple : la vidéo propose 1080p MP4·H.264 372 Mo (recommandé), 720p MP4 186 Mo et 1080p WebM·VP9 298 Mo ; l'audio propose MP3 320 kbps 28 Mo (recommandé), MP3 128 kbps 11 Mo et FLAC 112 Mo.

### 2. Fonctionnalités (`#fonctions`)
- Bordure haute `line`. Sur-titre mono 12 `accent-text`. H2 `clamp(32px,4vw,52px)` / 800 / −.04em / 1.04.
- Grille `repeat(auto-fit,minmax(min(100%,340px),1fr))`, column-gap 56. Chaque item a une bordure haute `line`, un padding 20/0 et un gap 16.
- Tuile d'icône 40×40, radius 10. Pour les 3 gestes (link, tune, download) : fond `accent`, icône `accent-ink`. Pour speed, video_library et contrast : `accent-subtle` / `accent-text`.
- Titre 16.5/700, texte 14.5/1.6 `muted`. Textes = `FEATURES` de Home.tsx.

### 3. Navigateur (`#navigateur`)
- **Toujours sombre**, quel que soit le thème : fond `#101820`, texte `#F5F7FA`, sur-titre `#35C9BD`, texte secondaire `#94A3B8`.
- Ligne titre (max 640) + paragraphe (max 440), flex wrap, alignés en bas.
- Capture `windows-browser.jpg` pleine largeur : radius 12, bordure `#2A3D4E`, ombre `0 40px 100px rgba(0,0,0,.5)`.
- Chips h 30, radius 15, 12.5/600, icône 16 :
  - disponibles : fond `#1F3A3C`, bordure `#2E6A68`, texte `#5FE0D5`, icône check ;
  - « Onglets et historique : bientôt » : fond `#2B2616`, bordure `#4A3F1F`, texte `#E8B04B`, icône schedule.

### 4. Formats (`#formats`)
- Deux colonnes en wrap : le texte (`flex:1 1 320px`) et une carte `surface` (`flex:1.2 1 420px`, radius 14, padding 20).
- Onglets Vidéo (movie) / Audio (music_note) / Sous-titres (closed_caption), h 40, 13.5/600. L'onglet actif est en `fg` avec un soulignement 2 px `accent`.
- Lignes : padding 14/4, bordure basse `line`, libellé 14.5/600, détail en mono 12.5 `muted`. Pour SRT, « Bientôt » s'affiche en `planned` 13/600. Données = `FORMATS` de Home.tsx.

### 5. Bibliothèque (`#bibliotheque`)
- Bande `surface` avec bordures haute et basse.
- Capture `windows-library.jpg` (`flex:1.6`, radius 12, bordure `line2`) à gauche, texte à droite (`flex:1 1 300px`).
- H2 `clamp(30px,3.4vw,44px)`, paragraphe 15.5, note Android 13.5.

### 6. Confidentialité (`#confidentialite`)
- H2 « Sans publicité. Sans compte. Sans pistage. »
- Grille `minmax(min(100%,220px),1fr)` avec une bordure haute de 2 px `fg`.
- Trois grands « 0 » `clamp(72px,8vw,120px)` / 800 / −.06em en `accent-text`, avec les libellés « publicité », « compte » et « traceur » (17/700) et leur description (14 `muted`).
- 4ᵉ colonne : icône hard_drive à la même échelle, puis « Vos fichiers restent chez vous ».
- Le lien « détails » mène à `/confidentialite.html`.

### 7. Plateformes (`#plateformes`)
- Titre et sous-titre « Ce que la version {RELEASE.version} sait faire aujourd'hui. ».
- Segmented de filtre Tout / Windows / Android : fond `surface2`, segment actif `surface`. Le filtre Windows masque les lignes où `windows === false`, et inversement.
- Table dans une carte `surface`, bordure `line`, radius 10.
  - Grille `minmax(0,2fr) minmax(0,1fr) minmax(0,1fr)`, gap `clamp(8px,2vw,16px)`, padding `12px clamp(12px,3vw,20px)`.
  - En-tête sur fond `surface2`. Sous 520 px, les colonnes n'affichent que l'icône.
  - Cellules : `true` → check `accent-text` ; `false` → « — » `faint` ; `'soon'` → « Bientôt » `planned` ; texte → mono 12 `body2`. Données = `PLATFORMS`.
- Sans JS : afficher la table complète (filtre « Tout »).

### 8. FAQ (`#faq`)
- Deux colonnes en wrap : le titre, puis la liste (`flex:2 1 480px`, gap 8).
- Chaque question est une carte `surface`, bordure `line`, radius 10.
  - Bouton plein largeur, padding 18/20, 15.5/700.
  - Icône `add` 22 : en `muted` quand la réponse est fermée ; en `accent-text`, tournée de 45°, quand elle est ouverte.
  - Réponse : 14.5/1.65 `muted`, padding 0 20 20.
- Une seule question ouverte à la fois, la première par défaut. Peut être implémenté en `<details name="faq">` pour fonctionner sans JS. Données = `FAQ`.

### 9. Versions (`#versions`)
- Boîte à défilement interne : carte `surface`, bordure `line`, radius 10, `position:relative; overflow:hidden`.
- Zone scrollable : `max-height:440px; overflow-y:auto`, **barre native masquée** (`scrollbar-width:none` + `::-webkit-scrollbar{display:none}`).
- Indicateur maison à droite : piste absolue `top:12; bottom:12; right:8`, largeur 4, `line`, radius 2. Le pouce `accent` a une hauteur = clientHeight / scrollHeight (min 12 %) et une position = scrollTop / (scrollHeight − clientHeight).
- Tant qu'il reste du contenu (scrollTop < max − 8) :
  - un dégradé bas de 96 px (transparent → `surface` à 70 %) ;
  - une pastille centrée h 32, radius 16, `surface2`, bordure `line2`, avec « +N » (mono `accent-text`, N = versions pas encore entièrement visibles) et « Faites défiler pour les versions précédentes ». Un clic fait `scrollBy(320, smooth)`.
- Frise : bordure gauche 2 px `line`, items padding 0 0 36 28. Les pastilles sont absolues à gauche :
  - planifiée : 14 px, anneau `planned` ;
  - courante : 14 px `accent` + halo 4 px `accent-subtle` ;
  - passée : 12 px `line2`.
- Nom en mono 18 (couleur `planned` / `accent-text` / `fg`), date 12.5/600, items 14 / 1.55 `body2`. Données = `CHANGELOG`.
- Sans JS : la boîte reste scrollable nativement ; l'indicateur et la pastille sont ajoutés par JS.

### Pied de page
Fond `sidebar`, bordure haute. Mention légale (13 `muted`, max 440) et liens Confidentialité, Licences, puis « © 2026 MIARINA ».

## Interactions et comportement
- **Thème** : sombre ou clair, mémorisé dans `localStorage`. Le prototype démarre en clair ; à décider pour le site (respecter `prefers-color-scheme` à défaut de préférence). Mettre `data-theme` sur `<html>` et définir les variables CSS par thème dans `site.css`.
- **Scroll spy** : la section active est la dernière dont le haut est à moins de 160 px du haut de la fenêtre ; « Versions » est forcée en bas de page. (Un IntersectionObserver convient aussi.)
- **Menu mobile** : bascule par le bouton ; fermé au clic sur un lien et au passage au-dessus de 900 px.
- **Survols** : 80 ms linéaire, fond et couleur uniquement (design system §7). Focus : outline 2 px `#35C9BD`, offset 2.
- **`prefers-reduced-motion`** : pas de défilement doux ; la progression de la démo peut sauter directement à l'état terminé.

## État (îlot client)
`theme`, `active` (scroll spy), `menu`, `w` (ou media queries CSS — **préférer les media queries** dans le vrai site), démo `{ step: idle|analyzing|formats|downloading|done, tab: video|audio, sel, pct }`, `spec` (onglet formats), `plat` (filtre), `open` (FAQ), `log` (indicateur de défilement). Aucune donnée distante.

## Design tokens

| Token | Sombre | Clair |
|---|---|---|
| bg | #101820 | #F6F8FA |
| surface | #182530 | #FFFFFF |
| surface2 | #1F2F3B | #EEF2F5 |
| sidebar | #0D141B | #EDF1F4 |
| line | #243545 | #DDE3E9 |
| line2 | #2A3D4E | #C9D2DB |
| fg | #F5F7FA | #101820 |
| muted | #94A3B8 | #526072 |
| faint | #64748B | #64748B |
| body2 | #C9D4E0 | #2B3A4A |
| accent | #35C9BD | #35C9BD |
| accent-hover | #4FD6CB | #4FD6CB |
| accent-text | #35C9BD | #0F8579 |
| accent-ink | #062320 | #062320 |
| accent-subtle | #1F3A3C | #DDF5F2 |
| chip | #2E6A68 | #9ADFD8 |
| planned | #E8B04B | #A86F0A |
| sel-bg | #16302F | #EAF8F6 |
| logo tuile / glyphe | #35C9BD / #101820 | #101820 / #35C9BD |
| shadow | rgba(0,0,0,.45) | rgba(16,24,32,.12) |

- Typo : Manrope (UI) et JetBrains Mono 400/500 (valeurs machine). H1 clamp(48–92) ; H2 clamp(32–52) ; corps 14.5–18 ; mono 11.5–13.
- Rayons : 5 (segment), 6 (boutons, champs), 7 (segmented), 8 (lignes, gros boutons), 10 (cartes), 14 (panneaux), 15–16 (chips, pastilles).
- Ombres : panneau `0 24px 64px shadow` ; capture du navigateur `0 40px 100px rgba(0,0,0,.5)` ; pastille de défilement `0 8px 24px shadow`.
- Espacement : base 4 ; gaps courants 8, 12, 16, 24, 32, 48, 56, 64.

## Assets
Tous proviennent de `apps/website/public/assets/` :
- polices : `manrope.woff2`, `jetbrains-mono-400/500.woff2`, `icons.woff2` ;
- images : `windows-hero.jpg` (non utilisée dans la v3), `windows-browser.jpg`, `windows-library.jpg`, `android-home.jpg` (non utilisée dans la v3) ;
- le logo est le SVG inline de `Common.tsx`.

**Icônes utilisées** (toutes présentes dans le sous-ensemble actuel) : download, tune, link, movie, video_library, visibility_off, desktop_windows, android, add, schedule, contrast, check, speed, music_note, closed_caption, hard_drive. Le hamburger du menu est dessiné en CSS (3 barres) ; il n'y a pas d'icône `menu` dans le sous-ensemble.

## Fichiers
- `Miarina Media - Landing v3.dc.html` — référence source (template et logique lisibles).
- `Miarina Media - Landing.html` — version autonome, à ouvrir dans un navigateur pour voir le rendu et tester les interactions.
- `assets/` — polices et images utilisées par la référence.
