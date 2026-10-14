# Miarina Media — Architecture (proposition Phase 0, en attente de validation)

> Statut : **PROPOSITION**. Aucun code n'est écrit. Les choix marqués ❓ demandent une validation explicite.

## 1. Vue d'ensemble

```
┌──────────────────────────── apps/client (Tauri 2) ─────────────────────────────┐
│  React + TS + Vite + Tailwind  (présentation, état UI Zustand)                  │
│        │ invoke() commandes typées          ▲ événements typés throttlés       │
│────────┼────────────────────────────────────┼───────────────────────────────────│
│  src-tauri (Rust) : commandes étroites et validées, capabilities minimales     │
│        │                                                                        │
│   ┌────▼─────────┐  ┌───────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│   │download-engine│─▶│resource-manager│  │   storage    │  │   media-core     │  │
│   │ file, scheduler│  │ sémaphores,   │  │ SQLite,      │  │ modèles, états,  │  │
│   │ trait Engine   │  │ modes, budgets│  │ migrations   │  │ validation chemins│  │
│   └──┬─────────┬──┘  └───────────────┘  └──────────────┘  └──────────────────┘  │
│      │         │                                                                │
│  ┌───▼───┐ ┌───▼────────┐            ┌──────────────────────────────────────┐   │
│  │ HTTP  │ │ yt-dlp     │ (Windows)  │ plugins/android-download (Kotlin)    │   │
│  │ direct│ │ + FFmpeg   │            │ extracteur, service/job, MediaStore, │   │
│  │(Rust) │ │ sidecars   │            │ notifications, Media3 (Android)      │   │
│  └───────┘ └────────────┘            └──────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────┘
```

Principes : le frontend ne touche jamais au système de fichiers ni aux processus ; toute la logique métier vit en Rust (testable sans UI) ; les spécificités plateforme sont derrière des adaptateurs.

## 2. Structure du dépôt proposée

```
miarina-media/
├── CLAUDE.md
├── design/                         # handoff Claude Design (lecture seule)
├── docs/
│   ├── architecture.md             # ce document
│   ├── design-system.md
│   ├── design-implementation-map.md
│   ├── android-feasibility.md
│   ├── phase-0-report.md           # risques, toolchain, plan, questions ouvertes
│   ├── performance.md              # créé en Phase 5 avec des mesures réelles
│   └── decisions/                  # ADR numérotés
├── apps/
│   └── client/
│       ├── package.json
│       ├── index.html, vite.config.ts, tsconfig.json
│       ├── src/
│       │   ├── app/                # routes, coquilles Desktop/Mobile
│       │   ├── components/         # design system React
│       │   ├── features/{home,analysis,downloads,library,player,history,settings,browser}/
│       │   ├── hooks/
│       │   ├── services/           # wrappers invoke/listen typés, platform
│       │   ├── stores/             # Zustand (UI uniquement)
│       │   ├── styles/             # theme.css (@theme Tailwind 4), fonts
│       │   ├── assets/             # logo, polices embarquées
│       │   └── dev/fixtures/       # données fictives, dev uniquement
│       └── src-tauri/
│           ├── Cargo.toml, tauri.conf.json, build.rs
│           ├── capabilities/       # desktop.json, mobile.json (moindre privilège)
│           ├── binaries/           # sidecars yt-dlp / ffmpeg (non versionnés, cf. §6)
│           ├── gen/android/        # projet Android généré par Tauri
│           └── src/{lib.rs, commands/, events.rs, state.rs, platform/}
├── crates/
│   ├── media-core/                 # types, machine à états, validation URL/chemins, noms de fichiers
│   ├── download-engine/            # trait Engine, scheduler, retry, moteurs http + ytdlp
│   ├── storage/                    # rusqlite + migrations + repositories
│   └── resource-manager/           # modes Eco/Balanced/Performance, sémaphores, budgets
├── plugins/
│   └── android-download/           # plugin Tauri mobile (Kotlin + glue Rust), Phase 4
├── packages/
│   └── shared-types/               # types TS générés depuis Rust (ts-rs)
├── Cargo.toml                      # workspace Rust
├── pnpm-workspace.yaml
└── package.json
```

