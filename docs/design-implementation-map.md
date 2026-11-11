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
| Bibliothèque Titres (tableau v2), Albums, Artistes, Dossiers, ouverture d'un groupe, Tout lire / Aléatoire | Fait (L06) ; Playlists et Favoris PRÉVU (COM-06) | `features/library/{LibraryScreen,TracksTable,GroupsView}.tsx`, commande `library_groups`, migration v5 |
| Éditeur de tags (Windows v2 écran 5) | Fait : champs audio/vidéo, paroles, « Remplir depuis le nom », « Renommer Artiste - Titre », écriture fichier optionnelle (audio) ; pochette PRÉVU | `features/library/TagEditor.tsx`, `crates/library/src/tags.rs`, commandes `library_tags` / `library_update_tags` |
| 1 Accueil v2 | Fait (UI2-02) | `features/home/HomeScreen.tsx` — titre « Du lien à votre bibliothèque », champ 48 px avec Coller intégré, aides Ctrl V / glisser / extension, actions rapides (Audio seul, Torrent / magnet ; Playlist et Plusieurs liens PRÉVU), « Reprendre » (médias lus récemment, non terminés : `features/player/recentPlays.ts` + positions), « Récemment téléchargés » ; la carte « Bibliothèque » et l'action « Ouvrir le dossier » de l'ancien écran sont retirées comme dans la maquette, « Ouvrir le dossier » passe dans Réglages |
| 2 Analyse v2 | Fait (UI2-02) | `features/analysis/AnalysisScreen.tsx` — en-tête vignette 224 + titre + source mono + puces calculées (meilleure qualité, nombre de sous-titres ; « Reprise possible » non affichée faute d'information), onglets soulignés, lignes 56 px, note par onglet, barre basse 68 px (dossier, Changer, Ajouter à la file, Télécharger · taille) ; état aucun média `NoMediaFound.tsx` avec « Ouvrir dans le navigateur » ; aperçu du nom de fichier retiré (absent de la maquette) |
| 3 Téléchargements v2 | Fait (UI2-02) | `features/downloads/DownloadsScreen.tsx` + `status.ts` partagé avec Android — En cours / Terminés / Échecs avec compteurs, bouton unique Tout mettre en pause / Tout reprendre (Ctrl P), lignes vignette 72, état icône + texte, conversion « étape 2/2 · ffmpeg » distincte (DL-06), reprise annoncée seulement si la source la permet ; l'ordre de la file reste modifiable (glisser une ligne en attente, ou Alt + ↑/↓ sur sa vignette) ; une ligne Terminé n'a pas de croix (l'historique ne s'efface qu'en entier) |
| 10 Historique v2 | Fait (UI2-03) | `features/history/HistoryScreen.tsx` — segmenté Téléchargements / Lectures (COM-13), groupes par jour traduits (`grouping.ts`), lignes 52 px heure · icône · titre · détail mono, « Effacer l'historique » par onglet (aucun fichier supprimé) ; historique de lecture local borné (`features/player/recentPlays.ts`, `mm:playHistory:v1`, position d'arrêt notée à la pause ou au changement de média), qui alimente aussi « Reprendre » ; menu ⋯ conservé (afficher dans le dossier / réessayer, copier le lien source) |
| 9 Torrents v2 | Fait (UI2-03) | `features/torrents/TorrentsScreen.tsx` — pastille d'état de session (corail quand le partage est actif), « Arrêter tout et le partage » / « Activer la session », champ magnet + Analyser le lien + Ouvrir un .torrent, cartes avec barre et stats icône + libellé + valeur (reçu, envoyé, pairs, reste ; terminé : partage, ratio réel, pairs), « Arrêter le partage » = mise en pause, limites de réception / d'envoi réelles (appliquées à Entrée ou en quittant le champ) ; ratio cible et durée de partage PRÉVU (pas encore dans le moteur) ; « Importer dans la bibliothèque » non affiché ; ouvrir le dossier et retirer conservés ; aperçu navigateur : données fictives `dev/torrentsMock.ts` en développement seulement |
| 11 Réglages v2 | Fait (UI2-03) | `features/settings/SettingsScreen.tsx` — navigation 236 px (Général, Mises à jour, Téléchargements, Lecture, Stockage, Performance, Apparence, Langue, Extension navigateur), contenu 720 px, lignes `SettingRow` restylées ; actifs : dossier (ouvrir / changer), téléchargements simultanés, outils média, reprise de lecture, stockage (disque, cache, fichiers temporaires), mode de ressources, réduction des animations, thème, langue FR/EN, mises à jour (carte : version, notes, téléchargement, vérification, installation à la demande), extension en 3 étapes (`BrowserExtension.tsx` : dossier, identifiant, liens reçus) ; PRÉVU au lieu de faux contrôles : démarrage, zone de notification, détection du presse-papiers, canal bêta, téléchargement automatique, qualité / format par défaut, limite de vitesse, sous-titres, décodage matériel, gapless, associations de fichiers ; moteur affiché tel qu'il est (« Intégré · WebView2 », libVLC après WIN-SPIKE) ; l'appairage par code de la maquette n'existe pas : le parcours réel par identifiant d'extension est conservé |
| Navigateur v2 | À faire (lot suivant) | — |
| Dialogue Retirer / Supprimer (COM-10) | Fait (Windows) ; Android garde la confirmation de suppression en attendant la maquette mobile | `features/library/RemoveDialog.tsx`, commande `library_remove`, migration SQLite v4 |

Le lecteur Android (`MobilePlayer`, Media3) n'est pas concerné par ce lot.

## Android v2 (handoff reçu le 2026-11-11)

| Écran | Statut |
|---|---|
| Shell 5 onglets, mini-lecteur Android | Fait : `app/MobileShell.tsx`, `features/player/MobileMiniPlayer.tsx` ; le lecteur plein écran reste monté quand il est réduit (le moteur natif n'est pas fermé) ; Retour réduit le lecteur au lieu de l'arrêter ; « Suivant » désactivé tant que la file Android n'existe pas (L03) ; Musique/Vidéos réutilisent la grille existante en attendant les écrans 05/14 |
| 05/15/16 Musique (Titres, Albums, Artistes, Dossiers, fiche artiste/album/dossier), 14 Vidéos | Fait : `features/library/MobileMusic.tsx`, `MobileVideos.tsx` ; 06 Playlists et Favoris PRÉVU (COM-06) ; « Importer un dossier » PRÉVU (COM-08) ; fichier introuvable non affiché (la requête exclut les fichiers absents) ; file de lecture Android au premier plan seulement (`ui.mobileQueue`, enchaînement à la fin du titre) jusqu'à L03 |
| 11 Retirer / Supprimer (sheet) | Fait : `features/library/MobileRemoveSheet.tsx` ; ouverte depuis la feuille d'actions (« Retirer ou supprimer… ») ; texte « playlists mises à jour » remplacé par « retiré de la file de lecture » (pas encore de playlists) |
| 07/08/09 En lecture, File, Son | Fait (audio) : `features/player/MobilePlayer.tsx`, `MobilePlayerSheets.tsx`, `stores/mobilePlayback.ts` — « Lecture depuis », aléatoire, répétition off/file/titre, vitesse persistée, minuteur, paroles locales, file réordonnable (poignée) ; égaliseur remplacé par une explication (natif L03/L07) ; favori (cœur) masqué tant que COM-06 n'existe pas ; balayer pour retirer remplacé par le bouton ✕ ; tout cela au premier plan seulement jusqu'à L03 |
| 10 Notification / écran verrouillé | Fait (L03a) : notification et commandes système Media3 (`PlaybackService`), contenu et actions reprises, style = gabarit système comme prévu par la maquette ; vérifié sur émulateur Android 15, recette téléphone à faire |
| 01 Accueil | Fait : `features/home/MobileHome.tsx` — carte de lien, actions rapides (Playlist PRÉVU), carte téléchargements, « Reprendre » d'après les positions enregistrées (sinon « Récemment téléchargés »), point de mise à jour sur Réglages ; animation logo du splash non faite (handoff splash) |
| 02–04 Navigateur, Formats, Téléchargements | Fait : `features/browser/BrowserView.tsx` (barre d'adresse sur `sidebar`, chemin grisé, chip `movie N`, Favoris dans la barre basse, libellés FR/EN), `features/analysis/AnalysisSheet.tsx` (segmenté Vidéo / Audio seul / Sous-titres PRÉVU, tag Recommandé, « À la file »), `features/downloads/MobileDownloads.tsx` (En cours / Terminés / Échecs, état icône + texte, conversion distincte, reprise annoncée seulement si possible) ; règle « Wi-Fi uniquement » et bandeau réseau mesuré non affichés tant que DL-10 n'existe pas ; onglets multiples (compteur fixé à 1) et unités « MB » / « Internal storage » encore non traduits |
| 12 Réglages | Fait : `features/settings/MobileSettings.tsx` — carte mise à jour (disponible → téléchargement → prête et vérifiée, « Plus tard », jamais forcée, téléchargements en cours nommés), Éco / Équilibré / Performance avec les limites réelles, « Reprendre où j'en étais » réel (`mm:resume`), casque / gestes / fondu / gapless PRÉVU ; « Wi-Fi uniquement » retiré tant que DL-10 n'existe pas |
| 13 Vidéo paysage | À faire en natif (L07) : la vue Media3 est dessinée au-dessus de la WebView (`setZOrderMediaOverlay`), les commandes superposées, le vrai plein écran, la rotation, les pistes et les gestes demandent le plugin Kotlin et une recette téléphone |
| 17–18 clair/EN | À faire (recette) |
