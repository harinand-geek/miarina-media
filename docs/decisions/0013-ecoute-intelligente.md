# 0013 — Écoute intelligente et fonctions du lecteur de musique

Date : 2026-11-28 · Statut : **acceptée** par le propriétaire (« ok vas y » à la recommandation 1 + 2 + 4 + 5, puis « continuer jusqu'à la fin » pour le reste)

## Contexte

Le propriétaire a demandé des fonctionnalités utiles qui manquent au lecteur de musique, et des « algorithmes avancés » qui facilitent l'usage. Parmi les propositions du 2026-11-28, il a retenu d'abord :

1. retenir les titres passés et ceux écoutés jusqu'au bout ;
2. une lecture aléatoire intelligente ;
4. une radio à partir d'un titre ;
5. une musique qui continue quand la file se termine.

Le 2026-11-28, le propriétaire a demandé de « continuer jusqu'à la fin » : les propositions 3, 6, 7, 8, 9, 10 et 11 ont suivi le même jour (§ 3 et § 6 à 11 ci-dessous).

Contrainte : tout reste **sur l'appareil** (principe local-first). Pas de service distant, pas de compte, pas de télémétrie.

## Décisions

### 1. Goûts appris (`lib/features/playback/taste.dart`)

- Un titre de la bibliothèque **entendu jusqu'au bout** gagne 1 point : l'engin signale la fin, ou 80 % de sa durée a vraiment été entendue.
- Un titre **passé** par l'auditeur (« Suivant », ou un autre titre de la file choisi) perd 1 point s'il a été entendu moins de 30 s ou moins de la moitié de sa durée.
- Le reste ne dit rien (une pause, un nouveau choix dans la bibliothèque, la touche « Précédent »).
- Le temps entendu se mesure **à l'horloge** pendant que l'engin dit qu'il joue, comme le journal d'écoute : Media3 n'envoie pas les positions au fil de la lecture.
- Deux titres entendus jusqu'au bout l'un après l'autre, à moins de 20 min d'écart, deviennent **voisins** (co-écoute, dans les deux sens).
- Les scores **s'effacent avec le temps** : ils sont divisés par deux en 45 jours. Ils restent entre −5 et +10.
- La mémoire est bornée : 3 000 titres au plus (on oublie d'abord les moins parlants), 800 titres avec des voisins, 16 voisins chacun.
- Stockage : clé `mm:taste:v1` dans le magasin de lecture (même endroit que l'historique et le journal).
- Seulement la musique de la bibliothèque : pas les vidéos, ni Focus (podcasts, cours, livres), ni l'écoute en ligne.

### 2. Lecture aléatoire intelligente (`smart_queue.dart`, `smartShuffleOrder`)

- Tirage pondéré (Efraimidis–Spirakis) : un titre aimé passe 1,5 à 3 fois plus souvent en tête, un titre souvent passé 0,25 fois, un titre entendu dans les 3 dernières heures 0,3 fois, un favori 1,4 fois.
- Ensuite, on **écarte les mêmes artistes** : jamais le même artiste ni le même album deux fois de suite quand c'est évitable. Quand un artiste a plus de titres que tous les autres réunis, il passe en priorité pour ne pas finir en série à la fin.
- Le titre choisi reste en premier, et chaque titre passe une seule fois.
- Réglage **« Lecture aléatoire intelligente »**, activé par défaut. Désactivé, on retrouve le hasard pur d'avant.

### 4. Radio (`radioPicks`, `QueueController.startRadio`)

- « **Radio de ce titre** » dans le menu ⋮ du lecteur (téléphone), dans le menu d'un titre de la liste Titres (téléphone et Windows) et sur les pages album et artiste.
- Proximité : même artiste (+3), même album (+1,2), même dossier (+0,6), et surtout **déjà écoutés ensemble** (jusqu'à +2,5). Le tout est multiplié par le goût. Une petite base (0,15) laisse place à la découverte.
- 25 titres au plus, jamais plus de deux du même artiste à la suite, sans vidéo ni fichier manquant.
- Lancée depuis le titre en cours, la radio le laisse jouer et remplace seulement la suite.
- La bibliothèque compte trop peu de titres : un message le dit, et rien ne change.

### 5. Continuation (`QueueController._continueIfEnding`)

- De la musique de la bibliothèque est en cours, la file en est à son dernier ou avant-dernier titre, sans répétition : **10 titres proches** des trois derniers entendus sont ajoutés à la fin de la file. Ils se voient dans la file, et on peut les retirer.
- On n'ajoute aucun titre déjà présent dans la file. Les titres entendus récemment sont rendus moins probables.
- Réglage **« Continuer avec des titres proches »**, activé par défaut.

### 3. Mix du jour selon les goûts (`dailyMixPicks`)

- 30 titres : un cinquième de favoris oubliés (aimés, favoris ou souvent joués, mais pas entendus depuis 45 jours), un tiers de titres proches des derniers entendus (les choix de la radio) et, pour le reste, les titres aimés (pondérés par le goût et le nombre d'écoutes). Le tout est mélangé, sans le même artiste deux fois de suite.
- Il reste le même toute la journée (`mm:dailyMix:v1`), même si les goûts évoluent entre-temps.

### 6. Recherche tolérante aux fautes (`crates/storage/src/fuzzy.rs`)

- Quand l'index plein texte trouve moins de 5 résultats, on compare les titres, artistes et albums mot à mot, accents retirés. La distance d'édition compte aussi l'inversion de deux lettres : aucune faute permise sous 3 lettres, une jusqu'à 5, deux au-delà. On compare aussi au début d'un mot encore en cours de frappe.
- Ces résultats arrivent après les résultats exacts.

### 7. Widget d'écran d'accueil Android (`PlayerWidget.kt`, `home_widget.dart`)

- Format 4×1, redimensionnable en largeur : pochette, titre, artiste, précédent / lecture-pause / suivant. Toucher le reste du widget ouvre l'appli.
- Flutter envoie le titre en cours. L'état lecture / pause vient du service de lecture lui-même, donc il reste juste même quand l'écran de l'appli est fermé. Dans ce cas, lecture-pause agit directement sur le lecteur, et précédent / suivant ouvrent l'appli (la file d'attente vit dans Flutter).

### 8. Réveil en musique (`features/alarm/`, `AlarmChannel.kt`)

- Réglages : l'heure, les jours (aucun = une seule fois), la musique (mix du jour, favoris ou toute la bibliothèque), le volume du réveil (Android) et un son progressif (bas au début, il monte en une minute).
- Quand il sonne : l'heure, le titre en cours, « Arrêter » et « Encore 10 min ».
- Android : c'est `AlarmManager.setAlarmClock`, comme les applis d'horloge, qui ouvre l'appli par-dessus l'écran verrouillé.
- **Deux permissions nouvelles**, utilisées uniquement pour le réveil :
  - `SCHEDULE_EXACT_ALARM` : Android 12+ la demande une fois, et l'écran du réveil le dit avec un bouton ;
  - `RECEIVE_BOOT_COMPLETED` : le réveil est reprogrammé après un redémarrage.
- Windows : un minuteur dans l'appli, donc le réveil ne sonne que si l'appli est ouverte (c'est écrit sur l'écran).

### 9. Égaliseur par sortie (`audio_route.dart`, `AudioRouteChannel.kt`)

- Android sait où va le son, sans permission : Bluetooth (chaque appareil à part), casque filaire ou USB, ou haut-parleur. Windows utilise la sortie choisie dans les réglages.
- Avec « Un réglage par sortie » (activé par défaut), chaque sortie garde son égaliseur, qui revient quand le son y retourne.
- L'égaliseur reste actif dès le lancement (`equalizerKeeperProvider`). Avant, Riverpod le mettait en pause tant qu'aucun lecteur n'était ouvert.

### 10. Rétrospective du mois (`listen_months.dart`, `month_recap.dart`)

- Un résumé mensuel est écrit en même temps que le journal d'écoute (`mm:listenMonths:v1`, conservé 24 mois) : les secondes par jour du mois, par artiste (50 au plus) et par titre (100 au plus).
- L'écran « Votre mois » s'ouvre depuis la carte « 7 derniers jours ». Il montre le temps d'écoute, les jours d'écoute, le jour le plus écouté, une barre par jour, les 5 artistes et les 10 titres les plus écoutés, et lance le top du mois. Les mois précédents restent accessibles.

### 11. Android Auto (`AutoLibrary.kt`, `auto_library.dart`)

- Le service de lecture devient un `MediaLibraryService`. C'est la même session pour l'appli, la notification et l'écran verrouillé.
- La voiture voit quatre listes : mix du jour, favoris, récemment joués et tous les titres. Flutter les écrit dans un fichier, au lancement puis quand un nouveau titre commence (au plus une fois toutes les 10 min), pour qu'elles existent même appli fermée.
- **Pas essayé en voiture** ni avec le Desktop Head Unit, absent ici.
- Un APK installé hors Play Store n'apparaît dans Android Auto que si les « sources inconnues » sont autorisées dans ses paramètres développeur.
- Pas de pochettes dans les listes de la voiture pour l'instant (les images sont des fichiers privés de l'appli).

### Compléments du 2026-11-28 (demandes du propriétaire)

- **Les listes suggérées s'ouvrent d'abord** (`mix_screen.dart`). Toucher la carte du mix, la carte « Découvrir », les tuiles du mix ou « Plus joués », ou la section « Les plus joués » ouvre la liste de ses titres : lire, mélanger, ou toucher un titre pour lire à partir de lui. Les boutons lecture et mélange de la carte du mix, et la pastille « Lecture aléatoire » de « Découvrir », jouent toujours directement.
- **Mix du moment** : le goût compte, pour chaque titre, les écoutes entières la nuit, le matin, l'après-midi et le soir. Le mix est fait pour le moment de la journée (« Mix du matin », « Mix du soir »…) : les titres habituellement écoutés à ce moment pèsent jusqu'à 2,5 fois plus. Il reste le même jusqu'au moment suivant. Le réveil et Android Auto prennent le même mix.
- **Recherche de la liste Titres** : une recherche simple (sans autre filtre) qui trouve moins de 5 titres exacts ajoute aussi les titres proches malgré les fautes.
- **Suggestions de la file** : la carte « titres proches » utilise l'algorithme de la radio, à partir du titre en cours et des deux précédents. Elle ne propose que des titres qui ont quelque chose en commun avec eux.

## Conséquences

- Aucune nouvelle dépendance, aucun accès réseau. Deux permissions Android, pour le réveil seulement (§ 8).
- Coût : le calcul se fait en mémoire sur la liste de la bibliothèque (3 000 titres au plus par tirage), une fois par radio ou par continuation, pas à chaque image.
- Tests : `test/smart_algorithms_test.dart` (goûts, effacement, stockage, aléatoire, radio) et `test/smart_playback_test.dart` (signaux sur la vraie file, continuation, radio). Les tests de playlists désactivent la continuation, car ils vérifient la file exacte.
