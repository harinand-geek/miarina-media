# Fiche LOT-L04 — Prototype libVLC (WIN-SPIKE)

- Statut : prototype terminé ; décision `docs/decisions/0005-windows-player-engine.md` **proposée**, à accepter par le propriétaire avant L05
- Exigences CDC : § 6 « Prototype obligatoire WIN-SPIKE », DEP-03 (licences des modules libVLC)
- Livré :
  - `apps/client/src-tauri/src/spike_libvlc.rs` : prototype compilé seulement avec `--features libvlc-spike` et lancé seulement si `MIARINA_LIBVLC_SPIKE` désigne un dossier libVLC ; libVLC chargé dynamiquement (aucune bibliothèque liée, aucune dépendance Rust ajoutée ; la fonctionnalité active seulement des modules de la crate `windows` déjà présente) ; fenêtre vidéo enfant, scénario de mesures, résultats en JSON.
  - Décision 0005 : comparaison WebView2 / libVLC sur un corpus de 8 fichiers + sous-titres externes, intégration (fenêtres, redimensionnement, ordre d'empilement, superposition HTML, mémoire, temps), tailles complète et réduite, licences à inventorier, proposition et conditions de L05.
- Constats principaux : libVLC lit ce que WebView2 ne lit pas (HEVC, AVI, pistes audio multiples, sous-titres intégrés et SRT externes) ; pas de fenêtre orpheline ; démarrage 30–120 ms avec cache des modules valide ; ensemble réduit 35 Mo compressés ; une vue web enfant transparente ne laisse pas voir la vidéo (commandes HTML hors image ou fenêtre transparente possédée) ; 4K 60 Mbit/s figée dans la fenêtre enfant (à résoudre en L05).
- Vérifications : `cargo check` et `clippy` avec et sans la fonctionnalité ; build release de recette avec la fonctionnalité ; 5 passages du scénario (runtime complet et réduit, décodage matériel et logiciel) ; corpus lu en parallèle dans Chromium (Edge 157 sans interface).
- Non vérifié : rendu de la fenêtre transparente possédée au-dessus de la vidéo (à regarder à l'œil : lancer la build de recette avec la fonctionnalité et les variables d'environnement de la fiche, la bande orange doit laisser voir l'image autour) ; machine sans VLC installé (le prototype charge un dossier copié, mais VLC est installé sur la machine de mesure) ; DPI ≠ 100 %, multi-écrans.
- Incident de recette : une capture d'écran destinée à la fenêtre de recette a pris l'écran réel de l'utilisateur ; fichier supprimé aussitôt, captures de l'écran réel abandonnées (seule la fenêtre de l'application est capturée).
- Relancer le prototype :
  ```
  npx tauri build --no-bundle --features libvlc-spike --config '{"identifier":"org.miarina.media.recette"}'
  MIARINA_LIBVLC_SPIKE=<dossier contenant libvlc.dll, libvlccore.dll, plugins\>
  MIARINA_SPIKE_CORPUS=<dossier de médias>  MIARINA_SPIKE_OUT=<fichier.json>  MIARINA_SPIKE_HW=any|none
  ```
