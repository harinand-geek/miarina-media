# Passation : landing Miarina Media v4 (Obtenir + Écouter)

## Vue d'ensemble
Refonte de la page d'accueil de `media.miarina.org` (`apps/website`). Miarina Media n'est plus seulement un téléchargeur : c'est aussi un lecteur de musique et de vidéo. La page présente donc à parts égales les deux espaces de l'app Windows v2, **Obtenir** et **Écouter**, avec le logo v2.0 (tuile nuit, play corail, barres teal), un thème sombre unique et une bascule FR / EN.

Sections, dans l'ordre : barre du haut → hero avec démo animée → Fonctionnalités (Obtenir | Écouter) → Bibliothèque et lecteur (captures qui défilent) → Télécharger → Journal des versions → pied de page.

## À propos des fichiers
`Miarina Media Landing v2.dc.html` est une **référence de design en HTML** : un prototype qui montre l'apparence et le comportement attendus, pas du code à livrer tel quel. Il faut **recréer ce design dans `apps/website`** (React + Vite, pré-rendu par `scripts/prerender.mjs`) en suivant les conventions existantes :

- **CSP du vhost : pas de script ni de style en ligne, aucune ressource externe** (`docs/decisions/0003-website-react-prerender.md`). Les styles en ligne du prototype doivent devenir des classes dans `src/styles/` (par ex. un nouveau `landing-v4.css` ou une réécriture de `landing.css`). Les valeurs dynamiques (largeur d'une barre de progression, etc.) passent par des propriétés CSS posées depuis React (`el.style.setProperty`) ou par des attributs `data-*` + classes. Pas d'attribut `style=""` dans le HTML pré-rendu.
- **Pré-rendu** : tout le texte doit être présent dans le HTML sans JavaScript. Les animations sont une amélioration progressive : sans JS, la démo du hero affiche son état final (vue Écouter), toutes les sections sont visibles et le journal montre la version actuelle.
- **Données** : le contenu ne doit jamais promettre plus que ce que fait la version publiée (README du site). Sources à utiliser à la place des chaînes codées en dur dans le prototype :
  - versions, fichiers, tailles, SHA-256, journal → `src/release.ts` (`RELEASE`, `CHANGELOG`, `downloadUrl()`)
  - textes des fonctionnalités → `src/pages/homeContent.ts` (`FEATURES`)
  - boutons de téléchargement → `src/components/Downloads.tsx`
- **Icônes** : le prototype charge Phosphor depuis unpkg. C'est interdit en production : soit héberger un sous-ensemble Phosphor sur le site (woff2 réduit ou SVG en ligne dans les composants), soit garder le sous-ensemble Material Symbols existant (`public/assets/fonts/icons.woff2`) et y ajouter les glyphes manquants. Liste des icônes plus bas.

## Fidélité
**Haute fidélité** pour la mise en page, l'échelle typographique, les espacements, les couleurs et les animations. Les textes FR viennent du site actuel (`homeContent.ts`, `Home.tsx`, `release.ts`), parfois raccourcis. Les textes EN sont une première traduction à relire.

> **Versions :** le prototype affiche Windows 0.1.8 / Android 0.1.7 (valeurs de `RELEASE`), alors que `CHANGELOG` marque déjà la 0.1.9 comme actuelle. En production, tout doit être lu depuis `release.ts`.

---

## Design tokens

Structure Nocturne (`_ds/…/styles.css`) avec l'accent et le fond remplacés par la charte du logo v2.0. Ces variables sont posées sur la racine de la page :

| Variable | Valeur | Rôle |
|---|---|---|
| `--color-bg` | `#101820` | fond (nuit de la charte) |
| `--color-surface` | `#182530` | surfaces (fenêtre de démo, bloc versions) |
| `--color-text` | `#e9e9ed` | texte |
| `--color-accent` | `#35C9BD` | **teal : télécharger, liens, boutons, progression, focus** |
| `--color-accent-100…900` | `oklch(0.97 0.03 185)`, `oklch(0.93 0.06 185)`, `oklch(0.87 0.09 185)`, `oklch(0.80 0.11 185)`, `oklch(0.72 0.12 185)`, `oklch(0.60 0.10 185)`, `oklch(0.48 0.08 185)`, `oklch(0.36 0.06 188)`, `oklch(0.27 0.045 190)` | rampe teal |
| `--mm-play` | `#FF7A45` | **corail : lecture uniquement** (mini-lecteur, égaliseur, onglet Écouter, groupe 02) |
| `--mm-play-300` | `oklch(0.86 0.08 45)` | texte corail sur teinte |
| `--mm-play-900` | `oklch(0.30 0.06 40)` | fond de l'étape « Lecture » active |
| `--color-neutral-100…900` | `#f3f5fe #e4e7f5 #cfd3e5 #b2b6ca #9397ab #75798c #595d6c #3f424d #292b31` | texte secondaire, filets, bordures |
| `--color-divider` | `color-mix(in srgb, #e9e9ed 16%, transparent)` | filets de section |
| `--radius-sm/md/lg` | `4px / 8px / 14px` | |
| `--shadow-sm` | `0 0 0 1px #3f424d` | bloc versions |
| `--shadow-md` | `0 0 0 1px #595d6c, 0 6px 18px rgba(0,0,0,.55)` | fenêtre de démo, capture Windows |
| `--shadow-lg` | `0 0 0 1px #9397ab, 0 16px 40px rgba(0,0,0,.65)` | téléphone Android |

**Règle de couleur :** le teal sert à Obtenir et aux actions, le corail à Écouter et à la lecture. Ne jamais inverser (charte logo). Aucun aplat saturé sur de grandes surfaces : l'accent sert de trait, de contour ou de teinte légère (`color-mix(... 12–16%)`).

**Fond de page** (calques, du haut vers le bas) :
```
radial-gradient(1200px 720px at 82% -160px, color-mix(in srgb, var(--color-accent-900) 75%, transparent), transparent 60%),
radial-gradient(1100px 800px at -10% 100%, color-mix(in srgb, black 30%, transparent), transparent 55%),
var(--color-bg)
```

**Filets** : toujours estompés aux extrémités sur 48 px :
`linear-gradient(to right, transparent, <couleur> 48px calc(100% - 48px), transparent)`, 1 px. Filets de section : `--color-divider` ; filets entre lignes de fonctionnalités : `--color-neutral-800` ; entre lignes de téléchargement : `--color-neutral-700`.

**Typographie**
- Corps et titres : Inter (400 / 500, **jamais plus de 500 pour les titres**). En prod, l'héberger sur le site (le site actuel héberge Manrope : à décider, garder Manrope partout est acceptable si on veut limiter les polices).
- Logotype « Miarina Media » : **Manrope 800**, letter-spacing −0.02em (`assets/fonts/manrope.woff2`, déjà présente dans `public/assets/fonts/`).
- Valeurs machine (URL, versions, tailles, SHA-256, minutage) : `ui-monospace, 'JetBrains Mono', Menlo, monospace` (JetBrains Mono déjà hébergée).
- Échelle :
  - H1 : `clamp(44px, 6.2vw, 84px)`, line-height 1.04, letter-spacing −0.03em, margin-left −0.04em. Chaque phrase sur sa propre ligne (`display:block`) ; la 2ᵉ ligne en `--color-neutral-400`.
  - H2 de section : `clamp(28px, 3.6vw, 46px)`, lh 1.1, ls −0.02em. H2 des versions : `clamp(26px, 3vw, 36px)`.
  - H3 de groupe : 28px. H3 de version : 22px. H4 de fonctionnalité : 17px / 24px.
  - Chapeau du hero : 17px / 28px, max 54ch, texte à 82 %.
  - Corps : 14.5–15.5px / 23–26px.
  - Kicker : 13px, majuscules, ls 0.06em, teal, précédé d'un trait plein de 32 × 1 px avec 14px d'écart.
  - Méta : 12–13px, `--color-neutral-500`.

**Mise en page** : conteneur `max-width: 1240px`, gouttière `clamp(20px, 5vw, 72px)`. Padding vertical des sections : `clamp(56px, 8vw, 104px)` ; hero : `clamp(56px, 9vw, 120px)` en haut, `clamp(72px, 9vw, 128px)` en bas.

**Composants Nocturne réutilisés** : `.btn .btn-primary` (contour 1px accent, fond transparent, survol à 12 %, appui à 22 %), `.btn .btn-secondary`, `.tag .tag-accent`, `.tag .tag-neutral`. Focus : `outline: 2px solid var(--color-accent); outline-offset: 2px`.

---

## Écrans / sections

### 1. Barre du haut (sticky)
- `position: sticky; top: 0; z-index: 20`. Fond `color-mix(in srgb, var(--color-bg) 78%, transparent)` + `backdrop-filter: blur(14px)`. Padding `12px <gouttière>`, gap `clamp(10px, 2vw, 22px)`.
- À gauche : logo animé de 26 px + « Miarina Media » (Manrope 800, 17px). Au survol du lien, l'animation d'intro du logo se rejoue.
- Liens (14px, `--color-neutral-300`, teal au survol) : Obtenir `#obtenir` · Écouter `#ecouter` · Bibliothèque `#bibliotheque` · Versions `#versions`. **Masqués sous 860 px.**
- Bascule de langue FR | EN : groupe avec bordure `--color-divider`, radius 8, boutons de 12px, padding 5×9. Bouton actif : texte teal + `box-shadow: inset 0 0 0 1px teal`. Choix mémorisé dans `localStorage['miarina-landing-lang']`. En production, préférer deux pages pré-rendues (`/` et `/en/`) avec `hreflang`, la bascule devenant alors un lien.
- CTA `.btn-primary` « Télécharger » (icône download-simple) → `#telecharger`. **Sous 520 px : icône seule** (garder un `aria-label`).

### 2. Hero
Grille `repeat(auto-fit, minmax(min(100%, 460px), 1fr))`, gap `clamp(40px, 6vw, 88px)`, contenu centré verticalement.

**Colonne texte**
- H1 FR : « Téléchargez une fois. » / « Écoutez hors ligne. » — EN : « Download once. » / « Listen offline. »
- Chapeau FR : « Collez un lien, choisissez le format, gardez le fichier. Miarina Media range vidéos et musique dans une bibliothèque sur votre appareil et les lit dans son propre lecteur : albums, playlists, pistes audio, sous-titres et égaliseur. Sur Windows et Android. »
- Boutons (gap 10, marge haute 30, padding 10×16, 15px) : `.btn-primary` « Télécharger pour Windows » (icône windows-logo) et `.btn-secondary` « Android (APK) » (icône android-logo). À brancher sur `Downloads.tsx` / `downloadUrl()`.
- Méta en mono 12.5px : « Windows {v} · Android {v} · préversions gratuites ».

**Colonne démo** (max 540px ; alignée à droite à partir de 980 px, à gauche en dessous), `aria-hidden`.
- Halo derrière : `radial-gradient(closest-side, color-mix(accent-700 38%), transparent)`, débord `inset: -12% -8% -14% -8%`.
- Fenêtre : radius 14, fond `color-mix(surface 92%, bg)`, `--shadow-md`.
  - Barre de titre (padding 11×14, filet bas `neutral-800`) : logo 18px statique, « Miarina Media » (Manrope 800, 13px) et, à droite, un segment Obtenir | Écouter (fond `--color-bg`, padding 2, onglets 12px en padding 4×10, radius 6). Onglet Obtenir actif : texte `accent-300`, fond teal à 16 %. Onglet Écouter actif : texte `--mm-play-300`, fond corail à 16 %.
  - Zone de contenu : **hauteur fixe 356px**, deux vues superposées en `position: absolute`.
- **Vue Obtenir** (padding 18, gap 14) :
  - Champ URL (fond bg, radius 8, bordure `accent-700` pendant la saisie, `neutral-800` ensuite) : icône link-simple, texte mono 12px, `direction: rtl` pour que la fin de l'URL reste visible, curseur teal de 1 × 14 px qui clignote (`steps(1)` sur 1 s). Texte : `commons.wikimedia.org/wiki/File:Big_Buck_Bunny_4K.webm`.
  - Bouton « Analyser » (contour teal, 12.5px), fond teal à 18 % et libellé « Analyse… » pendant l'analyse.
  - Liste de formats : titre « Big Buck Bunny · 10:35 » (11px majuscules), puis 3 lignes (padding 8×10, radius 8, contour `inset 0 0 0 1px neutral-800`) :
    - Vidéo · MP4 1080p — H.264
    - Audio · MP3 320 kbps — 24,8 Mo
    - Audio · FLAC — conversion

    La ligne sélectionnée a un fond teal à 12 % et un contour teal.
  - En bas : « big_buck_bunny.mp3 » + pourcentage en mono `accent-300` (« 24,8 Mo » une fois terminé), barre de 3px (piste `neutral-800`, remplissage teal).
- **Vue Écouter** :
  - « Ajoutés récemment » + grille de 4 colonnes de pochettes carrées (radius 6) : Big Buck Bunny (nouveau, contour teal, entre avec un fondu + `translateY(10px) scale(.94)` → normal, retard .25s), Albinoni, Mendelssohn, Bach. Toutes les pochettes sont découpées dans `windows-library.jpg` (1280×800) avec des valeurs en %, voir Assets.
  - Ligne « ✓ Enregistré dans Musique/Miarina » (check teal, 12.5px, `neutral-400`).
  - Barre de lecture de 2px (piste `neutral-800`, remplissage corail).
  - Mini-lecteur (padding 12×16, gap 12) : vignette 40px, titre « Big Buck Bunny » 13.5px/500 + « upload.wikimedia.org » 11.5px ; à droite, égaliseur (4 barres de 3px, corail), minutage mono « 05:10 / 10:35 », skip-back, bouton pause rond de 34px (contour corail, icône pause pleine corail), skip-forward. **Sous 520 px, l'égaliseur, le minutage et skip-back sont masqués.**
- Sous la fenêtre, 4 pastilles d'étape centrées (11.5px, padding 3×9, radius 6) : Lien · Format · Fichier · Lecture. Étape active : texte `accent-200` sur `accent-900` (corail `mm-play-300` sur `mm-play-900` pour Lecture). Étapes passées : `neutral-400`. À venir : `neutral-600`.

### 3. Fonctionnalités `#fonctions`
- Kicker « Fonctionnalités » ; H2 « Deux espaces, une seule application. » (max 20ch).
- Deux groupes en `flex-wrap` (chacun `flex: 1 1 360px`, gap `48px clamp(32px,5vw,80px)`) : côte à côte sur bureau, empilés sur mobile.
  - En-tête du groupe : numéro mono 13px (« 01 » teal / « 02 » corail), H3 28px avec icône de 24px de la même couleur, puis le texte d'introduction (15/24, `neutral-400`, max 46ch).
  - Lignes : padding 18 0, filet estompé `neutral-800` en haut, H4 17px puis texte 14.5/23 à 72 %.
- **01 Obtenir** `#obtenir` (download-simple) — « Du lien au fichier : analyse, choix du format, file de téléchargements. » Lignes : Collez un lien · Choisissez le format · File de téléchargements · Torrents sur Windows · Depuis Chrome ou Edge.
- **02 Écouter** `#ecouter` (music-notes) — « Un vrai lecteur pour ce que vous gardez, et pour la musique déjà présente sur l'appareil. » Lignes : Bibliothèque musicale · Playlists et favoris · Lecteur et égaliseur · Vos fichiers aussi.
- Textes : `FEATURES` dans `homeContent.ts` (raccourcis dans le prototype pour Bibliothèque, Playlists et Lecteur ; voir le fichier).

### 4. Bibliothèque et lecteur `#bibliotheque`
- En-tête en `flex-wrap`, aligné en bas : à gauche le kicker et le H2 « Tout ce que vous gardez, au même endroit. » (max 18ch), à droite le texte (15.5/26, 78 %).
- Onglets (marge haute 44, gap 6) : boutons 13.5px, padding 9×14×11, bordure `--color-divider`, radius 8, icône de 16px. Barre de progression de 2px en bas de l'onglet actif (teal ; corail pour « En lecture »).
  1. Windows · Albums (vinyl-record) → `windows-library.jpg`
  2. Windows · En lecture (play-circle) → `windows-hero.jpg`
  3. Android (android-logo) → met le téléphone en avant

  **Sous 520 px :** les onglets sont sur une seule ligne qui défile horizontalement, de bord à bord, sans barre de défilement visible.
- Scène : conteneur `padding-right: 9%` (14 % sous 520 px). Capture Windows en 16:10, radius 14, `--shadow-md`, les deux images superposées en fondu (.7s) avec un léger zoom de sortie (`scale(1.03)`, 1.2s). Téléphone : `position: absolute; right: 0; bottom: -7%`, largeur 22 % (30 % sous 520 px), ratio 540/1200, radius `clamp(12px,2vw,26px)`, `--shadow-lg`.
  - Onglet Android : téléphone en `translateY(-6%) scale(1.12)`, opacité 1, la capture Albums reste derrière à 40 %.
  - Autres onglets : téléphone en `scale(.94)`, opacité .9, `brightness(.7)`.
  - Transition du téléphone : .8s `cubic-bezier(.2,.8,.2,1)`.
- Légende de l'onglet actif sous la scène (14.5/24, `neutral-400`, max 62ch, min-height 48 pour éviter les sauts).

### 5. Télécharger `#telecharger`
- À gauche (max 400px) : logo animé en boucle de 56px, H2 « Télécharger Miarina Media », puis « Gratuit, sans publicité, sans compte. L'application n'envoie ni statistiques d'usage ni rapports de plantage. »
- À droite : une ligne par plateforme (padding 26 0, filet bas estompé `neutral-700`, `flex-wrap`) : icône de 30px · titre « Windows 0.1.8 » (19px/500) + configuration requise et taille (13px) + « fichier · SHA-256 e90bc6e2…5a7d49 » (mono 11.5px, `overflow-wrap:anywhere`) · bouton `.btn-primary` « Installateur .exe » / « Fichier .apk ». En prod : afficher l'empreinte **complète** (ou un bouton copier) depuis `release.ts`.
- Note : « Préversions non signées : Windows SmartScreen peut afficher un avertissement. Comparez l'empreinte SHA-256 avant d'installer. »

### 6. Journal des versions `#versions`
Pensé pour rester compact : une seule boîte au lieu de la longue chronologie actuelle.
- Kicker « Journal des versions », H2 « Ce qui a changé, version par version. ». En EN, mention à droite « Release notes are written in French. » (ou traduire `CHANGELOG`).
- Boîte : radius 14, fond `color-mix(surface 60%, transparent)`, `--shadow-sm`, padding `clamp(14px,2vw,22px)`, `flex-wrap`.
  - **Liste** (`role=tablist`) :
    - **À partir de 980 px** : colonne verticale, max 300px de large, `max-height: 380px` avec défilement et masque `linear-gradient(to bottom, #000 82%, transparent)`.
    - **En dessous** : rangée horizontale qui défile, masque `to right, #000 88%`, numéros seuls.
    - Chaque entrée : point de 7px (teal = actuelle, cercle vide `neutral-500` = Prochaines, `neutral-700` = autres), version en mono 13px et, sur bureau, la plateforme ou la date en 12px `neutral-500`.
    - Entrée active : fond teal à 12 %, texte plein.
  - **Détail** (`role=tabpanel`) : H3 22px du nom complet + `.tag-accent` « Actuelle » ou `.tag-neutral` « Prévu », la date (13px `neutral-500`), puis la liste des changements (14.5/22, 82 %), chaque point précédé d'un trait teal de 10 × 1 px.
- Sélection par défaut : l'entrée `current: true` de `CHANGELOG` (0.1.9). Toutes les entrées viennent de `CHANGELOG`.
- Accessibilité : en prod, ajouter la navigation au clavier ↑/↓ (ou ←/→) entre les onglets, et `aria-controls`.

### 7. Pied de page
Mention légale « Téléchargez uniquement les contenus dont vous détenez les droits ou dont la licence l'autorise. » (flex 1), liens Confidentialité `/confidentialite.html` et Licences `/licences.html` (`neutral-300`, teal au survol), « © 2026 MIARINA ». 13px, `neutral-500`.

---

## Interactions et animations

**Démo du hero**, boucle de 14 s (horloge rafraîchie toutes les ~60 ms ; en prod, préférer `requestAnimationFrame` et la mettre en pause hors écran avec IntersectionObserver ou `document.hidden`) :

| t (s) | État |
|---|---|
| 0 – 2.6 | Saisie de l'URL caractère par caractère, curseur visible, bordure du champ `accent-700` |
| 2.6 – 3.3 | Bouton « Analyse… » (fond teal à 18 %) |
| 3.3 – 8.0 | Liste des formats visible (fondu + `translateY(8px)` → 0, .45s) ; sélection sur MP4, puis sur MP3 320 à partir de 4.5 s |
| 5.4 – 7.8 | Barre de téléchargement de 0 à 100 %, puis « 24,8 Mo » |
| ≥ 8.2 | Bascule sur Écouter : la vue Obtenir part à gauche (`translateX(-24px)`, opacité 0), la vue Écouter arrive de la droite (.55s) ; nouvelle pochette, lecture à partir de 05:10 (+1 s/s), égaliseur actif |

**Logo** (SVG 32×32 : tuile `#182530` en rx 8 ; barres teal `#35C9BD` en (6, 10.5, 4×2.5), (4, 14.75, 6×2.5) et (6, 19, 4×2.5), rx 1.25 ; play corail `#FF7A45` `M13 9.5v13l10-6.5z`) :
- Intro (barre du haut) : chaque barre fait `translateX(-9px)`, opacité 0 → 0, en .55s `cubic-bezier(.2,.8,.2,1)`, retards de 0.08, 0.18 et 0.28 s. Le play fait `scale(.4)` → 1.08 → 1 en .6s, retard .45s (`transform-box: fill-box; transform-origin: center`).
- Boucle (section Télécharger) : les barres « coulent » vers le play (`mmFlow` sur 2.8 s : `translateX(-7px)`/0 → 0/1 à 25 % → maintien jusqu'à 70 % → `translateX(5px)`/0), décalées de 0.16 s. Le play pulse à 1.1 vers 70 % (`mmPulse`, 2.8 s).

**Égaliseur** : 4 barres, `scaleY(.18 ↔ 1)` en `alternate infinite`, durées 0.9 / 0.62 / 1.1 / 0.75 s, déphasage `-i*0.3s`, `transform-origin: bottom`.

**Apparition au défilement** : les éléments `[data-reveal="délai ms"]` partent de l'opacité 0 avec `translateY(18px)`, puis passent à l'opacité 1 sans décalage en .8s `cubic-bezier(.2,.8,.2,1)` avec ce délai, déclenchés par IntersectionObserver (`rootMargin: 0 0 -8% 0`), une seule fois. **Cacher les éléments seulement depuis le JS** pour que la page pré-rendue reste lisible.

**Captures de la bibliothèque** : avance automatique toutes les **6 s**, barre de progression sur l'onglet actif ; un clic sélectionne l'onglet et remet le minuteur à zéro.

**`prefers-reduced-motion: reduce`** : démo figée sur la vue Écouter (t = 10 s), pas d'avance automatique, pas d'apparition au défilement, animations CSS réduites à .01ms.

**Points de rupture** (largeur de la fenêtre) :
- **< 860** : liens de la barre du haut masqués.
- **< 980** : démo du hero alignée à gauche ; liste des versions horizontale, numéros seuls.
- **< 520** : CTA de la barre en icône seule ; mini-lecteur réduit ; onglets de la bibliothèque sur une ligne qui défile ; téléphone à 30 % et padding de la scène à 14 %.

Le reste s'adapte grâce à `flex-wrap` et aux tailles en `clamp()`. Pas de largeurs fixes sur les blocs de texte.

## État (React)
- `lang: 'fr' | 'en'`, idéalement remplacé par la route.
- `t` (0–14 s) pour la démo, `shot` (0–2) et `shotT` pour les captures, `ver` (index dans `CHANGELOG`, par défaut celui qui est `current`).
- `vw` (largeur de la fenêtre) pour les points de rupture qui changent la structure. Préférer des media queries CSS dès que possible (le prototype utilise un état parce que ses styles sont en ligne).
- Pas de récupération de données : tout est statique, depuis `release.ts` et `homeContent.ts`.

## Assets (`assets/`)
- `windows-library.jpg`, `windows-hero.jpg`, `android-home.jpg` : captures réelles venant de `apps/website/public/assets/img/`. **`android-home.jpg` est l'ancienne interface (ancien logo, en anglais) : la remplacer par une capture de l'Android 0.1.9.**
- Découpes de `windows-library.jpg` (pochettes carrées, valeurs indépendantes de la taille) : `background-size: <1280/c×100%> auto; background-position: <x/(1280−c)×100%> <y/(800−c)×100%>`
  - Albinoni `24.82% 20.32% / 711.11%`, Mendelssohn `42.73% 20.32% / 711.11%`, Bach `78.45% 20.32% / 711.11%` (c = 180)
  - Big Buck Bunny `20.39% 98.68% / 2909.09%` (c = 44)

  En prod, des fichiers de pochette séparés seraient plus propres.
- `miarina-media-icon-on-dark.svg`, `miarina-media-glyph-color.svg` : logo v2.0 (`design/brand/miarina-media-logo/`). Le favicon et les icônes PWA y sont aussi (`web/`).
- `fonts/manrope.woff2`.
- Icônes Phosphor utilisées (regular, sauf `ph-fill pause`) : download-simple, windows-logo, android-logo, link-simple, film-strip, music-note, music-notes, waveform, check, skip-back, skip-forward, pause, vinyl-record, play-circle.

## Fichiers
- `Miarina Media Landing v2.dc.html` : le prototype (balisage + classe de logique avec les textes FR/EN, `CHANGELOG` et l'horloge de la démo). Pour l'ouvrir en local, le servir avec un serveur statique depuis ce dossier (`npx serve .`), car `support.js` et les `_ds/…` sont chargés en relatif.
- `support.js` : moteur d'exécution du prototype, **pas utile en production**.
- `_ds/nocturne-…/styles.css` : tokens et classes Nocturne (`.btn`, `.tag`…) dont la page dépend.
- `assets/` : voir plus haut.
