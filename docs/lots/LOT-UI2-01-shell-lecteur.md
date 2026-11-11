# Fiche LOT-UI2-01 — Shell Windows v2, contrat lecteur et mini-lecteur

- Statut : Recetté sur Windows (2026-11-11) — DPI 150/200 % et deux écrans restent à vérifier
- Exigences CDC : COM-01, COM-02, COM-03, COM-04 (positions existantes), COM-05, COM-12, AND-09/AND-11 côté Windows (vitesse, minuteur), UX-01 (partiel), UX-06, WIN-02 (messages d'erreur conservés), WIN-11 (Espace, ←/→, F, Échap)
- Version de départ / commit : 0.1.7, `9215a34`
- Objectif utilisateur : écouter et regarder sans que la lecture s'arrête en changeant d'écran ; retrouver la file, la vitesse et le minuteur ; naviguer en deux espaces Obtenir / Écouter.
- Inclus :
  - Tokens corail et logo 4d (handoff `design/design_handoff_windows_v2`).
  - Barre de titre, bandeau hors ligne, sidebar navigation B.
  - Store `player` (contrat COM-01) : états idle/loading/ready/playing/paused/buffering/ended/error, instance anti-réponse obsolète, file bornée à 500, lire ensuite / ajouter / réordonner / retirer / vider, aléatoire réversible, répétition off/file/titre, vitesse 0,5–2×, volume/muet, minuteur (minutes / fin du titre), persistance locale sans reprise sonore au démarrage.
  - `PlayerHost` : un seul élément média pour l'application, placé au-dessus de la surface de l'écran vidéo.
  - Mini-lecteur, écran « En lecture » (File / Son), lecteur vidéo restylé.
  - Bibliothèque : Titres (audio) et Vidéos (vidéo) ; la liste visible devient la file.
  - Catalogue FR/EN et choix de langue.
- Exclus : albums/artistes/dossiers/playlists/favoris (L06), éditeur de tags, Retirer vs Supprimer (COM-10), égaliseur (L05/L07), pistes et sous-titres (WIN-05/06 après WIN-SPIKE), A–B/ratio/fenêtre compacte (L08), refonte Accueil/Analyse/Téléchargements/Torrents/Historique/Réglages, Android.
- Dépendances : aucune nouvelle dépendance npm ou Rust.
- Décision technique / maquette : moteur WebView conservé (le choix libVLC reste conditionné à WIN-SPIKE, CDC §6). L'élément média vit dans le shell et est positionné au-dessus de la surface vidéo (même principe que la surface native Android). Persistance de la file en localStorage, comme les positions de reprise existantes ; migration SQLite = moitié données de L02.
- Risques et données concernées : clé `mm:player:v1` (file, modes, vitesse, volume) et `mm:lang` en localStorage ; aucune migration SQLite ; aucune donnée existante modifiée.
- Travail :
  - [x] Diagnostic
  - [x] Implémentation
  - [x] Tests automatisés pertinents
  - [x] Recette native (application Tauri sur Windows, vrais fichiers) — voir « Recette native » ci-dessous
  - [x] Documentation (`design-system.md` §15, `design-implementation-map.md`)
- Tests (appareil, OS, build, fichier, résultat) :
  - `tsc --noEmit`, `eslint .`, `vitest run` (Windows 11 Pro, Node, jsdom) : 19 fichiers, 97 tests, tous verts (3 exécutions complètes consécutives).
  - `vite build` : OK.
  - Aperçu navigateur (backend fictif, Edge headless 1440 × 900, FR et EN) : Titres, En lecture, Son, Accueil avec mini-lecteur, Vidéos, lecteur vidéo ; rectangle de l'élément média = rectangle de la surface (908 × 765).
  - Non testé : DPI 150/200 %, deux écrans.
- Critères de réception satisfaits : changement d'écran sans recréer le média (test `keeps one playback across screens`), file distincte vidée sans suppression, réponses obsolètes ignorées, répétition/aléatoire testés, minuteur testé.
- Recette native (2026-11-11) — Windows 11 Pro, écran 1920 × 1080 à 100 %, build release `tauri build --no-bundle` avec identifiant isolé `org.miarina.media.recette` (base, réglages et WebView2 séparés de l'appli installée), pilotage par CDP WebView2, fichiers de test générés (3 MP3 tagués, FLAC, M4A, WAV, WebM VP9/Opus) + 8 vidéos MP4/H.264 1080p et 3 MP3 réels en lecture seule.
  | Vérification | Résultat |
  |---|---|
  | Lecture réelle MP3, FLAC, M4A, WAV, WebM VP9, MP4 H.264 1080p | OK |
  | Changement d'écran pendant la lecture (Albums, Artistes, Dossiers, Vidéos, Accueil, Réglages) | OK : même élément média, aucune coupure |
  | Naviguer sans lancer de lecture ne modifie pas la file | OK |
  | Enchaînement automatique, Suivant / Précédent | OK |
  | Espace (partout), ←/→ ±10 s (écrans lecteur), F plein écran natif, Échap | OK |
  | File : aléatoire puis retour à l'ordre d'origine, répétition off / file / titre | OK |
  | Vitesse 1,5× appliquée au média ; minuteur « fin du titre » : pause en fin de titre sans passer au suivant | OK |
  | Image dans l'image, y compris en changeant d'écran | OK |
  | Redémarrage : file et position restaurées, en pause, aucun son au lancement (40 s d'observation) | OK |
  | Remarques (non bloquantes) : « Précédent » reprend un titre à sa position enregistrée plutôt qu'au début ; la file affiche « À suivre » pour toute la file, titres déjà lus compris. | À trancher |
- Défauts / limites restantes : écrans non migrés restent en anglais quand le français est choisi ; la ligne « artiste » montre le site ou le dossier ; la file n'est pas encore en SQLite ; égaliseur absent.
- Retour arrière / récupération : revert du commit ; supprimer `mm:player:v1` et `mm:lang` remet l'état d'origine.
- Commit et preuves : voir historique git.
- Publication : non prévue.
- Prochaine petite étape : recette Tauri Windows de ce lot, puis L06 (tags/métadonnées, table Titres v2, playlists et favoris en SQLite, Retirer vs Supprimer).
