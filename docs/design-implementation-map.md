# Miarina Media — Correspondance design → implémentation

> Statut : **proposition Phase 0**, rien n'est encore implémenté. Les chemins sont relatifs à `apps/client/src/`.
> Légende disponibilité : ✅ MVP fonctionnel · 🟡 MVP partiel / conditionnel · ⏳ PLANNED (affiché comme indisponible) · ❓ décision requise

## 1. Coquille d'application

| Élément du design | Windows | Android | Composants / modules |
|---|---|---|---|
| Barre de titre custom 40 px (logo, recherche Ctrl K, min/max/close) | ✅ | — | `components/shell/TitleBar.tsx` (+ `data-tauri-drag-region`, commandes fenêtre Tauri) |
| Sidebar 232 ↔ 64 (7 entrées, badges, carte de progression globale, bouton Collapse) | ✅ | — | `components/shell/Sidebar.tsx`, `components/shell/GlobalProgressCard.tsx` |
| Bottom bar 80 dp (4 onglets : Home, **Browser**, Downloads, Library depuis la décision 0001 / M5 ; Settings via l'engrenage de Home ; pill active, badge) | — | ✅ | `components/shell/BottomNav.tsx` |
| Toasts (max 2, 4 s, action unique) | ✅ | ✅ | `components/feedback/ToastHost.tsx`, store `ui/toasts` |
| Dialogue de confirmation (420, focus sur choix sûr) | ✅ | ✅ (sheet) | `components/overlay/ConfirmDialog.tsx`, `components/overlay/BottomSheet.tsx` |
| Raccourcis clavier globaux | ✅ | — | `hooks/useGlobalShortcuts.ts` |
| Thèmes Dark / Light / System | ✅ | ✅ | `styles/theme.css`, `features/settings/appearance` |

Le choix de la coquille se fait par **plateforme** (`services/platform.ts` → `isAndroid`), pas par largeur d'écran : on n'impose pas la navigation desktop sur Android.

## 2. Écrans

| # | Écran design | Windows | Android | Dossier feature | Composants principaux | Dépendances backend | Dispo MVP |
|---|---|---|---|---|---|---|---|
| 1 | **Home** | Écran plein : champ URL + Paste + Analyze, drop de lien, 4 actions rapides, Recent downloads (4), carte Library (compteurs, espace disque) | Carte « Paste a link » + bouton pill, 4 actions rapides, carte de téléchargement actif, liste Recent | `features/home` | `UrlInputCard`, `QuickActions`, `RecentDownloads`, `LibraryOverviewCard`, `ActiveDownloadCard` (Android) | `library.recent`, `library.stats`, `system.disk_space` | ✅ (Playlist / Batch : ❓ ⏳) |
| 2 | **URL analysis** | Écran (retour Home) : skeleton → miniature + métadonnées, onglets Video / Audio only / Subtitles, liste de formats radio, Save to / File name, Add to queue / Download | **Bottom sheet** : skeleton → en-tête, segmented Video/Audio, formats, sélecteur de stockage (2e sheet), bouton « Download · taille » | `features/analysis` | `AnalysisView`, `FormatTabs`, `FormatList`, `DestinationField`, `FileNameField`, `StoragePickerSheet` (Android), `NoMediaFound` | `media.analyze`, `downloads.enqueue` | ✅ (Subtitles : 🟡) |
| 3 | **Downloads** | Liste active (miniature 96×54, %, barre, src/format/taille, statut, pause/annuler) + Queue (drag-reorder, Start now, Remove), Pause all / Resume all | Segmented Active / Queue / Done, cartes 64×64, bouton rond pause/play, barre 6 dp, Pause all | `features/downloads` | `DownloadRow`, `QueueList` (drag & drop accessible clavier), `DownloadTabs` (Android), `ProgressBar` | événements `download://progress`, `downloads.{pause,resume,cancel,reorder,start_now,remove}` | ✅ (pause = 🟡 selon source, cf. architecture §5) |
| 4 | **Library** | Recherche, tri, grille/liste, chips All/Video/Audio, grille auto-fill 210 / tableau | Barre de recherche pill, chips, grille 2 colonnes 16:10 | `features/library` | `LibraryToolbar`, `LibraryGrid` / `LibraryTable` **virtualisés**, `MediaCard`, `FilterChips`, `EmptyLibrary` | `library.query` (pagination + FTS), miniatures via protocole d'asset | ✅ |
| 5 | **Player** | Surface vidéo + titre, seek bar (buffer), prev/±10 s/play/next, volume, temps, vitesse, sous-titres, PiP, plein écran, panneau 300 (File, Up next) | Plein écran modal : vidéo 16:9 ou pochette audio, seek, ±10 s, play 76 dp, vitesse/sous-titres/rotation/PiP | `features/player` | `VideoSurface`, `SeekBar`, `TransportControls`, `PlayerSidePanel`, `UpNextList` | Windows : `<video>` WebView2 + protocole d'asset (Range) ; Android : plugin natif Media3 sous les mêmes contrôles React (cf. architecture §7) | ✅ lecture de base (Windows ; Android vérifié sur émulateur le 2026-10-18 : vidéo, audio, pause, ±10 s, vitesse, reprise) ; PiP / sous-titres / plein écran Android : 🟡 |
| 6 | **History** | Segmented All/Completed/Failed, groupes par jour, statut (point + texte), actions Show in folder / Retry / More, Clear history (dialogue) | ❓ pas d'écran : onglet « Done » de Downloads | `features/history` | `HistoryGroup`, `HistoryRow`, `ClearHistoryDialog` | `history.query`, `history.clear`, `downloads.retry`, `system.reveal_in_folder` | ✅ |
| 7 | **Settings** | Navigation 6 onglets : General, Downloads, Storage, Performance, Appearance, Language ; lignes toggle/select/path/stepper/button/segmented/radio | Liste groupée : Downloads, App, About ; toggles 52×32 | `features/settings` | `SettingsNav`, `SettingRow` (variantes), `StorageUsage`, `ResourceModeSelector` ❓ | `settings.get/set`, `storage.usage`, `storage.clear_cache`, `storage.clean_temp` | ✅ (voir détail §3) |
| — | **Browser** (P0, décision 0001 ; maquettes D1–D3, M1–M5, cf. `design-system.md` §14) | Fenêtre dédiée : onglets dans la barre de titre, barre d'adresse + chip médias, barre de favoris, bouton flottant, feuille D2, page interne historique/favoris (D3) | Mode plein écran depuis l'onglet Browser : barre d'adresse, grille d'onglets (M2), bouton flottant centré, feuille M3, historique/favoris (M4), Settings dans Home (M5) | `features/browser` | `BrowserWindow`, `TabStrip`, `AddressBar`, `MediaChip`, `FavoritesBar`, `DownloadFab`, `MediaSheet`, `BrowsingHistory` ; Android : `MobileBrowser`, `TabGrid` | Windows : webview de page isolée (sans IPC) + détection côté Rust ; Android : WebView native via plugin Kotlin ; tables SQLite historique / favoris / onglets ; `media.analyze`, `downloads.enqueue` | 🟡 Windows : un onglet, D1 + D2 + bouton (B) livrés (`phase-4-browser-report.md`) ; onglets, D3, favoris : à venir ; Android : un onglet, M1 + M3 + bouton natif livrés (`phase-4-browser-report.md` §6) ; M2, M4 : à venir |
| — | **Actions d'un fichier (Android)** | — | Non maquetté (les ⋮ étaient « not designed yet ») : feuille du bas du design system (`BottomSheet`, lignes 56 dp, icônes 24) avec Play · Share · Open with… · Copy source link · Rename · Delete file (rouge `danger`). Ouverte par ⋮ (Recent, lecteur) et appui long sur une vignette de la bibliothèque. Dans le lecteur : Share, Open with, Copy link seulement | `features/library/MobileMediaSheet.tsx`, `useMobileMediaSheet.tsx` | `library_share`, `library_open_external` (Android : `MediaToolsPlugin.share/openWith`, FileProvider, lecture accordée à l'appli cible seulement) | ✅ vérifié sur émulateur (2026-10-18) |
| — | **Icône et écran de démarrage Android** | — | Non maquettés : dérivés du logo (`apps/website/assets/img/logo.svg`) et des tokens. Icône adaptative (fond accent `#35C9BD`, glyphe `#101820` dans la zone sûre, couche monochrome Android 13+), PNG d'origine pour Android 7. Démarrage : fond `bg` `#101820`, tuile du logo au centre, mot-symbole « Miarina Media » (Manrope 700, `#F5F7FA`) en bas sur Android 12+ ; affiché jusqu'au premier rendu de l'interface (max 3 s) | `gen/android/.../res`, `MainActivity.kt`, `AppShellPlugin.kt`, `src-tauri/src/shell.rs` | — | AndroidX `core-splashscreen` 1.2.0 | ✅ vérifié sur émulateur (2026-10-18) |
| — | **Notifications Android** | — | Progression (Pause/Cancel/Pause all), terminé (tap to play), en attente Wi-Fi (Use data), contrôles média | plugin `android-download` (Kotlin) | `DownloadNotification`, `MediaSessionNotification` | service premier plan / user-initiated job | 🟡 Phase 4 |

