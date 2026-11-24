# Plan — passage en production (Stable) de Miarina Media 0.3

Date : 2026-11-24 · Demande du propriétaire : « finaliser l'app pour la production, pas bêta, et finir toutes les fonctionnalités pas encore faites ».

Point de départ : 0.2.4 publiée sur le canal Bêta (Windows et Android « Miarina Media Bêta ») ; le canal Stable reste 0.1.12 (Windows, Tauri) et 0.1.11 (Android, Tauri).

## Inventaire des fonctions visibles mais pas finies

Relevé dans l'app (badges PRÉVU / P1, valeurs « — ») et dans `flutter-implementation-map.md` :

| Lot | Fonction | Où | Plateformes |
|---|---|---|---|
| A1 | Plusieurs liens à la fois | Obtenir › accueil | Windows, Android |
| A2 | Qualité vidéo et format audio par défaut, limite de vitesse, sous-titres (réglage et onglet Sous-titres de l'analyse, DL-08) | Réglages › Téléchargements, analyse | Windows, Android |
| A3 | Lecture sans blanc, fondu entre les titres, normalisation du volume | Réglages › Lecture, Son | Windows (Android selon Media3) |
| A4 | Ratio cible et temps de partage des torrents | Torrents | Windows |
| A5 | Vidéo : chapitres, décalage et taille des sous-titres, format d'image, synchro audio, A–B | Lecteur vidéo | Windows, Android selon moteur |
| A6 | Playlist intelligente (règles), file intelligente, couleur de lecture | Playlists, File, Réglages | Windows, Android |
| A7 | Android : gestes vidéo (luminosité, volume), image dans l'image, import et export M3U, recherche — **fait 2026-11-24** (recherche déjà faite ; lecture sans blanc ajoutée), essai sur le Redmi à faire | Android | Android |

## Outils PC (handoff `design/design_handoff_outils_pc/`, priorité du propriétaire)

Après les lots A, avant la production. Windows seulement, jamais sur Android. Le handoff décrit l'app Tauri (`apps/client`) : il est reproduit dans l'app Flutter avec les mêmes jetons et composants (écart documenté).

| Lot | Contenu |
|---|---|
| C1 | Convertir : catégories Vidéo / Audio / Image, tuiles formats et outils (fusionner, découper, rogner, compresser, extraire l'audio, redimensionner…), dialogue d'options, file de conversion Démarrer / Arrêter, barre d'état — FFmpeg déjà livré. |
| C2 | Capture d'écran : Réglages › Capture d'écran, raccourcis globaux (Alt+C, Alt+Shift+C), superposition de sélection, copier / enregistrer, aperçu. — **fait 2026-11-24**, recette du propriétaire à venir. |
| C3 | Enregistrer l'écran : écran Enregistreur (plein écran, fenêtre, zone ; format, i/s, qualité ; son du PC, micro, curseur, compte à rebours), barre flottante exclue de la capture, Alt+R, enregistrements récents dans la bibliothèque. — **fait 2026-11-24**, recette du propriétaire à venir. |

## À décider

- **libmpv plus complète (Windows)** : la build livrée (mpv-winbuild-cmake 20261111) n'a que le filtre FFmpeg `equalizer` ; une build avec les filtres audio permettrait « Sauter les silences » et une normalisation en direct. Choix de build, taille et licences à faire avant de l'activer.

## Préparation de la production

| Lot | Contenu |
|---|---|
| B1 | Android : l'app Flutter reprend l'identité `org.miarina.media` (même clé de signature) et remplace la 0.1.11, avec reprise des données de la 0.1.11 (bibliothèque, playlists, favoris, téléchargements), essayée d'abord sur des données de démonstration puis sur le téléphone du propriétaire. La bêta séparée `org.miarina.media.beta` reste installable. |
| B2 | Fiabilité et mesures : démarrage, mémoire au repos et en téléchargement, taille des paquets (`docs/performance.md`), passe d'accessibilité clavier et lecteur d'écran, recette complète Windows et Android. |
| B3 | Publication 0.3.0 sur le canal Stable (`stable.json`, site, notes) — uniquement avec l'accord du propriétaire. |

## Règles

- Un lot à la fois : code, tests, essai réel, commit et push à la fin de chaque lot.
- Écrans sans maquette : composés à partir des éléments approuvés (règle acceptée pour Playlist), capture montrée au propriétaire avant publication.
- Rien n'est mis en ligne sans l'accord du propriétaire. Pas de signature Authenticode (décision du 2026-11-20, inchangée).
- Ce qui ne peut pas être fait honnêtement (fonction absente du moteur, test impossible sans appareil) est dit et documenté, jamais simulé.
