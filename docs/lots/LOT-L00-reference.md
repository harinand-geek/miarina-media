# Fiche LOT-L00 — Référence : corpus, appareils, mesures (Windows)

- Statut : Fait pour Windows sur la machine disponible (endurance 60 min validée le 2026-11-12) ; Android et seconde machine Windows **non validés** (pas d'appareil)
- Exigences CDC : § 13 (objectifs proposés, matrice matérielle), § 14 (corpus, défauts prioritaires)
- Mesures détaillées : `docs/performance.md` (section L00, 2026-11-12)

## Matrice des appareils réellement disponibles

| Cible | Appareil | État |
|---|---|---|
| Windows 11 x64, machine récente | Intel Core i5-8300H (4 cœurs / 8 fils), 16 Go, SSD, Intel UHD 630 + NVIDIA GTX 1050 Ti, Windows 11 Pro 10.0.22000, WebView2 157, 2 écrans 1920 × 1080 à 100 % | **validée** (mesures ci-dessous) |
| Windows modeste (GPU intégré seul, 2 cœurs / 4 Go) | — | non validée (pas d'appareil) |
| Windows DPI 150 / 200 % | — | non validée (échelle 100 % seulement) |
| Windows sans VLC installé | — | non validée (VLC 3.0.24 installé sur la machine ; le processus ne charge pourtant aucun module depuis `Program Files\VideoLAN`, voir `docs/licenses/libvlc-3.0.24-modules.md`) |
| Android ARM64 modeste / récent | — | non validée (émulateur seulement, recette téléphone de L03 en attente) |

## Corpus de référence (Windows)

Généré avec FFmpeg (aucun média tiers) ; commandes dans `docs/decisions/0005-windows-player-engine.md` et ci-dessous :

- `mkv multipistes.mkv` : H.264 1080p 12 s, AAC « Français » et « English », SRT intégré accentué + `mkv multipistes.srt` voisin ;
- `hevc.mp4` (H.265 1080p 8 s), `vp9.webm` (VP9/Opus 720p 8 s), `av1.mkv` (AV1 720p 6 s), `divx.avi` (MPEG-4/MP3 576p 8 s), `4k-h264.mp4` (H.264 2160p30 15 s, 60 Mbit/s), `corrompu.mp4` (tronqué), `dossier avec espaces/été – 测试 ✓.mkv` ;
- `long-1080p.mp4` : `ffmpeg -f lavfi -i testsrc2=size=1920x1080:rate=25:duration=300 -f lavfi -i sine=frequency=330:duration=300 -c:v libx264 -preset veryfast -crf 30 -g 50 -c:a aac long-1080p.mp4` (5 min, 74 Mo) ;
- bibliothèque de recette : 3 pistes MP3 (« Album Recette »), FLAC, WAV, vidéos téléchargées en recette.

## Résultats contre les objectifs proposés (§ 13)

| Mesure | Objectif proposé | Résultat (moteur libVLC) | État |
|---|---|---|---|
| Premier son / image, froid (premier fichier après démarrage, 10 démarrages) | p95 ≤ 2 s | médiane ~390 ms, max 1 117 ms | atteint |
| Premier son / image, chaud (20 essais, 4 fichiers) | p95 ≤ 2 s | p50 458 ms, p95 500 ms, max 1 119 ms | atteint |
| Play / pause (30 actions, commande → état du moteur) | p95 ≤ 200 ms | p95 26 ms (257 ms avant correctif, voir défauts) | atteint après correctif |
| Seek local (20 positions, fichier 5 min 1080p) | p95 ≤ 1 s | p95 416 ms | atteint |
| Recherche 10 000 médias (à chaque frappe) | p95 ≤ 500 ms | p95 8,9 ms, max 11,7 ms | atteint |
| Mémoire (20 ouvertures / fermetures puis repos) | pas de croissance persistante | processus principal : 223 → 230 Mo pendant les lectures, **31 Mo** au repos, 43 Mo après 20 cycles de plus ; WebView2 stable ~158 Mo | atteint |
| Endurance 60 min | aucun crash / blocage | 2e passage : 1 169 actions en 60 min, **0 échec**, mémoire stable (médiane 105–276 Mo, 105 Mo après arrêt) ; 1er passage arrêté à 50 min par fermeture manuelle de la fenêtre | **atteint** |
| Taille de l'installeur | écart mesuré et justifié | 91,2 Mio contre 70,2 Mio pour 0.1.7 : +21 Mio, dû à libVLC (lecture native, décision 0005) | mesuré |

## Défauts et limites prioritaires (état au 2026-11-12)

| Priorité | Défaut | Suite |
|---|---|---|
| P1 | Décision sur l'ensemble des modules libVLC livrés (17 modules à notice GPL, contribs à relever) et essai de l'installeur sur une machine sans VLC | tâche Flow « recette machine sans VLC et licences » (en revue) |
| P1 | Recette Android sur téléphone réel (L03) | phase mobile |
| — | Corrigé pendant L00 : indexation lente des gros dossiers (10 000 entrées en 30 s, une écriture SQLite par fichier et recherche linéaire des chemins connus) → 3,2 s (une transaction, table de hachage) | fait |
| P2 | Glisser-déposer HTML dans la page désactivé sous Windows par le gestionnaire natif de dépôt de fichiers (réordonner la file à la souris) ; Alt + ↑ / ↓ disponible | à étudier (dépôt natif ciblé) |
| P2 | Commandes du lecteur hors de l'image (fenêtre transparente possédée non vérifiée à l'œil) | à vérifier par le propriétaire |
| — | Mémoire en hausse pendant le 1er passage d'endurance (médiane 114 → 652 Mo) : non reproduite au 2e passage (médiane 105–276 Mo sur 60 min, 105 Mo après arrêt) ni sur 100 ouvertures | surveillé, pas de défaut retenu |
| P3 | Messages d'erreur du moteur non traduits quand ils ne sont pas reconnus | au fil des lots |
| — | Corrigé pendant L00 : play / pause répondait en 257 ms (relevé d'état libVLC toutes les 250 ms) → 26 ms (relevé toutes les 20 ms pendant 600 ms après une commande) | fait |