## 3. Réglages : faisabilité ligne par ligne

| Réglage (design) | Plateforme | Dispo | Remarque |
|---|---|---|---|
| Launch at startup | Win | ✅ | `tauri-plugin-autostart` (à valider) |
| Close to tray | Win | ✅ | tray icon Tauri ; nécessaire pour poursuivre les téléchargements fenêtre fermée |
| Detect copied links | Win | 🟡 | lecture presse-papier à l'activation de la fenêtre uniquement (pas de surveillance continue : vie privée + ressources) |
| When a link is pasted → Analyze automatically | Win | ✅ | |
| Save to / Library location | Win/And | ✅ | Android : sélection SAF (`ACTION_OPEN_DOCUMENT_TREE`) |
| Default video quality / audio format | Win/And | ✅ | |
| Simultaneous downloads (1–8 stepper) | Win/And | ✅ | borné par le mode de ressources |
| Speed limit | Win | 🟡 | yt-dlp `--limit-rate` ; moteur HTTP direct : limiteur de débit token bucket |
| Create a subfolder per source | Win/And | ✅ | nom de dossier = domaine assaini |
| Thumbnail cache / Temporary files (clean up) | Win/And | ✅ | |
| Hardware acceleration | Win | 🟡 | WebView2 décide du décodage matériel ; ce réglage n'aura d'effet que via les flags du navigateur → à confirmer ou retirer |
| Low-resource mode | Win/And | ❓ | **à remplacer/compléter par Eco/Balanced/Performance** (cahier des charges) |
| Reduce motion | Win/And | ✅ | + respect de `prefers-reduced-motion` |
| Thumbnail quality | Win/And | ✅ | taille de génération des miniatures |
| Theme Dark/Light/System, Density, Accent | Win/And | ✅ / 🟡 / 🟡 | Density « Compact » et Accent non maquettés (une seule valeur Teal) |
| Language (5 langues) | Win/And | ❓ | infra i18n au MVP ; traductions à fournir |
| Wi-Fi only for large files (> 100 MB) | And | ✅ Phase 4 | contraintes réseau du job |
| Progress notifications | And | ✅ Phase 4 | |

