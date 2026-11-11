# Fiche LOT-UI2-03 — Historique, Torrents et Réglages v2 (Windows)

- Statut : Fait, vérifié dans l'aperçu navigateur ; recette dans l'application Tauri à faire avec la prochaine recette Windows
- Exigences CDC : COM-13 (historique de lecture distinct), TOR-01..04 (partage visible et arrêtable), UPD-01..07 (mises à jour à la demande, vérifiées), EXT-01, UX-01 (FR/EN), UX-06 (fonctions non prêtes marquées PRÉVU)
- Maquette : `design/design_handoff_windows_v2` écrans 9, 10 et 11 (tous les onglets des Réglages, états de mise à jour)
- Inclus :
  - Historique : Téléchargements / Lectures, groupes par jour traduits, effacement par onglet ; historique de lecture local borné (`mm:playHistory:v1`, 200 entrées) avec position d'arrêt, qui alimente aussi « Reprendre » de l'Accueil (remplace `mm:recentPlays:v1`, jamais publié).
  - Torrents : pastille de session, arrêt global, champ magnet, cartes avec statistiques réelles (reçu, envoyé, pairs, reste ; partage et ratio réels une fois terminé), « Arrêter le partage » = pause, limites réelles.
  - Réglages : nouvelle structure en 9 sections, carte de mise à jour bureau, extension en 3 étapes.
- Contrôles retirés car ils ne faisaient rien : interrupteurs démarrage / zone de notification / presse-papiers / sous-dossier par source / accélération matérielle, sélecteurs qualité / format / limite de vitesse / qualité des miniatures, densité, accent (ils n'étaient pas enregistrés). Les éléments prévus par la maquette sont affichés PRÉVU.
- Adaptations documentées : ratio cible et durée de partage PRÉVU (absents du moteur torrent) ; « Importer dans la bibliothèque » non affiché ; appairage par code remplacé par le parcours réel (identifiant d'extension) ; moteur de lecture affiché « Intégré · WebView2 ».
- Aperçu navigateur : données de torrents fictives `dev/torrentsMock.ts`, en développement seulement (jamais dans l'application ni les tests).
- Tests : `tsc`, `eslint`, `vitest run` (29 fichiers, 151 tests) ; nouveaux tests : historique (onglets, effacement des lectures seulement, position d'arrêt, une entrée par lecture), torrents (partage après la fin, arrêt du partage, objectifs PRÉVU), réglages (pas de faux interrupteur, mises à jour, reprise, langue). Captures FR/EN conformes à la maquette.
- Non testé : application Tauri réelle, session torrent réelle, téléchargement d'une vraie mise à jour.
- Retour arrière : revert des commits `eab8cf7`, `7f2d723` et du commit Réglages.
