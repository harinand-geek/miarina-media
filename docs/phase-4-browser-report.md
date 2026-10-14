# Miarina Media — Rapport Phase 4, tranche 1 : navigateur intégré (Windows)

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
