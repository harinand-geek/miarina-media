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

## Non mesuré à ce stade

- CPU et RAM pendant un téléchargement actif et pendant une conversion FFmpeg.
- Effet mesuré des modes Eco / Performance (les limites appliquées sont testées, leur coût réel ne l'est pas).
- Machine modeste (2 cœurs / 4 Go), écran haute densité, disque dur mécanique.
- Android : rien.
