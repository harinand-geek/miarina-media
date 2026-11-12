# Miarina Media — Mesures de performance

Mesures **réellement relevées**, avec leur environnement. Aucun objectif chiffré n'est fixé ici : ce document sert de point de comparaison pour la Phase 5 (profilage).

## Environnement

| Élément | Valeur |
|---|---|
| Machine | Intel Core i5-8300H @ 2,30 GHz, 16 Go RAM, SSD |
| Système | Windows 11 Pro 10.0.22000 |
| WebView2 | 155 |
| Build | `pnpm tauri build --no-bundle` (profil `release`), exécutable non signé |
| Mode de ressources | Balanced (par défaut) |
| Bibliothèque | 5 fichiers (4 vidéos, 1 audio, 84 Mo) |

## Phase 3 — 2026-10-14

| Mesure | Résultat | Méthode |
|---|---|---|
| Taille de `miarina-media.exe` | 12,2 Mo | taille du fichier ; hors yt-dlp (17,8 Mo) et FFmpeg (138 Mo installé), téléchargés au premier besoin |
| Démarrage à froid → fenêtre créée | 51 – 175 ms (3 essais) | `Start-Process` jusqu'à `MainWindowHandle ≠ 0` |
| Démarrage à froid → écran Home rendu | 1,38 – 1,70 s (3 essais) | interrogation du DOM via le port de débogage WebView2 ; précision ±~100 ms, le port de débogage peut lui-même ralentir le démarrage |
| Processus principal (Rust) | ~29 Mo working set, ~5,5 Mo privés | `Get-Process`, en lecture comme au repos |
| WebView2 (7 processus) pendant la lecture d'une vidéo 240p WebM/VP9 | ~412 Mo working set, ~197 Mo privés | somme des processus `msedgewebview2.exe` de l'app ; le working set compte plusieurs fois les pages partagées, la mémoire privée est plus représentative |
| WebView2, bibliothèque au repos (10 s après avoir quitté le lecteur) | ~407 Mo working set, ~190 Mo privés | idem |
| Recherche FTS sur 5 000 entrées (base en mémoire) | sous le seuil de 500 ms du test (build debug) ; temps exact non relevé | test `storage::media::a_large_library_stays_fast` |

## Phase 4, tranche 1 (navigateur) — 2026-10-14

Même machine, build release. Fenêtre principale + fenêtre navigateur ouvertes, après visite de YouTube puis Wikimedia Commons.

| Mesure | Résultat | Méthode |
|---|---|---|
| Processus principal (Rust) | ~6,4 Mo privés | `Get-Process` |
| WebView2 (11 processus, les deux fenêtres) | ~558 Mo privés : navigateur 65, GPU 97, renderers 156 (page) + 59 + 55 + 51 + 31, utilitaires ~41 | somme des `msedgewebview2.exe` de l'app |
| Coût propre au navigateur | environ +370 Mo privés par rapport à la fenêtre principale seule (~190 Mo en Phase 3), page visitée comprise | différence ; sites lourds (YouTube) inclus |

## L00 — référence (2026-11-12)

Même machine (Core i5-8300H 4 cœurs / 8 fils, 16 Go, SSD, Intel UHD 630 + GTX 1050 Ti), Windows 11 Pro 10.0.22000, WebView2 157, 2 écrans 1920 × 1080 à 100 %. Build release de recette (`tauri build --no-bundle`, identifiant isolé), moteur de lecture **libVLC 3.0.24** (décision 0005), son coupé pendant les mesures. Mesures relevées dans l'application par son port de débogage (événements du moteur), corpus décrit dans `docs/lots/LOT-L00-reference.md`.

