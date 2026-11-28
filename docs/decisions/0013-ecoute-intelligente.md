# 0013 — Écoute intelligente : goûts appris, aléatoire intelligent, radio, continuation

Date : 2026-11-28 · Statut : **acceptée** par le propriétaire (« ok vas y » à la recommandation 1 + 2 + 4 + 5)

## Contexte

Le propriétaire a demandé des fonctionnalités utiles qui manquent au lecteur de musique, et des « algorithmes avancés » qui facilitent l'usage. Parmi les propositions du 2026-11-28, il a retenu d'abord :

1. retenir les titres passés et ceux écoutés jusqu'au bout ;
2. une lecture aléatoire intelligente ;
4. une radio à partir d'un titre ;
5. une musique qui continue quand la file se termine.

Restent proposés pour la suite : un vrai mix du jour (3), une recherche tolérante aux fautes (6), un widget d'écran d'accueil (7), un réveil en musique (8), l'égaliseur par appareil (9), une rétrospective du mois (10) et Android Auto (11).

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

## Conséquences

- Aucune nouvelle dépendance, aucune permission, aucun accès réseau.
- Coût : le calcul se fait en mémoire sur la liste de la bibliothèque (3 000 titres au plus par tirage), une fois par radio ou par continuation, pas à chaque image.
- Tests : `test/smart_queue_test.dart` (goûts, effacement, stockage, aléatoire, radio) et `test/smart_playback_test.dart` (signaux sur la vraie file, continuation, radio). Les tests de playlists désactivent la continuation, car ils vérifient la file exacte.