**Écarts justifiés par rapport à `CLAUDE.md`** :
- `packages/ui` **n'est pas créé** au départ (un seul consommateur) ; les composants vivent dans `apps/client/src/components`. Création si le site web le justifie.
- `plugins/android-download` est créé en **Phase 4**, après le spike de faisabilité, pas en Phase 1.
- `packages/shared-types` est **généré** (pas écrit à la main) pour éviter la dérive des contrats Rust ↔ TS.

## 3. Frontières des modules

| Module | Responsabilité | Ne doit PAS |
|---|---|---|
| `media-core` | Types de domaine (`MediaInfo`, `Format`, `DownloadTask`, `TaskState`, `TaskError`), machine à états avec transitions validées, validation d'URL (http/https uniquement, pas d'IP privées ❓, pas de `file:`), assainissement des noms de fichiers Windows/Android (caractères réservés, noms réservés `CON`, `NUL`…, longueur, espaces/points finaux), résolution des conflits (`name (1).ext`), garde anti-traversée | faire des I/O |
| `storage` | Connexion SQLite (WAL), migrations versionnées (`rusqlite_migration`), repositories `tasks`, `media`, `history`, `settings`, récupération après crash | connaître Tauri |
| `download-engine` | Trait `Engine`, scheduler (file bornée, priorité/ordre, concurrence), retry avec backoff exponentiel borné + jitter, estimation vitesse/ETA (moyenne glissante), throttling des événements, moteurs concrets `HttpEngine` et `YtDlpEngine` | parler à l'UI directement |
| `resource-manager` | Profils Eco/Balanced/Performance → limites concrètes (concurrence téléchargements, conversions, fréquence d'événements, taille miniatures, priorité processus), détection batterie/réseau mesuré | |
| `src-tauri` | Composition, commandes Tauri (validation des entrées), pont événements, fenêtre/tray, adaptation plateforme | contenir de la logique métier |
| `android-download` | Exécution des téléchargements sur Android hors du cycle de vie de l'Activity, SAF/MediaStore, notifications, lecture native | dupliquer la logique de file/état (elle reste en Rust autant que possible, cf. `android-feasibility.md`) |

## 4. Contrat du moteur de téléchargement

```rust
// crates/download-engine (esquisse, non contractuelle)
#[async_trait]
pub trait Engine: Send + Sync {
    fn id(&self) -> EngineId;
    fn capabilities(&self) -> EngineCaps;          // supports_pause_resume, supports_formats, …
    fn can_handle(&self, url: &ValidatedUrl) -> Confidence;
    async fn analyze(&self, url: &ValidatedUrl, cancel: CancellationToken) -> Result<MediaInfo, EngineError>;
    async fn start(&self, req: StartRequest, sink: ProgressSink, cancel: CancellationToken)
        -> Result<CompletedFile, EngineError>;     // stream vers fichier .part, finalisation atomique
}
```

- `analyze` renvoie métadonnées + formats **réellement fournis par la source** (pas de qualité inventée).
- **Pause** = annulation coopérative + conservation du `.part` ; **reprise** uniquement si `EngineCaps::supports_resume` ET que la source l'a confirmé (HTTP : `Accept-Ranges: bytes` + `ETag`/`Last-Modified` inchangés ; yt-dlp : `--continue` sur flux HTTP, fragments HLS/DASH partiellement). Sinon l'UI affiche « Restart » et non « Resume ».
- `status` / `formats` / métadonnées du fichier final sont servis par `storage`, pas par le moteur.

### Machine à états des tâches

```
queued ─▶ analyzing ─▶ waiting ─▶ downloading ─▶ processing ─▶ completed
   │          │           │            │  ▲            │
   │          │           │            ▼  │            │
   │          │           │          paused            │
   └──────────┴───────────┴────┬───────┴───────────────┘
                               ▼
                   failed (retryable / fatal) · canceled
```

Transitions validées par `media-core` ; toute transition invalide est une erreur testée. Au démarrage, les tâches trouvées en `downloading/processing` sont replacées en `paused` (ou `queued` si non reprenables) — récupération après crash.

## 5. Gestionnaire de téléchargements

| Exigence | Conception |
|---|---|
| File persistante | table `tasks` (état, ordre, format choisi, chemins `.part`/final, octets, tentatives, erreur) ; écriture à chaque transition + checkpoint d'octets ≤ 1/5 s |
| Concurrence configurable | `tokio::sync::Semaphore` téléchargements + sémaphore séparé conversions, tailles issues du mode de ressources ; file bornée (refus explicite au-delà, ex. 500 tâches) |
| Progression | le moteur publie dans un canal borné ; agrégation et émission vers l'UI **à 1 Hz max par tâche** (design : ticks d'1 s + tween 900 ms) ; un seul événement `downloads://progress` groupé par tick |
| Vitesse / ETA | moyenne mobile exponentielle sur fenêtre ~5 s |
| Retry | erreurs classées (réseau / HTTP 5xx / 429 → retry ; 4xx / non supporté / disque plein → fatal) ; backoff 2 s → 60 s, ×2, jitter, max 5 tentatives (configurable) ; l'UI montre « retrying in N s » (design) |
| Nom de fichier sûr | `media-core::sanitize_filename` + vérification que le chemin canonique final reste sous le dossier de destination autorisé |
| Conflits | détection avant démarrage + au moment de la finalisation (rename atomique `MoveFileExW` / `rename`) ; suffixe ` (n)` |
| Disque plein | vérification d'espace libre avant démarrage (taille estimée + marge) et gestion de `ENOSPC`/`ERROR_DISK_FULL` en cours → état `failed` « disk full » (toast du design) |
| Hors ligne | détection des erreurs réseau → pause automatique, reprise au retour réseau (état « You're offline » du design) |
| Historique | table `history` alimentée aux états terminaux ; « Clear history » ne supprime pas les fichiers (design) |

## 6. Adaptateur Windows

- **Moteurs** : `HttpEngine` (liens directs vers des fichiers média, `reqwest` en streaming, Range) et `YtDlpEngine` (pages de sites supportés).
- **yt-dlp** : exécutable autonome `yt-dlp.exe` lancé comme **sidecar Tauri** (`externalBin`) ou depuis un dossier de composants géré (cf. décision D3). Appels par `tokio::process::Command` avec **tableau d'arguments**, jamais de chaîne shell :
  - analyse : `--ignore-config --no-plugin-dirs ❓(selon version) --dump-single-json --no-playlist --skip-download -- <url>` ;
  - téléchargement : `--ignore-config --newline --progress-template <json> --no-exec ❓ -f <format_id> -P <dir_temp> -o <template sûr> --ffmpeg-location <ffmpeg> -- <url>` ;
  - `--ignore-config` empêche un fichier de config utilisateur d'injecter `--exec` ; `--` empêche une URL commençant par `-` d'être lue comme option.
  - La sortie JSON est **non fiable** : désérialisation stricte avec bornes de taille, champs optionnels tolérés, titres assainis.
- **Processus** : `CREATE_NO_WINDOW` ; chaque tâche dans un **Job Object Windows** (`JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE`) pour tuer yt-dlp **et** ses enfants FFmpeg à l'annulation ou à la fermeture de l'app ; priorité processus abaissée en mode Eco ; timeout d'analyse (ex. 60 s).
- **FFmpeg** : uniquement pour fusion audio+vidéo (DASH), extraction/convertion audio (MP3/M4A/FLAC du design) ; nombre de conversions simultanées borné ; build **LGPL** de préférence (cf. risques).
- **Fenêtre** : `decorations: false`, barre de titre custom, taille min 960×640, tray pour « Close to tray ».

## 7. Lecteur et bibliothèque

- **Bibliothèque** : table `media` (chemin ou content URI, type, durée, résolution, codecs, taille, source, dates, miniature) + index FTS5 sur titre/source ; vérification d'existence paresseuse (au scroll / à l'ouverture) et scan léger au démarrage ; listes **virtualisées** (`@tanstack/react-virtual`) ; requêtes paginées.
- **Miniatures** : vignette de la source téléchargée à l'analyse ou extraite par FFmpeg ; stockées sur disque (cache) en WebP/JPEG à la taille d'affichage, jamais en base.
- **Lecture Windows** : `<video>/<audio>` HTML dans WebView2 via le protocole d'asset Tauri (support des requêtes Range, pas de chargement complet en RAM) avec scope limité au dossier bibliothèque. Codecs pris en charge par WebView2 : H.264/AAC, VP8/VP9, AV1, Opus, Vorbis, MP3, FLAC dans MP4/WebM/Ogg ; **HEVC et MKV non garantis** → bouton « Ouvrir avec le lecteur système » + préférence de formats compatibles à l'analyse (le format « Recommended » du design = MP4 H.264). PiP via l'API web `requestPictureInPicture` si WebView2 l'expose — **à vérifier**, sinon marqué indisponible.
- **Lecture Android** : **Media3/ExoPlayer natif** via le plugin Kotlin (MediaSession, notification média du design, lecture audio en arrière-plan, PiP Android). Le `<video>` WebView ne permet pas une lecture fiable en arrière-plan ni la notification média.

