# Handoff : Miarina Media — refonte de l'espace « Écouter » (lecteur Musique · Cinéma · Focus)

> **À LIRE EN PREMIER — ce n'est PAS une nouvelle application.**
> Ce lot améliore l'UX/UI et ajoute des fonctions au **lecteur existant de Miarina Media**, dans l'espace **Écouter** (`space: 'play'`) de `apps/client`.
> - Ne pas créer de nouveau projet, de nouvelle app « player », de nouveau repo, ni de nouveau binaire/installeur.
> - Ne pas utiliser le nom « Nova Player » (nom provisoire du cahier des charges, abandonné). Le produit reste **Miarina Media**, logo 4d inchangé.
> - L'espace **Obtenir** (accueil lien, analyse, téléchargements, navigateur, torrents) n'est **pas** concerné et ne doit pas régresser.
> - Toutes les fonctions actuelles du lecteur sont conservées (file, égaliseur, vitesse, minuteur, tags, retirer/supprimer, playlists M3U, mini-lecteur, lecteur vidéo libVLC/Media3…).

## Overview
Refonte du lecteur intégré de Miarina Media sur Windows et Android, guidée par le cahier des charges « Lecteur multimédia Windows + Android 2026 » (`uploads/Cahier_des_charges_…pdf`, transmis séparément). L'espace Écouter est réorganisé en trois sections — **Musique, Cinéma, Focus** (podcasts, cours, livres audio) — avec un nouvel Accueil Écouter (reprise multi-sections), une barre de lecture pleine largeur, un écran En lecture enrichi (paroles synchronisées, file, son), une fiche film/série, un lecteur vidéo avec pistes/sous-titres/chapitres, un lecteur long format (vitesse, signets), la gestion des fichiers introuvables et des doublons, et les états vides/erreurs.

Direction validée : **3a « Continuité, finition soignée »** = charte Miarina actuelle (bleu nuit, corail = lire, teal = obtenir/sélection/focus, Manrope + JetBrains Mono).

## Où intégrer dans le code existant
Cible : **`apps/client`** (Tauri 2 + React 19 + Tailwind 4 + Zustand), selon `CLAUDE.md` et les patterns existants.

| Zone | Fichiers existants à faire évoluer |
|---|---|
| Shell Windows | `src/app/DesktopShell.tsx`, `src/app/Sidebar.tsx` (espace `play`), `src/app/TitleBar.tsx` |
| Shell Android | `src/app/MobileShell.tsx` (onglets), `features/player/MobileMiniPlayer.tsx` |
| Navigation | `src/app/navigation.ts`, `src/stores/ui.ts` (`Screen`, `LibraryView`, `Space`) |
| Lecteur | `features/player/*` (`NowPlayingScreen`, `MiniPlayer`, `PlayerScreen`, `MobilePlayer`, `MobileVideoFullscreen`, `TracksPanel`, `EqualizerSection`, `SeekBar`, `parts.tsx`) |
| Bibliothèque | `features/library/*` (`LibraryScreen`, `TracksTable`, `GroupsView`, `PlaylistsView`, `ResumeShelf`, `autoLists.ts`, `MobileMusic`, `MobileVideos`, `RemoveDialog`, `TagEditor`) |
| Historique / recherche / réglages | `features/history/*`, `features/search/*`, `features/settings/*` |
| Tokens | `src/styles/theme.css` (tokens `--mm-*`) — **aucun nouveau token de couleur n'est nécessaire** ; les valeurs sont celles déjà présentes |
| Stores | `stores/player.ts`, `stores/library.ts`, `stores/playlists.ts`, `stores/settings.ts`, `stores/mobilePlayback.ts` |
| Natif | `src-tauri/src/native_player.rs`, `playback_state.rs`, `playlists.rs`, `m3u.rs`, `device_media.rs` |

Les composants `src/components/*` (Button, IconButton, Icon, Menu, Overlay, ProgressBar, ToastHost, Feedback, VirtualGrid) doivent être réutilisés et étendus plutôt que dupliqués.

**Flutter** : le design system contient un mapping Flutter (ThemeData / ThemeExtension, go_router, Riverpod) en prévision d'une migration éventuelle. **Ce n'est pas la tâche de ce lot** : ne pas démarrer d'app Flutter. Ce mapping sert uniquement de référence si la migration est décidée plus tard (décision D3).

## About the Design Files
Les fichiers `.dc.html` de ce dossier sont des **références de design en HTML** (prototypes cliquables), **pas du code de production**. Ouvrir dans un navigateur avec `support.js` à côté. Les recréer dans `apps/client` avec ses composants, tokens Tailwind et stores. Ne pas embarquer le HTML.

