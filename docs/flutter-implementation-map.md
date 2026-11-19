# Client Flutter — correspondance maquette ↔ code

Maquette : `design/design_handoff_lecture_ecouter/` (direction 3a). Décision : [0007](decisions/0007-flutter-migration.md). Code : `apps/flutter_client/lib/`. Les écrans de l'app Tauri restent décrits dans `design-implementation-map.md`.

État au 2026-11-19 (phase 2, fondations).

## Fondations

| Élément du handoff | Code | État |
|---|---|---|
| Tokens couleur sombre / clair (README, `theme.css`) | `design/tokens.dart` (`MmColors`) | fait ; le clair n'est pas encore sélectionnable (réglage W-S1) |
| Typographie Manrope / JetBrains Mono tabulaire | `design/tokens.dart` (`MmType`), `assets/fonts/` | fait ; graisses par axe variable |
| Rayons, ombres, halo lire | `MmRadius`, `MmShadows` | fait |
| Mouvement (§03) : 160 / 180 / 220 / 240 / 320 ms, courbes, mouvement réduit → fondu 120 ms | `MmMotion`, transitions dans `app/router.dart` | fait pour écran, favori, lecture/pause, survol, pastilles ; ouverture du lecteur (320 ms) avec l'écran En lecture |
| Icônes | `design/mm_icons.g.dart` (généré par `tool/gen_icons.dart`), `design/widgets/mm_icon.dart` | **écart validé** : Phosphor au lieu de Material Symbols (décision 0007, `docs/icon-system.md`) |
| Focus clavier : contour 2 px teal décalé 2 px ; cibles ≥ 32 px | `design/widgets/pressable.dart` | fait |
| Progression interpolée (§03) | `InterpolatedPosition` (`design/widgets/track_bar.dart`) | fait : au plus 500 ms d'avance sur le moteur |
| i18n FR (référence) + EN | `lib/l10n/*.arb` | fait pour les textes existants |

## Shell

| ID | Écran / zone | Code | État et écarts |
|---|---|---|---|
| — | Barre de titre Windows 40 px, recherche, boutons fenêtre | `features/shell/title_bar.dart` | fait ; la recherche (W-02) est affichée **inerte** avec infobulle « Bientôt disponible » ; la zone utile fait 1280 × 800 au lancement (bordures invisibles de Windows ajoutées) |
| — | Barre latérale Écouter 232 / 64 px, sélecteur Obtenir · Écouter | `features/shell/sidebar.dart` | fait ; seuil de repli : zone utile < 1280 px ; seul « Titres » affiche un compteur (le seul que le cœur donne aujourd'hui) |
| — | Barre de lecture 80 px, grille 320 / 1fr / 320 | `features/shell/playback_bar.dart` | fait : pochette, titre, transport (aléatoire, précédent, lire, suivant, répéter non → tout → ce titre), position, volume et coupure ; **Paroles, File, Mini-lecteur affichés inertes** jusqu'au lot En lecture ; le cœur de la barre n'est pas encore affiché |
| A-00… | Onglets Android Musique · Cinéma · Focus (corail) · Obtenir (teal), mini-lecteur 64 dp | `features/shell/mobile_shell.dart` | fait ; **écart temporaire** : l'onglet Musique ouvre Titres tant que A-00 n'est pas construit ; le mini-lecteur n'ouvre pas encore le lecteur complet (A-03) |

## Écrans

| ID | Écran | Code | État |
|---|---|---|---|
| W-M1c / A-01 | Titres | `features/library/tracks_screen.dart` | fait : table virtualisée par pages de 200 (Windows), lignes 60 dp (Android), filtre plein texte (Windows), puces Tous / Favoris, favori réel, introuvable atténué ; double-clic ou Entrée lit (Windows), toucher lit (Android). Puces « Jamais écoutés », « Hi-res », « Introuvables », « Ajoutés ce mois », tri par colonne, sélection multiple, « Localiser », menu ⋮ et index alphabétique : **non affichés** tant que non construits |
| W-00, W-M1a/b, W-M2a/b, W-M3, W-M4, W-M5, W-02, W-C1–4, W-F1/F2, W-03, W-O1/O2, W-S1–3, W-E1–3, A-00, A-01b…A-08 | autres écrans | `features/common/coming_soon.dart` | écran « Cet écran arrive bientôt » avec l'ID ; rien de simulé |
| Obtenir | accueil lien, analyse, téléchargements, navigateur, torrents | — | à porter à l'identique de l'app Tauri (pas de nouvelle maquette) |

## Données

- Bibliothèque : `features/library/library_data.dart` (`LibraryApi`) → pont Rust `rust/src/api/library.rs` → `crates/storage` (même base et mêmes migrations que la 0.1.x).
- En développement, `--dart-define=MM_DATA_DIR=<dossier>` pointe vers un dossier de travail ou une **copie** d'un dossier de données 0.1.x ; la base de l'app Tauri en service n'est jamais ouverte tant que les deux apps coexistent.
- Android : la base est vide ; les titres du téléphone (MediaStore, comme `DeviceMediaPlugin` de l'app Tauri) arrivent dans un lot suivant.

## Vérifications

- `flutter analyze` : aucun problème. `flutter test` : 18 tests (contrat moteur, file de lecture, shell Windows et Android, table, favori, repli de la barre latérale).
- Capture réelle Windows (release, copie de la bibliothèque) à 1280 × 800 : barre latérale, table, lecture en cours ; comparée à W-M1c.
- Capture réelle Android (émulateur, debug) : onglets, état vide, mini-lecteur en lecture.