| Mesure | Résultat | Méthode |
|---|---|---|
| Premier son / image, froid | médiane ~390 ms, max 1 117 ms (10 démarrages) | premier fichier après le démarrage de l'application : commande d'ouverture → premier état « lecture » avec une position > 0 ; fichiers MP3, MKV 1080p, MP4 1080p 5 min en alternance |
| Premier son / image, chaud | p50 458 ms, p95 500 ms, max 1 119 ms (20 essais) | idem, application déjà lancée, 4 fichiers en alternance |
| Play / pause | p95 26 ms, max 26 ms (30 actions) | commande → état « pause » / « lecture » rapporté par le moteur ; **257 ms avant correctif** (état relevé toutes les 250 ms ; maintenant toutes les 20 ms pendant 600 ms après une commande) |
| Seek | p95 416 ms (20 positions) | fichier 5 min 1080p : commande → position rapportée à moins d'1 s de la cible |
| Recherche 10 000 médias | p95 8,1–8,9 ms, max 11,7 ms (50 frappes) | `cargo run --release -p storage --example search_bench` : base sur disque, titres / artistes / albums réalistes, première page (100) à chaque frappe |
| Indexation de 10 000 entrées | **3,2 s** (30,4 s avant regroupement en une transaction) | même exemple ; l'analyse de dossier de la bibliothèque écrit maintenant en une transaction et retrouve les chemins connus par table de hachage |
| Mémoire, processus principal (libVLC inclus) | ~223–230 Mo privés pendant les lectures, **31 Mo** 30 s après l'arrêt, 43 Mo après 20 cycles de plus | 20 ouvertures / fermetures (5 fichiers) puis 30 s de repos, `PrivateMemorySize64` |
| Mémoire, WebView2 (6 processus) | ~157–161 Mo privés, stable sur les mêmes cycles | somme des `msedgewebview2.exe` du profil de recette |
| Endurance (prévue 60 min) | **arrêtée à 50 min** : 897 actions (ouverture, seek, piste audio, pause / lecture, changement d'écran toutes les 3 s), 0 échec jusqu'à 11:29:50 UTC, puis le processus de l'application a disparu ; aucun rapport d'erreur Windows, aucun vidage mémoire, aucun événement « Application Error » (Windows en enregistre bien pour d'autres applications sur cette machine), sortie d'erreur non capturée pendant ce passage. Cause : la fenêtre de recette a été fermée à la main par le propriétaire vers 11:30 UTC (confirmé), ce que montrent aussi ces traces ; pas un plantage. Critère « 60 min » non atteint par ce passage, refait ci-dessous | `endurance.mjs` par le port de débogage, son coupé, mémoire relevée chaque minute |
| **Endurance 60 min (2e passage, 12:54–13:55 UTC)** | **atteint** : 1 169 actions (ouverture, seek, piste audio, pause / lecture, changement d'écran toutes les 3 s), **0 échec**, aucune intervention ; mémoire du processus principal par tranche de 10 min : médiane 105, 186, 193, 256, 246, 276 Mo (maximum 434) ; **105 Mo 30 s après l'arrêt** ; WebView2 ~770–990 Mo (écran Navigateur ouvert par l'essai) ; sortie d'erreur : seul message « Error parsing OBU data » (1 780 fois), émis par le décodeur AV1 sur le fichier `av1.mkv` lors des seeks, sans effet visible | même script, sortie d'erreur capturée |
| Mémoire pendant l'endurance (1er passage) | processus principal, médiane par tranche de 10 min : 114, 274, 400, 492, 652 Mo (minimum 7, 90, 123, 317, 493 ; maximum 384 à 739) ; WebView2 185–270 Mo, puis 810–960 Mo après l'ouverture de l'écran Navigateur par les clics de l'essai | `PrivateMemorySize64` toutes les minutes |
| Mémoire, 100 ouvertures sans arrêt | 299 Mo après 20 ouvertures, 316 Mo après 100 (palier), **48 Mo** 30 s après l'arrêt : pas de croissance liée aux ouvertures ; la croissance pendant l'endurance (seeks, changements de piste, pauses mêlés) n'est pas expliquée | `leak.mjs`, 6 fichiers en rotation toutes les 1,5 s |
| Taille de l'installeur Windows | **91,2 Mio** (95 607 326 octets) contre 70,2 Mio pour 0.1.7 publié (73 603 463 octets) : **+21 Mio** | NSIS, `tauri build` ; l'écart vient de libVLC (78 Mo sur disque, 280 modules) |
| Taille installée des outils | FFmpeg 138 Mo, libVLC 78 Mo, yt-dlp 18 Mo, QuickJS 3 Mo, exécutable 17,3 Mo | `tools/` à côté de l'exécutable |

## Non mesuré à ce stade

- CPU et RAM pendant un téléchargement actif et pendant une conversion FFmpeg.
- Effet mesuré des modes Eco / Performance (les limites appliquées sont testées, leur coût réel ne l'est pas).
- Machine modeste (2 cœurs / 4 Go), écran haute densité (150 / 200 %), disque dur mécanique, machine sans VLC installé.
- Android : rien.
