# Fiche LOT-AND06 — Android : musique et vidéos déjà présentes sur le téléphone

- Statut : fait ; vérification sur téléphone réel en cours (Redmi Note 10 Pro, Android 13 / MIUI 14)
- Exigence CDC : AND-06 (MediaStore et import SAF), SEC-05 (permissions minimales et révocables)
- Demande du propriétaire (2026-11-13) : un vrai lecteur de musique, avec accès aux fichiers locaux du téléphone ; permissions approuvées le même jour
- Maquette : `design/design_handoff_android_v2` écran 05 ; aucune maquette pour la demande d'accès (adaptation ci-dessous)

## Réalisé

| Élément | Réalisation |
|---|---|
| Permissions | `READ_MEDIA_AUDIO` et `READ_MEDIA_VIDEO` (Android 13+, deux autorisations séparées « Musique et audio » / « Vidéos »), `READ_EXTERNAL_STORAGE` limité à Android ≤ 12 (`maxSdkVersion="32"`). `requestLegacyExternalStorage` pour qu'Android 10 lise les fichiers par leur chemin (ignoré à partir d'Android 11). Aucune permission d'écriture ni d'accès global aux fichiers |
| Liste du téléphone | `DeviceMediaPlugin.kt` interroge l'index média du système sur tous les volumes (mémoire interne, carte SD) : musique (`IS_MUSIC`, donc sans sonneries, alarmes ni sons de notification ; extraits de moins de 30 s exclus) et vidéos ; 20 000 fichiers au plus ; lecture seule |
| Indexation | `Library::sync_listed` (crate `library`) : partage le cœur du scan de dossier ; fichiers nouveaux ajoutés, retrouvés restaurés, disparus marqués introuvables ; un fichier retiré de la bibliothèque n'est jamais rajouté (COM-10) ; les fichiers propres à l'app absents de la liste mais présents sur disque restent. Une transaction |
| Quand | Au démarrage si l'accès a déjà été donné (jamais de demande au démarrage) ; à l'ouverture de Musique si la dernière indexation date de plus de 5 min ; juste après l'autorisation |
| Demande d'accès (adaptation) | Carte « Musique du téléphone » en tête de Musique › Titres (`DeviceMediaCard.tsx`) : texte « lecture seule », « Autoriser l'accès » (dialogues système, seulement sur appui), « Plus tard » (masquée jusqu'au prochain lancement). Après un refus définitif : « Ouvrir les réglages » (fiche de l'app dans Android) et nouvelle vérification au retour dans l'app. Masquée sur Windows et une fois l'accès donné |
| Lecture | Inchangée : le lecteur natif (L03, L07) lit les chemins ; titres, albums, artistes, dossiers et pochettes viennent des tags lus comme pour les téléchargements |
| Suppression | Android interdit de supprimer le fichier d'une autre app : message clair (« Retirez-le de la bibliothèque, ou supprimez-le avec l'app Fichiers ») au lieu de l'erreur système ; « Retirer de la bibliothèque » fonctionne |

## Écarts et limites

- « Importer un dossier » (SAF, bouton de l'écran 05) reste PRÉVU : l'index média couvre déjà les dossiers de musique ; un dossier non indexé par Android (fichiers `.nomedia`, certains dossiers d'apps) n'apparaît pas.
- Pas de suppression avec confirmation système (`MediaStore.createDeleteRequest`) ni d'écriture des tags dans les fichiers des autres apps : écriture refusée par Android.
- Pas d'observation en continu de l'index : un fichier ajouté pendant que l'app est ouverte apparaît à la prochaine ouverture de Musique (après 5 min) ou au prochain lancement.
- Android 14+ « accès partiel » aux vidéos : seules les vidéos choisies par l'utilisateur sont listées.

## Vérifications

- Tests : `library::sync_listed` (doublons, chemins relatifs et extensions refusés, fichier disparu, fichier retiré jamais rajouté, fichier propre conservé, restauration) ; `device_media::tests` ; `device-media.test.tsx` (masquée sur Windows et une fois autorisée, demande seulement sur appui, refus → réglages puis nouvelle vérification au retour, « Plus tard », erreur affichée, nouvelle indexation après 5 min).
- Téléphone : voir `docs/recette-android-telephone.md` § 5.
