# Fiche LOT-UI2-02 — Accueil, Analyse et Téléchargements v2 (Windows)

- Statut : Fait, vérifié dans l'aperçu navigateur ; recette dans l'application Tauri à faire avec la prochaine recette Windows
- Exigences CDC : UX-01 (écrans traduits FR/EN), UX-06 (fonctions non prêtes marquées PRÉVU), DL-02 (reprise annoncée seulement si possible), DL-06 (conversion affichée à part), COM-04 (positions de reprise)
- Maquette : `design/design_handoff_windows_v2` écrans 1, 2 et 3 (états normal, aucun média, onglets Terminés / Échecs)
- Inclus :
  - Accueil : carte de saisie, aides, actions rapides, « Reprendre » (nouveau : liste des médias réellement lus, bornée à 20 identifiants, `mm:recentPlays:v1`), « Récemment téléchargés ».
  - Analyse : en-tête, puces calculées depuis les formats réels, onglets, lignes de format, barre d'action fixe, état « aucun média » avec ouverture dans le navigateur intégré.
  - Téléchargements : trois listes, statuts icône + texte partagés avec Android (`features/downloads/status.ts`), conversion distincte, pause/reprise globale.
  - Réglages : bouton « Ouvrir le dossier » à côté de la destination (la fonction quittait l'Accueil).
- Adaptations documentées : texte discret quand « Reprendre » ou « Récemment téléchargés » est vide (la maquette n'a pas d'état vide) ; Playlist et Plusieurs liens restent PRÉVU ; puce « Reprise possible » non affichée (l'analyse ne le dit pas) ; pas de croix sur une ligne Terminé.
- Dépendances : aucune.
- Tests :
  - `tsc --noEmit`, `eslint .`, `vitest run` : 29 fichiers, 146 tests verts (nouveau `src/test/windows-v2-screens.test.tsx` : Reprendre, PRÉVU, mémorisation des lectures, onglets Terminés / Échecs, conversion étape 2/2).
  - Aperçu navigateur (Edge headless 1440 × 900, backend fictif, FR et EN) : Accueil, Analyse Vidéo / Audio seul, aucun média, Téléchargements En cours / Terminés / Échecs — conforme à la maquette.
  - Non testé : application Tauri réelle (WebView2), analyse d'un vrai lien.
- Retour arrière : revert du commit ; la clé `mm:recentPlays:v1` peut rester.