## Fidelity
**Haute fidélité** : couleurs, typographie, espacements, rayons, ombres et comportements sont définitifs. Les zones hachurées sont des placeholders (pochettes, affiches, surface vidéo) remplacés par les médias de l'utilisateur.

## Navigation cible
- **Windows, sidebar espace Écouter** : `Accueil` (nouveau, D1) · groupe **Musique** (Albums, Artistes, Titres, Playlists, Favoris) · groupe **Cinéma** (Films & séries, Vidéos perso) · groupe **Focus** (Podcasts & cours, Livres audio). « En lecture » s'ouvre depuis la barre de lecture. Sélecteur Obtenir/Écouter inchangé.
- **Android, onglets** : `Musique · Cinéma · Focus` (corail) + `Obtenir` (teal, dernier) — extension de la décision 0006 (D2). Le navigateur reste hors barre comme aujourd'hui.
- Une commande de lecture reste toujours visible (barre 80 px Windows / mini-lecteur 64 dp Android).

## Screens / Views
Les IDs renvoient à l'inventaire (`Design System` §09) et aux sélecteurs en haut de chaque prototype.

### Windows — shell commun (fenêtre 1280 × 800 de référence, min 960 × 640)
- Barre de titre 40 px `#0D141B`, bordure basse `#1B2935` ; recherche centrale 420 × 30, radius 999, `#182530`, bordure `#243545`, kbd « Ctrl K ».
- Sidebar 232 px `#0D141B` (repliée 64 sous 1280 px) ; items 38 px radius 999, 13.5/600 ; actif = fond `#182530` + `inset 0 0 0 1px #243545`, icône corail `#FF7A45` FILL 1 ; en-têtes de groupe 11/700 uppercase +6 % `#64748B`.
- **Barre de lecture** 80 px pleine largeur `#0B1117`, bordure haute `#1B2935` ; grille 320 / 1fr / 320 ; pochette 52 radius 12 (clic → En lecture) ; transport : shuffle 20, prev/next 28 `#F5F7FA`, play 44 corail + halo `0 6px 18px rgba(255,122,69,.3)` ; seek 4 px `#243545`/corail, pouce 12 blanc ; à droite paroles, file, mini-lecteur (Ctrl M), volume 84 px.

### W-00 Accueil Écouter (nouveau)
Carte « Reprendre » 216 px radius 20 (pochette floutée + dégradé `rgba(13,20,27,.94)→.2`, affiche 112×168), bouton « Reprendre à mm:ss » corail ; « Vos listes automatiques » (4 cartes, `autoLists.ts`) ; « Focus en cours » (3 lignes avec progression) ; panneau droit 320 « En lecture » (pochette, titre, ligne de paroles courante) + « À suivre » — **sans boutons de transport** (ils sont dans la barre). Panneau masqué sous 1280 px.

### W-M1a/b/c Albums · Artistes · Titres
Grilles auto-fill (5 col. à 1280) ; cartes : survol = soulèvement + bouton lire 38 corail. Artistes en cercles. Titres : table `40 / 2fr / 1.3fr / 1.3fr / 110 / 60 / 36`, lignes 44, en lecture = titre `#FF9166` + icône graphic_eq, sélection `#16302F`, **introuvable** opacité .72 + « Fichier introuvable · Localiser » `#E8B04B`. Filtres en puces (actif `#3A2620`/`#7A4330`/`#FF9166`).

### W-M2a/b Album · Artiste
En-tête avec pochette floutée (opacité .55) ; titre 40/800 ; Lire (corail 42) / Aléatoire / Favori / Tags (`TagEditor` existant) / ⋯. Bandeau doublons `#2B2616`/`#4A3F1F` + badge P1. Artiste : image locale facultative (D5), « Les plus écoutés » (historique local), albums.

### W-M3 En lecture
Fond = pochette floutée σ60 + voile `rgba(13,20,27,.55)` ; pochette 360 radius 16 ; panneau droit 420 translucide `rgba(13,20,27,.55)` avec segment **Paroles / File / Son**. Paroles : lignes 26/800, courante `#F5F7FA`, passées 32 %, suivantes 50 % ; clic = seek ; source `.lrc` locale ou tag. File : existant (`QueuePanel`) + carte Smart Queue P1. Son : `EqualizerSection` (toggle corail, 5 préréglages, 6 bandes), vitesse, normalisation P1.

