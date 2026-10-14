# Miarina Media — Rapport Phase 1 (fondations et écrans)

Date : 2026-10-14 · Statut : **terminée, en attente de revue** · Environnement : Windows 11 Pro 22000, Rust 1.99.0 (MSVC 14.51, SDK 10.0.26100), Node 24.21, pnpm 12.11.2, WebView2 155.0.4283.45.

## 1. Livré

| Élément | Emplacement |
|---|---|
| Monorepo pnpm + workspace Cargo (edition 2024) | `package.json`, `pnpm-workspace.yaml`, `Cargo.toml` |
| Crate `media-core` : machine à états des tâches, assainissement des noms de fichiers, garde anti-traversée, validation d'URL | `crates/media-core/` |
| App Tauri 2 : fenêtre sans décoration 1280×800 (min 960×640), CSP stricte, capabilities minimales (aucun accès fs/shell côté front), commande `validate_media_url` (règles Rust réelles) | `apps/client/src-tauri/` |
| Tokens du design system transcrits pour Tailwind 4 (dark + light), polices locales (Manrope, JetBrains Mono, Material Symbols Rounded) | `apps/client/src/styles/` |
| Composants : Button, IconButton, ProgressBar (4 variantes), Tabs, Segmented, Chip, Toggle, Stepper, RadioDot, Menu, ConfirmDialog, BottomSheet, Toasts, Skeleton (délai 200 ms), EmptyState, PlannedBadge, Kbd, Thumbnail, VirtualGrid | `apps/client/src/components/` |
| Coquille Windows : barre de titre custom, sidebar 232↔64 (repli auto < 1280 px), carte de progression globale, raccourcis Ctrl+1…7 / Ctrl+B / Ctrl+K / Ctrl+P / Ctrl+V | `apps/client/src/app/` |
| Coquille Android : bottom nav 4 onglets, analyse et stockage en bottom sheets, lecteur plein écran | `apps/client/src/app/MobileShell.tsx` |
| Écrans Windows : Home, Analyse, Downloads (file réordonnable souris + clavier), Library (grille/liste virtualisées, recherche, tri, filtres), Player, History, Settings (6 onglets), Browser (PLANNED) | `apps/client/src/features/` |
| Écrans Android : Home, Downloads (Active/Queue/Done), Library, Settings, feuilles d'analyse et de stockage, lecteur | `apps/client/src/features/*/Mobile*.tsx` |
| Décisions Q1–Q3, Q6, Q8 appliquées : sélecteur Eco/Balanced/Performance, Playlist/Batch en PLANNED, « Report link » masqué, anglais seul, media.miarina.org | — |

## 2. Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| `cargo test --workspace` | ✅ 30 tests passés (machine à états, noms de fichiers, chemins, URLs) |
| `cargo clippy --workspace --all-targets -- -D warnings` | ✅ 0 avertissement |
| `cargo fmt --all --check` | ✅ |
| `pnpm typecheck` (TypeScript 6.0.3 strict, `noUncheckedIndexedAccess`) | ✅ 0 erreur |
| `pnpm lint` (ESLint 10 + typescript-eslint + react-hooks 7) | ✅ 0 erreur, 0 avertissement (2 incompatibilités TanStack Virtual / React Compiler annotées) |
| `pnpm test` (Vitest 5, jsdom) | ✅ 27 tests passés : navigation, raccourcis, erreur de lien, analyse → formats → téléchargement, « No downloadable media found », dialogue d'annulation (focus sur Keep, Esc), accessibilité de la progression, modes de ressources, coquille Android sans sidebar, analyse en bottom sheet, simulation de file |
| `prettier --check` | ✅ |
| `pnpm tauri build --no-bundle` (release) | ✅ `target/release/miarina-media.exe`, **8,8 Mo** (dont 5,4 Mo de police d'icônes) |
| Lancement réel de l'exécutable release + captures d'écran | ✅ Home, Downloads, Library, Player, History, Settings en dark ; Home, Downloads, Player, Settings en light. Mémoire de travail observée ≈ 27–28 Mo au repos (lecture ponctuelle du Gestionnaire de processus, **pas un benchmark**) |

Corrections faites suite à la vérification visuelle : badge PROTOTYPE masqué en build release (corrigé : visible tant que les fixtures sont utilisées), titre sur deux lignes, barre de défilement claire, logo non inversé en thème clair, piste de lecture claire en thème clair, libellé de vitesse « 1.× ».

## 3. Non vérifié / limites connues

- **Android : aucune build ni exécution.** La coquille mobile est couverte par les tests de composants uniquement ; le rendu visuel à 360/412 dp n'a pas été comparé aux maquettes (prévu avec la toolchain Android en Phase 4).
- **Données fictives** : toutes les listes, l'analyse et la progression proviennent de `src/dev/fixtures.ts` et d'un simulateur. Le badge **PROTOTYPE** l'indique dans la barre de titre. Seule la validation d'URL est réelle (Rust).
- Actions nécessitant le backend natif (choisir un dossier, ouvrir le dossier, vider le cache, supprimer les fichiers temporaires, PiP) : **explicitement signalées comme indisponibles** par un toast, pas simulées.
- Réglages : thème, réduction des animations, mode de ressources et nombre de téléchargements simultanés ont un effet réel sur l'UI et le simulateur ; les autres réglages ne sont **ni persistés ni appliqués** (Phase 2).
- Lecteur : horloge simulée, pas de `<video>` (Phase 3).
- Valeurs « derived » du thème clair (couleurs utilisées par les prototypes mais absentes du design system) : adaptations à faire valider par le design.
- Police Material Symbols complète (5,4 Mo) : sous-ensemble à produire en Phase 5.
- i18n : chaînes en anglais dans le code ; l'infrastructure de traduction sera ajoutée avant d'introduire une 2e langue.
- Installeur NSIS non généré (`--no-bundle`), aucune signature de code.
- pnpm est appelé via un shim corepack installé dans `%APPDATA%\npm`.

## 4. Écarts documentés par rapport au design

| Écart | Raison |
|---|---|
| Badge « PROTOTYPE » dans la barre de titre | Honnêteté sur les données fictives ; disparaît en Phase 2 |
| Sélecteur Eco / Balanced / Performance à la place du toggle « Low-resource mode » | Q1 + cahier des charges |
| « Report link » absent | Q3 (pas de backend) |
| Density « Compact » affiché PLANNED | non maquetté |
| Langues autres que l'anglais désactivées | Q6 |
| Menu de tri, menu « More » (History), sélecteurs natifs des Settings | options non maquettées ; styles du composant Menu du design system |
| État vide du lecteur (« Nothing is playing ») et bouton de tiroir < 1280 px | non maquettés |
| Barres de défilement fines aux couleurs du thème | non spécifiées |
| Bottom sheet Android : « Waiting for a free slot » dans l'onglet Queue | repris du prototype |

## 5. Prochaine étape : Phase 2 (vertical slice Windows)

Moteur `HttpEngine` + `YtDlpEngine`, crates `download-engine`, `storage` (SQLite + migrations) et `resource-manager`, file persistante, événements typés throttlés, gestion des composants yt-dlp/FFmpeg téléchargés à la demande (D3), remplacement des fixtures par les commandes Tauri. Les décisions Q4/Q7 restent attendues pour la Phase 4.
