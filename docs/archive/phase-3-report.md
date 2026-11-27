# Miarina Media — Rapport Phase 3 (bibliothèque et lecteur)

Date : 2026-10-14 · Statut : **terminée (périmètre bibliothèque + lecteur)** · Environnement : Windows 11 Pro 22000, Rust 1.99.0 (MSVC 14.51), Node 24.21, pnpm 12.11.2, WebView2 155.

## 1. Livré

| Tranche | Contenu |
|---|---|
| `storage` (migration v2) | Table `media` + index plein texte FTS5 (`unicode61`, sans diacritiques) maintenu par triggers ; requêtes paginées (tri date / titre / taille / durée, filtre vidéo / audio) ; statistiques ; recherche utilisateur assainie en termes préfixes ; mise à niveau v1 → v2 testée |
| Crate `library` (nouveau) | Indexation du dossier de téléchargement (bornée), ajout automatique des téléchargements terminés, métadonnées `ffprobe` et miniatures FFmpeg en arrière-plan **bornées par `max_conversions`** et des délais (30 s / 60 s), renommage sans écrasement, suppression, détection des fichiers disparus, cache de miniatures vidable |
| Tauri | Commandes `library_*`, `storage_*`, `downloads_open_folder`, toutes accordées explicitement ; protocole d'asset activé avec un *scope* statique vide, élargi à l'exécution aux seuls dossiers de médias connus ; événement `library://changed` |
| Bibliothèque (UI) | Données réelles, liste virtualisée, recherche, filtres, tri, miniatures ; menu contextuel du design (Play, Show in folder, Copy source link, Rename, Delete file) au clic droit et au clavier (⇧F10, F2, Suppr, Ctrl+E), confirmation de suppression focalisée sur « Keep » |
| Lecteur (UI) | `<video>` / `<audio>` réels via le protocole d'asset (lecture en flux, Range) ; reprise de position ; vitesse, volume, saut ±10 s, image dans l'image, plein écran ; panneau Fichier avec les vraies métadonnées ; « Up next » depuis la bibliothèque ; repli « Open with system player » si le format n'est pas décodable |
| Home / Settings / mobile | Récents et aperçu disque réels ; « Open folder » ; onglet Storage réel (cache, fichiers temporaires orphelins) ; écrans mobiles branchés sur les mêmes stores ; **fin du badge PROTOTYPE** (« PREVIEW » seulement dans l'aperçu navigateur) |

## 2. Vérifications réellement exécutées

| Vérification | Résultat |
|---|---|
| `cargo test --workspace` | ✅ **122 tests** ; 2 tests `#[ignore]` (réseau yt-dlp, FFmpeg réel) exécutés manuellement : ✅ |
| `cargo clippy --workspace --all-targets -D warnings`, `cargo fmt --check` | ✅ |
| `pnpm typecheck`, `pnpm lint`, `pnpm test` (**44 tests**), `prettier --check src` | ✅ |
| App release, pilotée par clics / clavier réels + DevTools WebView2 | ✅ 5 fichiers réels indexés avec durées, qualités, codecs et miniatures FFmpeg ; lecture réelle de Big Buck Bunny 240p (image affichée, temps qui avance, reprise à la position enregistrée) ; menu contextuel au clic droit ; raccourci Ctrl+3 depuis le lecteur |
| Mesures | voir `docs/performance.md` (exe 12,2 Mo ; processus Rust ~29 Mo ; WebView2 ~190–197 Mo privés) |

## 3. Défauts trouvés pendant la vérification et corrigés

1. **Lecture automatique manquée à la première ouverture du lecteur** : React crée l'élément `<video>` pendant le rendu ; avec l'écran chargé à la demande, `loadedmetadata` survenait avant l'attachement du gestionnaire — ni `play()` ni la reprise de position n'avaient lieu. Le démarrage est désormais aussi exécuté si l'élément a déjà ses métadonnées ; test de non-régression ajouté. Diagnostiqué en instrumentant les événements média via le protocole DevTools.
2. Attentes FTS erronées dans les tests (les opérateurs saisis par l'utilisateur sont cherchés comme des mots, ce qui est voulu).
3. Règles React Compiler (« accès aux refs pendant le rendu ») et react-refresh : lecteur et actions réécrits.
4. Liste virtualisée vide sous jsdom : dimensions simulées dans la configuration de test.

## 4. Limites connues / non vérifié

- **Conversions yt-dlp non soumises au sémaphore `max_conversions`** : yt-dlp lance FFmpeg lui-même pour la fusion / l'extraction audio ; seul le nombre de threads FFmpeg est borné. Les miniatures et `ffprobe` de la bibliothèque, eux, sont bornés. Séparer téléchargement et post-traitement est reporté (Phase 5, ou plus tôt si souhaité).
- Sous-titres : bouton désactivé (non implémenté).
- Formats que WebView2 ne décode pas (p. ex. certains MKV / HEVC) : repli sur le lecteur système, pas de transcodage.
- Position de reprise dans `localStorage` (non partagée, peut être perdue).
- Miniatures Sintel gris clair : image réelle (brouillard) à 10 % de la durée, pas un défaut ; le choix de l'image pourrait être affiné.
- Indexation limitée au dossier de téléchargement courant (et aux dossiers choisis ensuite) ; pas de surveillance du système de fichiers en continu (rescan au démarrage et à la demande).
- **Android : rien de cette phase n'a été compilé ni exécuté sur Android.**
- CPU / RAM pendant un téléchargement ou une conversion non mesurés.

## 5. Prochaine étape — à valider

Le cahier des charges Android (`docs/requirements/android-mvp.md`) place le **navigateur intégré** en P0, alors que `CLAUDE.md` le classe « Later ». Avant la Phase 4, décisions nécessaires : priorité du navigateur, navigation mobile, maquettes des écrans navigateur, et spike de faisabilité (Windows : webview secondaire Tauri ; Android : WebView native via plugin Kotlin).