## 4. Composants partagés (`packages/ui` ou `apps/client/src/components`)

`Button` (primary, secondary, ghost-icon, destructive ; tailles sm/md/lg ; variantes Android tonal/pill), `TextInput` (link, error, disabled), `Tabs`, `Segmented`, `Chip`, `Toggle`, `Radio`, `Stepper`, `Select`, `Menu` / `ContextMenu`, `ProgressBar` (determinate, paused, error, indeterminate), `Dialog`, `BottomSheet`, `Toast`, `Skeleton` (délai 200 ms), `EmptyState`, `PlannedBanner`, `Badge`, `Kbd`, `Icon` (Material Symbols, fill on/off), `Thumbnail`, `Logo`.

Recommandation : **commencer ces composants dans `apps/client/src/components`** et ne créer `packages/ui` que si un 2e consommateur apparaît (site web). `CLAUDE.md` autorise explicitement à ne pas créer de packages vides.

## 5. Données fictives

Adaptation technique du 2026-10-27 : `MobileDownloads` ajoute une action texte
« Cancel download » avec la confirmation partagée, pour rendre l'annulation
accessible aussi pendant une fusion FFmpeg. Elle réutilise les tokens existants
et une cible tactile d'au moins 44 px ; aucun nouvel écran n'est introduit.

Les titres du prototype (Blender, NASA, Musopen, Internet Archive) ne servent qu'aux fixtures de la Phase 1 (`apps/client/src/dev/fixtures/`), chargées uniquement en mode développement et retirées des flux de production en Phase 2.
# Installateur Windows — 2026-10-28

Habillage demandé par le propriétaire : `apps/client/src-tauri/installer/`.
Logo Flow mark, palette sombre et tagline issus du design system. Les panneaux
NSIS utilisent ses dimensions standard ; contrôles système conservés.
Accueil français vérifié sur Windows, génération NSIS réussie. Aucune nouvelle
maquette de l'application ni aucun changement du parcours de mise à jour.