## 8. Modes de ressources (effets mesurables)

| Paramètre | Eco | Balanced (défaut) | Performance |
|---|---|---|---|
| Téléchargements simultanés max | 1 | 2 (Android) / 3 (Windows, design « up to 3 at once ») | jusqu'à la valeur utilisateur (≤ 8) |
| Conversions FFmpeg simultanées | 1 | 1 | 2 |
| Threads FFmpeg (`-threads`) | 1 | moitié des cœurs | tous |
| Fragments concurrents yt-dlp (`-N`) | 1 | 2 | 4 |
| Fréquence événements progression | 0,5 Hz | 1 Hz | 1 Hz |
| Taille miniatures générées | petite | moyenne | grande |
| Priorité processus enfants | BELOW_NORMAL | NORMAL | NORMAL |
| Animations | fondus 120 ms (design « Low-resource ») | complètes | complètes |
| Sur batterie (auto) | — | bascule Eco si réglé | — |

Les valeurs exactes sont des **hypothèses de départ** ; leurs effets (CPU, RAM, débit) seront mesurés en Phase 5 et consignés dans `docs/performance.md`.

## 9. IPC Rust ↔ React

- Commandes (noms indicatifs) : `media_analyze`, `downloads_enqueue`, `downloads_start_now`, `downloads_pause`, `downloads_resume`, `downloads_cancel`, `downloads_reorder`, `downloads_list`, `library_query`, `library_stats`, `library_delete_file`, `library_rename`, `history_query`, `history_clear`, `settings_get`, `settings_set`, `system_disk_space`, `system_reveal_in_folder`, `system_pick_folder`.
- Événements : `downloads://progress` (lot, ≤ 1 Hz), `downloads://state` (transitions), `library://changed`, `system://network`.
- Types générés par **ts-rs** dans `packages/shared-types` ; erreurs sérialisées en enum discriminée (`{ kind: "DiskFull", … }`) pour que l'UI affiche les messages du design.
- Frontend : Zustand pour l'état UI ; les listes de téléchargements sont abonnées par sélecteurs fins (une ligne ne se re-rend que si sa tâche change).

