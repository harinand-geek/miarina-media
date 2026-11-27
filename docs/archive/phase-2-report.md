# Miarina Media — Rapport Phase 2 (vertical slice Windows)

Date : 2026-10-14 · Statut : **terminée** · Environnement : Windows 11 Pro 22000, Rust 1.99.0 (MSVC 14.51), Node 24.21, pnpm 12.11.2, WebView2 155.

## 1. Livré

| Tranche | Contenu |
|---|---|
| `storage` | SQLite (WAL), migrations versionnées (`rusqlite_migration`), tâches / historique / réglages, **toute transition validée par la machine à états** de `media-core`, récupération après crash, lignes corrompues signalées sans panique |
| `resource-manager` | Eco / Balanced / Performance → limites concrètes : téléchargements simultanés, conversions, threads FFmpeg, fragments, fréquence de progression, taille des miniatures, priorité des processus, animations |
| `download-engine` | Moteur HTTP en streaming (`.part` → finalisation atomique **sans écrasement**, reprise **uniquement** si le serveur confirme les plages, vérification de l'espace disque, refus des réponses tronquées ou trop longues) ; gestionnaire borné (pause/reprise/annulation/retry exponentiel avec jitter, réordonnancement, « Start now », événements limités) |
| yt-dlp + FFmpeg | Téléchargement **au premier besoin avec consentement** et **SHA-256 épinglé** (D3) ; extraction zip limitée aux fichiers attendus (anti zip-slip) ; yt-dlp lancé avec `--ignore-config`, `--no-plugin-dirs`, `--` avant l'URL, arguments en tableau, sortie bornée et non fiable ; **Job Object Windows** pour tuer yt-dlp et FFmpeg à l'annulation ; formats proposés = ceux réellement fournis, DRM exclus, lives refusés ; étape « Preparing / merging » pour fusion/conversion |
| Tauri | Commandes étroites et validées, **app manifest** : chaque commande est accordée explicitement dans la capability ; aucune permission fs/shell/dialog/opener côté front ; plugins dialog/opener appelés depuis Rust uniquement |
| Interface | Interface `Backend` unique (implémentation Tauri réelle + mock navigateur au même contrat) ; Downloads, History, Analyse, Settings branchés sur les vraies données ; écran de consentement des outils ; section Media tools |

## 2. Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| `cargo test --workspace` | ✅ **102 tests** (+1 test réseau `#[ignore]` exécuté manuellement, voir ci-dessous) |
| Tests d'intégration contre un serveur HTTP local | ✅ reprise par Range, serveur sans Range, 416, transfert coupé, 404/503, annulation, non-écrasement, limite de concurrence, retry, échec définitif, pause/reprise, **session interrompue puis reprise**, changement de limite à chaud — stables sur 5 exécutions répétées |
| Test réseau réel `ytdlp_live` | ✅ installation vérifiée de yt-dlp 2026.08.19 et FFmpeg n8.1.2 LGPL, analyse d'une page Wikimedia Commons (4 formats réels), téléchargement 240p (30,4 Mo), dossier de travail nettoyé |
| `cargo clippy -D warnings`, `cargo fmt --check` | ✅ |
| `pnpm typecheck`, `pnpm lint`, `pnpm test` (37 tests), `prettier --check` | ✅ |
| **Bout en bout dans l'app release** (pilotée par clics/clavier réels) | ✅ lien direct Blender → analyse → téléchargement : **SHA-256 identique** à une copie `curl` indépendante ; 2e téléchargement → `sintel_trailer-480p (1).mp4` (non-écrasement) ; historique persistant entre deux lancements |
| **Crash réel** (`Stop-Process -Force` pendant un téléchargement de 30,9 Mo) | ✅ au relancement la tâche est **en pause** (jamais reprise en silence), reprise → fichier final **SHA-256 identique** à la référence |
| Page web via yt-dlp dans l'app | ✅ consentement → installation (progression par outil) → analyse (métadonnées réelles, licence CC BY 3.0) → téléchargement → fichier final ; extraction **MP3** : étape « Preparing / merging » visible, `ffprobe` : MP3 10:34, 228 kb/s VBR |

## 3. Défauts trouvés pendant la vérification et corrigés

1. **Interblocage** à l'annulation d'un téléchargement en cours (verrou SQLite repris dans un `if let`) — attrapé par un test d'intégration qui ne se terminait pas.
2. **Mapping de l'analyse côté Tauri** : tout résultat non « ready » devenait « No media » sans raison (remplacement scripté silencieusement non appliqué) — trouvé en interrogeant l'app via le protocole DevTools ; test de non-régression ajouté.
3. **Course** : la réponse de `downloads_start` (instantané « waiting ») écrasait l'événement « downloading » et laissait la ligne dans la file pendant tout le transfert — test de non-régression ajouté.
4. Sélection par défaut du format le plus lourd (2,76 Go) → désormais « Recommended », sinon le meilleur ≤ 1080p.
5. Pause proposée pendant une conversion (impossible) → désactivée.
6. Libellé « Idle · Paused », date d'historique sans virgule (« Saturday 10 October »), licence FFmpeg erronée (LGPL-3.0 et non 2.1).

## 4. Limites connues / non vérifié

- **Android : rien de cette phase n'a été compilé ni exécuté sur Android.** yt-dlp/FFmpeg sont des binaires Windows (Phase 4).
- Les conversions lancées par yt-dlp ne sont pas encore soumises au sémaphore `max_conversions` (seul le nombre de threads FFmpeg est borné) ; un pipeline de conversion séparé arrive en Phase 3.
- Reprise yt-dlp : `--continue` reprend les `.part` HTTP ; pour les formats fragmentés (HLS/DASH), la reprise dépend de yt-dlp et n'a pas été testée.
- Bibliothèque, aperçu Home, lecteur : toujours sur fixtures (badge **PROTOTYPE**) — Phase 3.
- Réglages non persistés : thème, langue, toggles de démarrage/tray/presse-papier (les réglages persistés sont : dossier, simultanéité, mode de ressources).
- « Close to tray », « Launch at startup », détection du presse-papier : non implémentés.
- Pas d'installeur ni de signature de code ; WebView2 suppose un runtime à jour.
- Une fois, la barre latérale s'est repliée seule après un clic sur Download ; non reproduit en 4 essais.

## 5. Prochaine étape : Phase 3

Bibliothèque SQLite réelle (indexation du dossier, FTS, miniatures via FFmpeg), lecteur `<video>` via le protocole d'asset, pipeline de conversion borné, menus contextuels (Show in folder, Rename, Delete), fin du badge PROTOTYPE.
