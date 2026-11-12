# Fiche LOT-L02 (données) — File de lecture, positions et historique en SQLite

- Statut : Fait sur Windows (recette native) ; Android à vérifier sur appareil
- Exigences CDC : L02 « données et anciens parcours préservés », COM-03 (file), COM-04 (reprise par média), COM-13 (historique de lecture), T-04 (mort du processus / redémarrage : état durable, aucune corruption)
- Problème : file, positions de reprise, historique de lecture et préférences de lecture ne vivaient que dans le stockage local de la WebView. Sur l'émulateur Android, ce stockage a perdu des données après un arrêt forcé (journal LevelDB endommagé, voir LOT-L03).
- Choix : le stockage local reste une copie synchrone (tout le code existant la lit sans changement) ; chaque écriture des clés concernées part aussi, regroupée toutes les secondes, dans SQLite ; au lancement, avant que les écrans ne lisent quoi que ce soit, SQLite réécrit la copie locale. Premier lancement : la copie locale existante est importée. Si SQLite ne répond pas sous 1,5 s, la copie locale est utilisée et rien n'est perdu.
- Inclus :
  - Migration SQLite v6 : table `playback_state (key, value, updated_at)` ; clés autorisées seulement (`mm:position:<id>`, `mm:player:v1`, `mm:mobile:session:v1`, `mm:playHistory:v1`, `mm:lang`, `mm:resume`, `mm:mobile:rate`, `meta:imported`) ; valeur ≤ 1 Mio, 50 000 lignes au plus, écritures par lot dans une transaction (tout ou rien).
  - Retirer ou supprimer un média efface aussi sa position de reprise.
  - Commandes Tauri `playback_load` et `playback_write` (2 000 changements au plus par appel) + permissions.
  - `services/durableState.ts` : hydratation au démarrage (`main.tsx` charge l'application ensuite), écritures regroupées, nouvelle tentative après échec, envoi immédiat quand la fenêtre se masque ou se ferme.
- Tests :
  - `cargo test -p storage` : 33 tests (nouveaux : v5 → v6 sans perte, écriture atomique et relecture après réouverture, clés et tailles bornées, position oubliée au retrait).
  - `vitest` : 30 fichiers, 156 tests (nouveaux : import au premier lancement, restauration depuis SQLite, regroupement et nouvelle tentative, repli si SQLite ne répond pas) ; `tsc`, `eslint`, `vite build`.
  - Recette native Windows (build release isolé `org.miarina.media.recette`) : migration v5 → v6 ; import de 8 positions et de la file au premier lancement ; écriture en base en moins d'une seconde pendant la lecture ; dossier « Local Storage » de la WebView supprimé puis relance : file, position (0:20, en pause, sans son), « Reprendre », historique et langue française restaurés.
- Non testé : Android sur appareil (la session Android `mm:mobile:session:v1` utilise le même mécanisme), arrêt brutal pendant une écriture SQLite.
- Hors périmètre : réécriture du modèle de lecture en tables relationnelles (les valeurs restent les JSON existants, bornés) ; thème et réglages de la barre latérale restent locaux.
- Retour arrière : revert du commit ; la table `playback_state` peut rester (ignorée par l'ancien code), la copie locale étant toujours tenue à jour.
