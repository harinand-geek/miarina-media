# Miarina Media — Rapport Phase 4, tranche 1 : navigateur intégré (Windows)

> Note (2026-11-12) : les anciennes maquettes citées ici (`design/*.dc.html` v1, `design/design_handoff_landing_v3/`) ont été retirées du dépôt sur décision du propriétaire ; elles restent consultables dans l'historique git (`git show 63f712a:design/…`). Les maquettes en vigueur sont `design/design_handoff_windows_v2`, `design_handoff_android_v2` et `design_handoff_splash`.

Date : 2026-10-14 · Statut : **tranche livrée (un onglet)** · Décision : `docs/decisions/0001-embedded-browser-p0.md` · Maquettes : `design/Miarina Media - Browser.dc.html` (D1, D2, B) · Spike : `docs/spikes/browser-windows.md`.

Environnement : Windows 11 Pro 22000, Rust 1.99.0, Node 24.21, pnpm 12.11.2, WebView2 155, Tauri 2.12.3 **avec la feature `unstable`** (accord du 2026-10-14).

## 1. Livré

| Élément | Contenu |
|---|---|
| Fenêtre navigateur | Fenêtre dédiée sans décoration native (D1) : barre de titre avec logo, onglet (titre, icône, compteur de médias, fermer), min/max/fermer ; barre d'outils : précédent, suivant, recharger/arrêter, accueil, barre d'adresse (hôte + chemin atténué, cadenas, chip « N media »), téléchargements (badge). Ouverte par l'entrée Browser de la sidebar ou Ctrl+6. |
| Isolation | Trois webviews : `browser-ui` et `browser-overlay` (code de l'app, capability `browser.json` minimale), `browser-page` (site visité : **aucune capability**, http(s) seulement, popups rouverts dans l'onglet, téléchargements natifs refusés). |
| Détection | `media_core::detect` (pur, testé) alimenté par WebView2 : réponses réseau (type, statut, taille totale via `Content-Length`/`Content-Range`, `Sec-Fetch-Dest`), sources `<video>`/`<audio>` relevées par un script lancé depuis Rust (fin de chargement + toutes les 3 s, suspendu si fenêtre réduite), lecteurs MSE (`blob:`) → « la page » analysée par yt-dlp. Dédoublonnage, plafond de 50 éléments, remise à zéro à chaque navigation (y compris navigations internes des sites mono-page). |
| Bouton flottant (B) | États « found » (1 / N), « downloading » (pourcentage, débit, barre ; ouvre Downloads dans l'app), « done » (« Saved · Play » 4 s ; ouvre la bibliothèque). La webview overlay est **dimensionnée au bouton** : la page reste cliquable autour. |
| Feuille de formats (D2) | Liste des médias (cases à cocher, présélection), onglets Video / Audio only / Subtitles, formats issus de l'analyse existante, dossier + Change, Add to queue / Download ; Échap ou voile pour fermer ; consentement yt-dlp/FFmpeg si absent. |
| Raccourcis | Depuis la page : Ctrl+L, Ctrl+Shift+S, F5 (interceptés côté WebView2) ; depuis la barre : F5, Alt+←/→, Ctrl+Shift+S ; Alt+←/→ natifs dans la page. |
| Fenêtre principale | Badge « Later » retiré ; la fenêtre principale affiche Downloads / Library à la demande du navigateur. |

## 2. Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| `cargo test --workspace` | ✅ **131 tests** (+8 détection, +1 validation d'adresse) |
| `cargo clippy --workspace --all-targets -D warnings`, `cargo fmt --check` | ✅ |
| `tsc`, `eslint`, `prettier --check`, `vitest` | ✅ **50 tests** (+6 navigateur : présélection, adresse invalide/valide, feuille → téléchargement) |
| App release pilotée (clics, clavier, DevTools) | ✅ ouverture depuis la sidebar ; page Wikimedia : 5 médias, feuille D2 avec analyse réelle (480p, 92 Mo) ; **téléchargement complet** (fichier de 92,2 Mo dans `Videos\Miarina`), bouton « 7 % · 1.0 MB/s » puis « Saved · Play » ; **clic sur la page à côté du bouton reçu** ; YouTube : seule « la page » proposée, analyse yt-dlp 2160p→720p ; fichier vidéo direct : détecté par le réseau avec sa taille (30 Mo) |
| Lecture automatique du lecteur sans `--autoplay-policy` | ✅ toujours automatique et avec le son après un clic dans la bibliothèque → le drapeau est **retiré** (les sites visités ne lancent plus de son sans geste) |

## 3. Défauts trouvés pendant la vérification et corrigés

1. Sons d'interface YouTube (`open.mp3`…) proposés comme médias : ce sont des objets `Audio()` servis par le service worker, sans taille ni type (diagnostic par trace temporaire, retirée). Règle : les fichiers vus sur le réseau ne sont proposés que s'ils sont ouverts directement ou si leur taille totale est connue et ≥ 256 Kio.
2. Page HTML dont le chemin finit par `.webm` détectée comme vidéo : l'extension ne décide plus que pour un type vide ou générique.
3. Libellé du bouton coupé sur deux lignes (mesuré avant le chargement de la police) : largeur intrinsèque (`w-max`).
4. Placeholder visible sous l'adresse affichée ; titre d'onglet de la page précédente conservé.
5. Toast « history_list not allowed by ACL » dans la feuille : permission en lecture ajoutée à la capability du navigateur (l'ACL a fait son travail).
6. Fichier d'entrée `browserOverlay.tsx` écrasant `BrowserOverlay.tsx` (système de fichiers insensible à la casse) : entrées déplacées dans `src/browser-*.tsx`.

## 4. Écarts avec la maquette (documentés)

- **Un seul onglet** : le bouton « + », Ctrl+T/W, la barre de favoris, l'étoile, Favoris/Historique (D3) et le menu ⋮ ne sont pas affichés (tranche suivante, SQLite).
- **Partie gauche du bouton** : télécharge le média présélectionné (format par défaut), pas *tous* les médias (sur Wikimedia, « tous » = 5 variantes du même film).
- **État « Detecting »** et réduction du bouton au défilement : non réalisés (le premier exige d'afficher l'overlay sans détection, le second d'observer le défilement de la page).
- **Page d'accueil** (aucune page) : non maquettée, composée avec le motif « état vide » du design system.
- Onglet Subtitles : informatif (sous-titres non pris en charge).

## 5. Limites connues / non vérifié

- **Android : rien.** Aucun appareil connecté (`adb devices` vide).
- La page partage le profil WebView2 (cookies, stockage) de l'interface de l'app ; les objets IPC de Tauri restent injectés dans la page (aucune commande autorisée, mais détectables).
- Téléchargements d'éléments qui exigent cookies, `Referer` ou session : non transmis volontairement → peuvent échouer (403).
- Tauri `unstable` : API susceptible de changer ; version épinglée.
- Le module `browser` n'est pas encore protégé par `cfg(desktop)` : à faire avant toute compilation Android.
- Sites testés : Wikimedia Commons, YouTube, un fichier direct. Pas de test HLS/DASH réel, d'iframe de lecteur, de DPI élevé, ni de mesure CPU.
- La correction du titre d'onglet (point 4) est couverte par le build mais n'a pas été revérifiée visuellement dans l'app.

## 6. Tranche Android : navigateur (M1, M3) — 2026-10-18

Environnement : émulateur `voakajy_test` (Android 15 / API 35, x86_64), APK release x86_64 signé. **Aucun appareil physique.**

### Livré

| Élément | Contenu |
|---|---|
| Page | `BrowserPlugin.kt` : WebView native placée par l'interface au-dessus de la zone « page » de l'écran React (même principe que la surface du lecteur Media3). Réglages : JavaScript et stockage DOM pour les sites ; **aucune interface JavaScript**, aucun accès fichier/contenu, contenu mixte refusé, pas de popups (les liens `target=_blank` s'ouvrent dans la page), géolocalisation coupée, lecture automatique sur geste seulement. Liens d'application (`intent:`, `market:`, `tel:`…) refusés. Vidéo plein écran du site gérée (Retour la quitte). |
| Chrome (M1) | Barre d'adresse 44 dp (cadenas, hôte en mono, chip « ↓ N »), compteur d'onglets, menu ⋮ (Recharger, Paramètres), ligne de chargement 3 dp, barre du bas (précédent, suivant, accueil, historique, Miarina = retour à l'app). La barre de navigation principale est masquée dans le navigateur. Page de démarrage : recherche + raccourcis. Saisie : adresse ouverte, sinon recherche Google (`address.rs`, partagé avec Windows). |
| Détection | Relevé des `<video>`/`<audio>` du document principal (fin de chargement puis toutes les 3 s, uniquement page affichée) et fichiers que la page propose au téléchargement (`DownloadListener` : ils sont signalés, jamais enregistrés par la WebView). Classement et filtres dans Rust (`browser/page_state.rs` → `media_core::detect`), remise à zéro à chaque navigation (y compris sites mono-page). **Android ne propose que les fichiers vidéo/audio directs** : flux HLS/DASH et lecteurs MSE (`blob:`) demandent l'extracteur, absent sur Android. |
| Bouton flottant | Natif (les vues natives sont dessinées au-dessus de l'app) : pastille 52 dp `#35C9BD`, « Download » ou « Download · N », centré 16 dp au-dessus de la barre, entrée 200 ms fondu + montée 12 dp. Appui = feuille M3 ; appui long = téléchargement immédiat au format par défaut (toast « Downloading · … »). |
| Feuille (M3) | Feuille d'analyse existante + puces des médias de la page. Les variantes d'un même fichier sont nommées par ce qui les distingue (« 480p.vp9.webm ») ; présélection : meilleure copie ≤ 1080p plutôt qu'un original énorme (aussi sur Windows). Après « Download », on reste sur la page avec un toast « Download started · View ». |
| Recouvrement | Une feuille, un menu, les paramètres, le lecteur ou une confirmation masquent la page native ; une **image JPEG de la page** (prise juste avant, ½ résolution) est affichée à sa place sous le voile. Média de la page mis en pause quand elle est masquée. Toasts placés sur la barre du navigateur (sinon cachés par la page). |
| Retour Android | Ferme le menu / la saisie, puis recule dans la page, puis revient à l'accueil de l'app. |

### Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| `cargo test` (app) | ✅ dont 6 nouveaux tests `page_state` (génération, filtres Android, téléchargements proposés, adresse affichée, geste du bouton, entrées de l'interface) |
| `cargo clippy --all-targets -D warnings`, `cargo fmt` | ✅ (hôte Windows) |
| `tsc`, `eslint`, `prettier --check`, `vitest` | ✅ **63 tests** (+4 : navigateur mobile, adresse refusée, libellés des variantes, présélection ≤ 1080p) |
| `tauri android build --apk --target x86_64` | ✅ |
| Émulateur | ✅ page de démarrage ; saisie d'une adresse Commons → page affichée, **5 médias détectés**, bouton « Download · 5 » ; appui → feuille M3 avec capture de la page, puces, analyse réelle (WEBM 92 Mo) ; téléchargement lancé en restant sur la page, terminé, visible dans Récents ; recherche Google depuis la barre ; ouverture d'un résultat, touche Retour → page précédente, Suivant actif ; appui long → téléchargement direct + toast ; page masquée quand on quitte l'onglet |

### Défauts trouvés sur émulateur et corrigés

1. Toast invisible dans le navigateur (dessiné sous la page native) → placé sur la barre du bas, un seul à la fois.
2. Puces identiques (« Big_Buck_Bunny_4K.we… ») → libellés distinctifs.
3. Titre long débordant de la feuille → retour à la ligne.
4. Appui long : l'original de 2,76 Go choisi → présélection ≤ 1080p.

### Écarts avec la maquette (documentés)

- **Un seul onglet** : le compteur affiche 1 sans ouvrir M2 ; historique (M4) désactivé dans la barre ; favoris et « Help & feedback » absents du menu. Tranches suivantes.
- Bouton flottant natif : police système en gras (Manrope n'est pas disponible côté natif) ; réduction en cercle au défilement non réalisée.
- Feuille M3 : le fond est une image figée de la page, pas la page vivante.

### Limites / non vérifié

- Pas d'appareil physique ; pas de mesure mémoire/CPU/batterie.
- Médias dans des iframes d'autres origines non détectés (le relevé ne lit que le document principal).
- Téléchargements exigeant cookies, `Referer` ou session : non transmis → peuvent échouer.
- L'écran Téléchargements Android n'a **pas d'action Annuler** (manque antérieur, constaté pendant ce test).
- La page de confidentialité du site sera mise à jour à la publication d'une version contenant le navigateur.

## 7. Windows : navigateur dans la fenêtre principale, favoris — 2026-10-18 (version 0.1.3)

Demande de l'utilisateur : « mets exact comme [l'APK] sur desktop… pas de nouvelle fenêtre… ajouter des icônes favoris… laisse faire une recherche, pas lien seulement ».

- **Écart avec la maquette D1 (accepté par l'utilisateur)** : plus de fenêtre dédiée. L'écran Browser de la fenêtre principale reprend l'écran Android (`BrowserView`, M1) ; la page (`browser-page`) et l'overlay (`browser-overlay` : bouton flottant B et feuille D2 conservés) sont des webviews enfants de la fenêtre `main`, placées par `browser_frame`. Le bouton flottant est centré au-dessus de la barre comme sur mobile. Le module `browser-ui` (barre de titre et onglet D1) est supprimé.
- **Sécurité** : la page est dans la fenêtre `main`, mais c'est une origine distante ; les capabilities sans `remote` ne s'appliquent qu'aux origines locales (vérifié dans `tauri-utils` `acl/resolved.rs`), donc la page ne peut appeler aucune commande. L'overlay reçoit aussi la capability `default` (code de l'app).
- **Favoris** (Windows et Android) : étoile dans la barre d'adresse ; tuiles « Favorites » sur la page de démarrage ; stockés dans la table `settings` SQLite (`browser.favorites`, 48 au plus, http(s) seulement, titre borné).
- **Recherche depuis l'accueil** : des mots qui ne forment pas un lien ouvrent le navigateur sur une recherche (la barre d'adresse le faisait déjà).
- **Défauts trouvés et corrigés pendant le test Windows** : création concurrente des webviews (« webview already exists ») → création exclusive ; retour arrière vers la page de démarrage laissant l'interface sur celle-ci → état « page de démarrage » suivi à chaque navigation ; lecteur : boucle de rendu (référence de la vidéo recréée à chaque rendu) qui vidait la fenêtre → référence stable.
- **Lecteur** : bandes rayées remplacées par un fond flou (image courante de la vidéo, 48×27 px redessinée toutes les 400 ms pendant la lecture ; pochette floutée pour l'audio, fond uni sans pochette).
- Toujours **un seul onglet** ; historique à venir.
