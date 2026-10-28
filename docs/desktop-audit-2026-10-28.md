# Audit desktop — 28 octobre 2026

## Corrections

- Lecture des sorties yt-dlp : les lignes sans limite étaient allouées en entier
  avant filtrage. Le moteur conserve maintenant au plus 4 097 octets et vide le
  reste de la ligne. Test avec une ligne de 1 Mio, suivi d'une progression valide.
- Finalisation : un flux intermédiaire plus gros que le résultat pouvait être
  choisi après reprise. Seuls les fichiers correspondant au modèle final
  `media.<extension>` sont retenus. Régression couverte avec `media.f137.mp4`.
- Lecteur : la position est sauvegardée au détachement de l'élément média,
  avant que React ne vide la référence utilisée par le nettoyage de l'effet.
  Test de sortie du lecteur à 37 secondes.
- Fond vidéo : arrêt du timer lorsque la page est masquée ou la vidéo terminée,
  reprise au retour visible. Aucun changement du design.

## Vérifications exécutées sur Windows

- Suite frontend finale : 65 tests, 13 fichiers, tous réussis, dont le nouveau
  test de sauvegarde du lecteur.
- Rust workspace : 170 tests réussis, 6 tests externes ignorés par défaut.
- TypeScript, ESLint, build Vite, format Rust et contrôle des différences : réussis.
- Clippy application et moteur, toutes cibles de test, avertissements interdits : réussi.
- Téléchargement réel YouTube via yt-dlp + QuickJS (audio de Sintel, contenu
  libre) : réussi en 25,02 secondes pour le test ; fichier final validé.

## Limites de cet audit

Ce contrôle ne certifie pas l'absence de tout bug. Il ne remplace pas une campagne
interactive Windows : navigateur WebView2, erreurs des sites, fusion vidéo/audio,
redémarrage durant un transfert, saturation disque et lecture des codecs réels.
Pas de nouvelle mesure CPU/RAM ni de temps de démarrage ; aucun gain chiffré
annoncé. Les mesures historiques restent dans `performance.md`.
Les onglets multiples et l'historique du navigateur restent des fonctions à
implémenter, pas des fonctions validées par ces tests.