### W-M4 Mini-lecteur flottant (fenêtre compacte)
Fenêtre séparée 340 × 120 (jusqu'à 340 × 340), toujours au premier plan, pochette 120, transport 34 corail. Commandes aussi dans la miniature de la barre des tâches.

### W-M5 Playlists
Deux colonnes (300 + édition) ; réordonner par glisser ou Alt+↑/↓ (ligne surélevée, contour teal) ; import/export M3U existants ; création via dialogue (playlist intelligente P1).

### W-02 Recherche
Résultats groupés par type et section, puces avec compteurs, « Meilleur résultat », insensible aux accents ; recherche dans transcriptions = FUTUR.

### W-C1 / C2 / C3 / C4 Cinéma
Bibliothèque (segment Tout/Films/Séries, « Reprendre » 16:9 avec temps restant, affiches 2:3) ; fiche série (fond 300 px, pistes audio et sous-titres visibles **avant** lecture, bouton « Reprendre S1 · É4 à 23:12 », épisodes vus/en cours/introuvables) ; lecteur fenêtré (chapitres à droite P1, épisode suivant) ; plein écran (commandes masquées après 3 s, menus **Sous-titres** avec SRT/VTT/ASS + décalage ±0,1 s + taille, **Piste audio** mémorisée par série, **Chapitres** en vignettes, **Vidéo** : vitesse, ratio, recadrage, synchro audio, décodage matériel, A–B).

### W-03 Historique et reprise
Groupé par jour, toutes sections ; chaque ligne montre la position et propose Reprendre / Revoir ; effacer ne supprime aucun fichier.

### W-F1 / F2 Focus
Bibliothèque (En cours avec temps restant à la vitesse choisie, liste des leçons d'un cours) ; lecteur long format : −10/+30 s, play 72, vitesse segmentée (mémorisée par contenu), **Signet** (touche B, losanges sur la barre), « Fin estimée », minuteur fin de chapitre ; onglets Signets / Chapitres / Texte (**FUTUR**, rien de simulé).

### W-O1 Premier démarrage · import · analyse (Lot 4)
3 étapes sautables (langue/thème, dossiers typés Musique/Vidéo/Focus, analyse progressive avec « Commencer à écouter »). S'appuie sur l'analyse/scan existants ; ne pas dupliquer `features/analysis` (qui concerne Obtenir).

### W-O2 Fichiers introuvables · doublons
Groupes par cause (disque débranché, dossier renommé → mise à jour des chemins, fichier isolé) ; doublons P1 (empreinte + tags), garder la meilleure qualité, masquer par défaut, suppression → Corbeille. **Jamais de suppression automatique.**

### W-S1/2/3 Réglages
Apparence (thème, couleur de lecture P1, densité, taille du texte, réduire animations/transparence, pochette en fond), Lecture (moteur, sortie, WASAPI exclusif, reprise, gapless, fondu P1, normalisation P1, sous-titres par défaut), Raccourcis (modifiables, détection de conflit). S'insèrent dans `SettingsScreen` existant.

### W-E1/E2/E3 Vide · chargement · erreurs
Vide avec deux actions ; squelettes après 300 ms ; 6 cas d'erreur (codec, fichier endommagé, accès refusé, disque plein, hors ligne, base à réparer) : ce qui s'est passé, ce qui est conservé, une action, détails techniques copiables.

### Android (Lot 5, 360 dp de référence)
A-00 Accueil Musique · A-01 Titres (index alphabétique) · A-01b Recherche · A-02 Album / Artiste / Playlists · A-C Cinéma · A-F Focus · A-03 Lecteur audio (glisser ↓ = réduire, balayer pochette = titre, bouton paroles) · A-03b File (poignée, balayage pour retirer) · A-03c Égaliseur (curseurs 24 dp) · A-04 Vidéo portrait (PiP) · A-04b Paysage (gestes luminosité/volume, ±10 s, pincer, cadenas) · A-05 Notification/écran verrouillé (Media3 MediaSession, actions par section) · A-06 Autorisations (explication → dialogue système → A-07 refus) · A-07b Erreurs (carte SD retirée, format illisible) · A-08 Réglages.

## Interactions & Behavior
Voir `Lecteur Miarina - Handoff.dc.html` §02–§04 (flux, souris/clavier/glisser-déposer, gestes Android, retour système, animations avec durées et équivalents « mouvement réduit », règles responsive). Points clés :
- Une seule session de lecture pour toute l'app (déjà le cas via `PlayerHost`) : changer d'écran ne relance jamais la lecture.
- Fonctions non prises en charge par le moteur : masquées/désactivées, jamais simulées. P1 = visible + badge P1 + désactivé ; FUTUR = mentionné là où on le cherche.
- Transitions : écran 160 ms fondu + 8 px ; ouverture lecteur 320 ms (pochette partagée) ; album 240 ms ; dialogues 220 ms ; courbe `cubic-bezier(.2,0,0,1)` (déjà `--ease-standard`). Mouvement réduit → fondus 120 ms.
- Focus clavier : contour 2 px teal décalé 2 px ; cibles ≥ 32 px Windows, ≥ 48 dp Android.

## State Management (extensions des stores existants)
- `ui` : `space: 'play'` + nouvelles vues `listenHome`, `albums`, `album/:id`, `artists`, `artist/:id`, `cinema`, `series/:id`, `focus`, `focusPlayer`, `history`, `libraryHealth` ; `nowPanel: 'lyrics' | 'queue' | 'sound'` (ajout `lyrics`).
- `player` : existant + `section` (music | cinema | focus), `bookmarks` par média, `rate` mémorisé par contenu Focus, `subtitleDelay`, `audioTrack` mémorisé par série.
- `library` : `kind` étendu (podcast, cours, livre audio), `missing` groupés par cause, `duplicates` (P1), `autoLists`, couleur dominante de pochette calculée à l'indexation.
- Persistance SQLite (migrations versionnées) pour positions, signets, choix de pistes ; export/import JSON + M3U.

## Design Tokens
Inchangés : voir `src/styles/theme.css` et `Lecteur Miarina - Design System.dc.html` §03–§05.
Sombre : bg `#101820` · sidebar `#0D141B` · barre `#0B1117` · surface `#182530` · surface-2 `#1F2F3B` · line `#243545` · line-strong `#2A3D4E` · divider `#1B2935` · fg `#F5F7FA` · muted `#94A3B8` · faint `#64748B` · corail `#FF7A45` (hover `#FF9166`, press `#E8642E`, ink `#1F0C03`, subtle `#3A2620`, chip border `#7A4330`) · teal `#35C9BD` (subtle `#1F3A3C`, chip text `#5FE0D5`) · warning `#E8B04B` (bg `#2B2616`, border `#4A3F1F`) · danger `#F07070` · vidéo `#070B0F`.
Clair : valeurs `[data-theme='light']` existantes.
Typo : Manrope (display 40/800 et 28/800, title 18/700, body 14/500, label 13.5/600, caption 12, overline 11/700 +6 %) ; JetBrains Mono tabulaire pour temps, formats, chemins, raccourcis.
Rayons : 4 / 8 / 12 / 14 / 18 / 24 / 999. Ombres : `0 8px 20px rgba(0,0,0,.25)`, `0 12px 32px rgba(0,0,0,.4)`, `0 24px 64px rgba(0,0,0,.5)`, halo lire `0 8px 20px rgba(255,122,69,.25)`.

## Assets
- Logo 4d existant (`src/components/Logo.tsx`, `design/brand/`). À produire : icône Android 13+ monochrome, sous-ensemble Material Symbols Rounded mis à jour (liste DS §06), pochettes de repli.
- Pochettes, affiches, images d'artiste : **uniquement les fichiers locaux de l'utilisateur** (pas de récupération en ligne sans validation).

## Files
- `Lecteur Miarina - Design System.dc.html` — charte, tokens, composants et états, inventaire des écrans.
- `Lecteur Miarina - Windows Musique.dc.html` — Lot 2 (prototype cliquable).
- `Lecteur Miarina - Windows Cinema Focus.dc.html` — Lot 3.
- `Lecteur Miarina - Windows Systeme.dc.html` — Lot 4 (démarrage, import, introuvables, doublons, réglages, états).
- `Lecteur Miarina - Android.dc.html` — Lot 5 (+ paysage, notification/écran verrouillé).
- `Lecteur Miarina - Handoff.dc.html` — flux, interactions, motion, responsive, V1/P1/FUTUR, décisions.
- `Lecteur Miarina - Directions.dc.html` — historique des pistes explorées (3a retenue, section du haut).
- `support.js` — runtime nécessaire pour ouvrir les prototypes.

## Ordre de mise en œuvre conseillé
1. Shell Écouter : sidebar à sections + barre de lecture pleine largeur + onglets Android (sans casser Obtenir).
2. Bibliothèque Musique (albums, artistes, détails) + états introuvable/vide/chargement.
3. En lecture : onglet Paroles (.lrc) + intégration File/Son existants.
4. Cinéma : fiche série, menus pistes/sous-titres, reprise.
5. Focus : types de contenu, lecteur long format, signets, vitesse par contenu.
6. Accueil Écouter, historique, recherche groupée.
7. P1 ensuite (doublons, chapitres, Smart Queue…), en gardant badge P1 tant que non livré.

## Décisions à valider avant de coder
D1 entrée « Accueil » dans Écouter · D2 onglets Android à 4 entrées · D3 migration Flutter (hors périmètre de ce lot) · D4 pas de transparence Mica en V1 · D5 image d'artiste uniquement locale · D6 validation avec de vraies pochettes.