Miniatures absentes — demande du propriétaire du 28 octobre 2026 :
`LocalThumb.tsx` remplace les rayures par le logo officiel à 15 % d'opacité
sur surface-2, partagé entre desktop et mobile. Les miniatures existantes
et les badges restent affichés normalement.

## Landing v3
Home.tsx : sections ; LandingShell.tsx : navigation, thème et scroll spy ; DownloadDemo.tsx : simulation locale ; ReleaseLog.tsx : frise ; landing.css : tokens et états du handoff. Downloads.tsx conserve les liens et empreintes de release.ts. Sans JS : menu natif, formats complets, FAQ native et tableau entier. Contrôles interactifs activés après hydratation.

## Download submission states — 2026-10-29

AnalysisScreen.tsx and AnalysisSheet.tsx reuse the approved Button disabled palette during task creation, with Starting and aria-busy. useStartActions synchronously prevents repeat submissions before rendering. No layout or assets changed. Notifications now describe the existing Android-managed permission instead of showing SOON; processing uses a format-neutral label.

## Desktop playback error recovery — 2026-10-31

PlayerScreen.tsx retains the approved dark player surface and existing error banner. On media error, hide the failed video surface/backdrop; add Retry playback alongside the existing system-player action. Error text follows the media error code. This is a minimal recovery/accessibility adaptation to the reported white-screen failure; no new visual design.

## Player fullscreen — 2026-10-31

The native window was entering fullscreen but the app title/sidebar remained in the layout. DesktopShell now omits both while playerFullscreen is active; PlayerScreen hides its details panel as before. State is committed only after the native command succeeds, repeated requests are guarded, and leaving/unmounting the player exits native fullscreen. Escape restores normal layout. Minimal adaptation requested by the owner; existing player styles retained.

## Windows v2 — lot UI2-01 (2026-11-11)

Handoff : `design/design_handoff_windows_v2`. Ordre conseillé par le handoff : contrat lecteur → shell nav B + mini-lecteur → bibliothèque → lecteur vidéo natif → En lecture/Son → mises à jour → torrents/navigateur.

| Élément v2 | Statut | Code |
|---|---|---|
| Tokens corail, bandeau hors ligne | Fait | `styles/theme.css`, `app/DesktopShell.tsx`, `hooks/useOnline.ts` |
| Logo 4d | Fait (app) ; icônes installateur à régénérer | `components/Logo.tsx`, `assets/logo.svg` |
| Barre de titre (recherche 420, logo liseré) | Fait | `app/TitleBar.tsx` |
| Sidebar navigation B (Obtenir / Écouter, groupes Musique/Vidéo, En lecture, point mise à jour) | Fait ; vues L06 en PRÉVU | `app/Sidebar.tsx`, `app/navigation.ts`, `stores/ui.ts` (`space`, `libraryView`) |
| Catalogue FR/EN | Shell, mini-lecteur, En lecture, lecteur vidéo, titre bibliothèque, langue | `i18n/index.ts`, `stores/settings.ts` (`lang`) |
| Contrat lecteur COM-01 + file COM-03 + aléatoire/répétition COM-12 | Fait côté client (persistance localStorage) | `stores/player.ts` |
| Moteur unique (un élément média pour toute l'app) | Fait (WebView) ; libVLC après WIN-SPIKE | `features/player/PlayerHost.tsx` |
| Mini-lecteur 68 px | Fait | `features/player/MiniPlayer.tsx` |
| En lecture (pochette, transport, File/Son, vitesse, minuteur) | Fait ; égaliseur PRÉVU | `features/player/NowPlayingScreen.tsx` |
| Lecteur vidéo (en-tête, barre corail, ±10 s, volume, vitesse, PiP, plein écran) | Fait ; pistes/sous-titres PRÉVU | `features/player/PlayerScreen.tsx` |
| Bibliothèque Titres / Vidéos | Fait (liste par défaut pour Titres, grille pour Vidéos) ; table musique v2 à faire | `features/library/LibraryScreen.tsx` |
| Accueil, Analyse, Téléchargements, Navigateur, Torrents, Historique, Réglages v2 | À faire (lots suivants) | — |
| Éditeur de tags, dialogue Retirer/Supprimer | À faire (L06, COM-10) | — |

Le lecteur Android (`MobilePlayer`, Media3) n'est pas concerné par ce lot.