## 10. Sécurité

- Capabilities Tauri : aucune permission `fs` ni `shell` exposée au frontend ; seulement les commandes applicatives ci-dessus + fenêtre/dialog nécessaires. Sidecars appelés **uniquement depuis Rust**.
- CSP stricte (pas de scripts distants, polices locales) ; protocole d'asset limité aux dossiers bibliothèque/miniatures.
- URLs : schémas `http/https` seulement, longueur bornée, pas d'identifiants dans l'URL journalisés ; option ❓ refuser `localhost`/IP privées (SSRF local).
- Pas de journalisation d'URLs complètes ni de cookies ; logs avec rotation et taille bornée.
- Pas de contournement de DRM, paywall ou authentification ; **pas d'import de cookies de navigateur** au MVP. Les sources DRM sont signalées comme non supportées.
- Mises à jour des composants (yt-dlp/FFmpeg) : URL épinglée, vérification **SHA-256**, consentement utilisateur.

## 11. Choix de dépendances (versions stables vérifiées le 2026-10-13 sur npm / crates.io / GitHub)

| Dépendance | Version stable actuelle | Rôle | Remarque |
|---|---|---|---|
| tauri / @tauri-apps/cli / @tauri-apps/api | 2.12.3 / 2.12.2 / 2.12.3 | coquille | |
| tauri-build | 2.7.2 | build | |
| react | 19.3.0 | UI | |
| vite | 8.3.4 | build front | |
| tailwindcss | 4.3.3 | styles | config CSS-first : transcription des tokens du handoff |
| typescript | **6.0.3 retenue** (7.0.2 disponible) | typage | typescript-eslint 8.71 exige TypeScript < 6.1 : TS 7 écarté en Phase 1 |
| zustand | 5.0.15 | état UI | |
| @tanstack/react-virtual | 3.14.13 (3.14.19 publiée la veille, écartée par la politique d'âge minimal de pnpm) | virtualisation | |
| vitest / @testing-library/react / user-event | 5.0.4 / 16.3.3 / 14.6.7 | tests front | |
| pnpm | 12.11.2 | workspaces | non installé ; via corepack |
| tokio | 1.53.2 | async | |
| reqwest | 0.13.5 | HTTP streaming | rustls |
| rusqlite (+ bundled) / rusqlite_migration | 0.40.2 / 2.6.0 | SQLite | préféré à `tauri-plugin-sql` : la base reste côté Rust, pas d'accès SQL depuis le frontend |
| ts-rs | 12.0.1 | génération types TS | |
| thiserror / serde | 2.0.21 / 1.0.229 | erreurs / sérialisation | |
| windows-sys | 0.61.2 | Job Objects, espace disque | |
| yt-dlp | 2026.08.19 | extracteur Windows | Unlicense ; binaire PyInstaller |
| FFmpeg | à choisir | fusion/conversion | build LGPL (cf. risques) |
| youtubedl-android | à évaluer | extracteur Android | **GPL-3.0** (vérifié sur GitHub) |

Non retenus : Electron, Next.js dans l'app, backend distant, `tauri-plugin-shell` exposé au frontend, `tauri-specta` (encore en RC pour Tauri 2 à ma connaissance — à re-vérifier si on veut générer aussi les commandes).

## 12. Ajustements réalisés en Phase 2

- **Dépendances entre crates** : `download-engine` dépend de `storage` et `resource-manager` (le gestionnaire de file y vit et persiste chaque transition). `media-core` reste sans I/O.
- **Commandes Tauri** : déclarées dans un *app manifest* (`build.rs`) ; chaque commande est accordée explicitement dans `capabilities/default.json`. Les plugins `dialog` et `opener` sont appelés depuis Rust uniquement.
- **Moteurs** : `http` (liens directs) et `ytdlp` (pages). L'analyse sonde d'abord le lien en HTTP ; une page HTML part vers yt-dlp.
- **Format choisi** : pour yt-dlp, l'identifiant de format est un `FormatSpec` opaque (sélecteur, fusion, extraction audio) **revalidé** côté Rust avant usage (liste blanche de caractères et de valeurs).
- **Dossier de travail yt-dlp** : `<fichier>.<id>.part.d` à côté de la destination ; supprimé à l'annulation ou à la fin ; le fichier produit est finalisé par la même routine sans écrasement que le moteur HTTP.
- **Composants** : `%APPDATA%\org.miarina.media\components\<outil>\<préfixe sha>\`, publiés atomiquement après vérification (voir `licenses.md`).
- **Historique** : stocke l'URL source (copie du lien, nouvel essai d'un téléchargement annulé) ; elle n'est jamais journalisée.
- **Événements** : un seul canal `downloads://event` ; le front considère les événements comme faisant foi (une réponse de commande ou un instantané ne remplace jamais un état plus récent).
