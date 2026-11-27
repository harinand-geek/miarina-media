# Miarina Media — Rapport Phase 0 (audit et planification)

Date : 2026-10-13 · Statut : **architecture validée le 2026-10-13** (réponses par défaut en §5bis) · Aucun code applicatif écrit.

Documents liés : [architecture.md](architecture.md) · [design-system.md](design-system.md) · [design-implementation-map.md](design-implementation-map.md) · [android-feasibility.md](android-feasibility.md)

## 1. Ce qui a été audité

- `CLAUDE.md` (règles projet).
- Handoff `design/` : Design System v1.0, prototype interactif Windows (1440×900 / 1280×800, 8 écrans dont Browser « PLANNED »), prototype Android (360/390/412 dp, 4 onglets + sheets + lecteur + 4 concepts de notification), `support.js` (runtime des prototypes, non réutilisé), une capture de palette.
- Poste de développement (constaté, pas supposé) :

| Outil | État | Requis pour |
|---|---|---|
| Node.js | ✅ v24.21.0 | front |
| npm | ✅ 11.19.0 | |
| pnpm | ❌ absent (activable via corepack) | workspaces |
| Git | ✅ 2.55 | |
| **Rust (rustup, cargo)** | ❌ **absent** | **bloquant Phase 1** |
| **MSVC Build Tools (C++)** | ❌ **non détecté** (pas de Visual Studio Installer) | **bloquant Phase 1** (Tauri sur Windows) |
| WebView2 Runtime | ⚠️ entrée registre machine trouvée en v90 (ancienne) ; Windows 11 l'inclut normalement à jour — à revérifier | exécution |
| JDK | ✅ Temurin 17.0.20 | Android |
| Android SDK | ✅ platforms 35/36/37, build-tools 34–36, cmdline-tools | Phase 4 |
| Android NDK | ✅ 26.1, 27.0, 27.1 | Phase 4 |
| `ANDROID_HOME` / `NDK_HOME` | ❌ non définies | Phase 4 |
| yt-dlp / FFmpeg | ❌ absents (normal : seront gérés par l'app) | Phase 2 |
| Python | ❌ non utilisable (alias Microsoft Store) | non requis |

## 2. Les cinq risques techniques majeurs

### R1 — Extraction média sur Android · **Critique**
yt-dlp est en Python ; aucun binaire Windows ne fonctionne sur Android. Les solutions réalistes (youtubedl-android — GPL-3.0 — ou Python embarqué via Chaquopy) ajoutent plusieurs dizaines de Mo par ABI, et la mise à jour des extracteurs (indispensable : les sites changent souvent) entre en conflit avec la politique Google Play sur le code téléchargé.
**Atténuation** : moteur HTTP direct partagé d'abord ; spike mesuré A/B (cf. android-feasibility §8) ; décision de distribution (Q4) avant d'investir.

### R2 — Packaging et licence de FFmpeg · **Élevé**
Un FFmpeg complet pèse ~80–130 Mo sous Windows ; les builds « GPL » imposent la GPL à la distribution qui les embarque ; les builds LGPL excluent certains encodeurs (ex. libx264, mais pas nécessaires ici : on remuxe et on encode MP3 via libmp3lame — LGPL — et FLAC natif). `ffmpeg-kit` (Android) est archivé.
**Atténuation** : FFmpeg lancé comme **processus séparé** (pas de liaison) ; build LGPL minimale (muxers MP4/WebM/M4A/MP3/FLAC, décodeurs/encodeurs audio nécessaires) ; **téléchargement à la demande** avec SHA-256 épinglé plutôt qu'embarqué (décision D3) ; écran « Licences » et offre de sources ; Android : `MediaMuxer` natif pour le remux.

### R3 — Navigateur intégré · **Élevé (mais hors MVP)**
Le multi-webview de Tauri 2 est encore derrière la feature `unstable` et n'est pas disponible sur mobile ; détecter les médias impose d'intercepter les requêtes réseau (WebView2 `WebResourceRequested`, Android `shouldInterceptRequest`) ; charger des sites arbitraires dans l'app exige une isolation stricte (aucune capability IPC sur la webview distante). Le design l'a déjà marqué **PLANNED**.
**Atténuation** : MVP = coller / partager / glisser un lien (déjà au design) ; spike séparé post-MVP ; alternative légère : extension navigateur ou « Partager vers Miarina Media » (déjà prévu sur Android).

### R4 — Taille de l'application · **Moyen à élevé**
Base Tauri ≈ quelques Mo, mais yt-dlp.exe (PyInstaller, ~15–20 Mo) + FFmpeg (jusqu'à >100 Mo) + polices + sur Android Python/yt-dlp/FFmpeg × ABI.
**Atténuation** : composants téléchargés à la demande sur Windows ; AAB / APK par ABI sur Android ; sous-ensemble Material Symbols ; mesures réelles de taille à chaque phase (pas d'objectif chiffré inventé).

### R5 — Téléchargements en arrière-plan et cycle de vie · **Élevé**
Android : quotas des foreground services (`dataSync` limité à 6 h/24 h sur Android 15), user-initiated jobs seulement sur API 34+, runtime Tauri lié à l'Activity. Windows : poursuite fenêtre fermée (tray), arrêt propre des processus enfants (Job Objects), reprise après crash/arrêt brutal.
**Atténuation** : machine à états persistée + récupération au démarrage (Phase 2) ; Job Objects ; spike Android dédié avec destruction forcée de l'Activity (Phase 4.0).

### Autres risques notables

| # | Risque | Niveau | Atténuation |
|---|---|---|---|
| R6 | **Légal / CGU** des plateformes (YouTube interdit le téléchargement hors fonctions officielles) ; rejet Play Store probable | Élevé (business) | pas de contournement DRM/auth ; avertissement déjà au design (« Only download media you own or have permission to save ») ; distribution hors Play à décider |
| R7 | Faux positifs antivirus / SmartScreen sur yt-dlp.exe et l'installeur non signé | Moyen | **signature de code** (certificat OV/EV) avant release ; binaires officiels vérifiés par hash |
| R8 | Casse fréquente des extracteurs yt-dlp | Moyen | mise à jour de yt-dlp gérée (Windows) avec vérification et retour arrière |
| R9 | Codecs non lisibles par WebView2 (HEVC, MKV) | Moyen | préférence MP4/H.264 à l'analyse, « Ouvrir avec le lecteur système » |
| R10 | Outillage très récent (TypeScript 7, Vite 8, Tailwind 4) vs exemples Tailwind v3 du handoff | Faible | transcription des tokens ; repli TS 5.x/6.x si l'outillage n'est pas prêt |
| R11 | Écart design ↔ cahier des charges (modes Eco/Balanced/Performance, Playlist/Batch, Report link, light theme non maquetté) | Moyen | questions Q1–Q3 ci-dessous |

## 3. Plan de développement

Chaque phase : annonce du périmètre → implémentation par tranches → lint/typecheck/tests/build réellement exécutés → rapport (réussites, échecs, limites) → mise à jour de la doc.

### Phase 1 — Fondations (Windows d'abord)
**Prérequis** : Rust stable + MSVC Build Tools installés ; pnpm via corepack.
**Contenu** : monorepo (pnpm + workspace Cargo), app Tauri 2 + React/TS/Vite/Tailwind 4, tokens du design system, polices embarquées, composants de base, coquille Windows (titlebar, sidebar, raccourcis) et coquille mobile (bottom nav, sheets), les 7 écrans + Browser PLANNED avec **fixtures de développement**, thèmes dark/light, crates vides mais testées (`media-core` : machine à états + validation chemins/URL).
**Critères d'acceptation** :
- `pnpm tauri dev` lance l'app sous Windows ; navigation Ctrl+1…7, Ctrl B, Esc fonctionnelles.
- Comparaison visuelle des écrans à 1440×900 et 1280×800 vs prototype ; écarts documentés.
- Rendu mobile vérifié en navigateur à 360/412 px (build Android réel en Phase 4).
- Tout contrôle sans backend est visiblement marqué indisponible (pas de faux bouton).
- `cargo test`, `cargo clippy -D warnings`, `cargo fmt --check`, `tsc`, `eslint`, `vitest` passent.

### Phase 2 — Vertical slice Windows
URL → analyse (yt-dlp) → choix du format → téléchargement → fichier final ; `HttpEngine` ; file persistante SQLite + migrations ; concurrence, pause/reprise honnêtes, annulation (Job Objects), retry borné, disque plein, hors ligne, conflits de noms, historique, récupération après crash ; événements typés throttlés ; gestion des composants yt-dlp/FFmpeg (décision D3).
**Acceptation** : téléchargement réel d'un média autorisé de bout en bout ; tests de la machine à états, des migrations, de l'annulation, des erreurs réseau simulées, des URLs non supportées et du redémarrage ; fixtures retirées des flux de production.

### Phase 3 — Bibliothèque, lecture, conversion
Bibliothèque SQLite + FTS + miniatures, listes virtualisées, lecteur `<video>` via protocole d'asset, conversions audio bornées (MP3/M4A/FLAC), fusion DASH, vérification d'existence des fichiers, menus contextuels (Show in folder, Rename, Delete).
**Acceptation** : bibliothèque de 5 000 entrées fluide (mesurée), lecture des formats recommandés, conversion annulable, documentation des différences de codecs.

### Phase 4 — Android
4.0 spike de faisabilité (protocole dans android-feasibility.md) → rapport et go/no-go → 4.1 implémentation du périmètre validé : coquille mobile, `HttpEngine`, plugin Kotlin (job/service, notifications, MediaStore/SAF, Media3), extracteur retenu.
**Acceptation** : build APK/AAB réel, tests sur appareils physiques (API 34+ et < 34), téléchargement qui survit à la fermeture de l'app, taille mesurée.

### Phase 5 — Optimisation et durcissement
Profilage (démarrage à froid, RAM au repos/en téléchargement, CPU conversion, taille des paquets) sur machines/appareils représentatifs → `docs/performance.md` ; correction des goulets mesurés ; accessibilité (clavier, lecteurs d'écran, 200 %) ; revue sécurité des capabilities.

### Phase 6 — Release
Installeur Windows (NSIS/MSI) signé, APK/AAB signés, versionnage, mise à jour applicative, écran licences et notices tierces, documentation utilisateur, check-list de release.

## 4. Décisions proposées (à valider)

| ID | Décision proposée |
|---|---|
| D1 | Monorepo pnpm + workspace Cargo ; `packages/ui` différé ; `plugins/android-download` créé en Phase 4 |
| D2 | SQLite via `rusqlite` côté Rust uniquement (pas de `tauri-plugin-sql`) ; types TS générés par `ts-rs` |
| D3 | Windows : yt-dlp et FFmpeg **téléchargés au premier besoin** (consentement + SHA-256 épinglé + mise à jour gérée) plutôt qu'embarqués dans l'installeur — installeur léger, mises à jour yt-dlp indépendantes. Alternative : embarquer yt-dlp seul. |
| D4 | Moteur `HttpEngine` Rust partagé Windows/Android en plus de yt-dlp |
| D5 | Lecture : WebView2 `<video>` sur Windows ; Media3 natif sur Android |
| D6 | Android : spike avant tout engagement ; distribution hors Play Store envisagée |
| D7 | Domaine produit : `media.miarina.org` (le design indique `play.miarina.org`) |

## 5. Questions ouvertes pour validation

- **Q1 — Modes de ressources** : le design n'a qu'un toggle « Low-resource mode ». J'implémente un sélecteur **Eco / Balanced / Performance** (segmented dans Settings › Performance, style du design) en remplacement du toggle ? Ou faut-il une maquette Claude Design d'abord ?
- **Q2 — Playlist et Batch links** (actions rapides du design, hors MVP selon `CLAUDE.md`) : afficher avec badge **PLANNED** ou masquer au MVP ?
- **Q3 — « Report link »** : sans backend, je propose de l'ouvrir vers une page de contact/issue dans le navigateur, ou de le retirer. Lequel ?
- **Q4 — Distribution Android** : Play Store (périmètre d'extraction très réduit) ou APK direct / F-Droid (périmètre complet, licence GPL si youtubedl-android) ?
- **Q5 — D3** : composants yt-dlp/FFmpeg téléchargés à la demande, ou embarqués dans l'installeur ?
- **Q6 — Langues du MVP** : anglais seul avec infrastructure i18n, ou anglais + français (+ malgache) dès le MVP ? Qui fournit les traductions ?
- **Q7 — ABI Android** : `arm64-v8a` seul, ou aussi `armeabi-v7a` pour les appareils d'entrée de gamme ?
- **Q8 — Domaine** : confirmer `media.miarina.org`.

## 5bis. Réponses retenues (défauts validés avec l'architecture, révisables)

| Question | Décision retenue | Phase concernée |
|---|---|---|
| Q1 | Sélecteur segmenté **Eco / Balanced / Performance** dans Settings › Performance (Windows) et App (Android), remplaçant le toggle « Low-resource mode » ; style du composant Segmented du design | 1 |
| Q2 | Playlist et Batch links **affichés avec badge PLANNED** (même traitement que Browser) | 1 |
| Q3 | « Report link » **masqué au MVP** (aucune URL de contact existante) | 1 |
| Q4 | Reporté à la fin du spike Android (Phase 4.0) | 4 |
| Q5 | yt-dlp et FFmpeg **téléchargés au premier besoin** (consentement + SHA-256 épinglé) — D3. **Révisé le 2026-10-17 : inclus dans l'installeur Windows (décision 0002)** | 2 |
| Q6 | **Anglais uniquement** au MVP, avec infrastructure i18n prête pour fr / mg / es / pt | 1 |
| Q7 | Reporté au spike Android (mesure de taille par ABI) | 4 |
| Q8 | Domaine **media.miarina.org** | 1 |

## 6. Prochaine étape

Après validation de l'architecture et réponses à Q1–Q8 : installation de Rust + MSVC Build Tools (action de ta part, ou je te guide), puis démarrage de la **Phase 1**.
