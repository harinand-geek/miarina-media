# Miarina face aux alternatives

Analyse du 11 novembre 2026 — version publiée 0.1.7, sources applicatives 0ccc620, dépôt consulté au commit 1100485.

## Conclusion

Miarina a une proposition cohérente : réunir navigation, téléchargement vidéo/audio, bibliothèque et lecture locale dans une application gratuite sur Windows et Android, avec torrents sur Windows. Son intérêt réside dans ce parcours intégré et dans le contrôle laissé à l’utilisateur. Les preuves disponibles ne permettent pas de le présenter comme plus rapide, plus stable, plus léger ou globalement meilleur que ses concurrents.

L’objectif commercial conseillé est une alternative accessible pour conserver et retrouver ses médias, plutôt qu’un clone ou un accélérateur promettant une vitesse supérieure.

## Méthode et limites

Lecture du code et des rapports du dépôt, puis consultation des descriptions officielles des alternatives. Aucun benchmark comparatif, test utilisateur ou nouvel essai sur téléphone n’a été exécuté pour cette analyse. Les descriptions concurrentes sont des déclarations de leurs éditeurs, pas des résultats reproduits. L’absence d’une fonction dans une page marketing ne prouve pas son absence du produit.

Le site snaptubeapp.com renvoyait un message de maintenance dans la source consultée ; aucune comparaison précise de sa version actuelle, de ses publicités, de sa sécurité ou de ses performances n’est donc retenue. Le dépôt MDM distant n’a pas pu être récupéré par l’outil web : la comparaison MDM porte sur le sous-module épinglé 46bb3bcd, et non sur une version actuelle supposée.

## État réel de Miarina

- Windows et Android : analyse de liens, choix des formats disponibles, file de tâches, bibliothèque et lecteur, navigateur intégré avec recherche et favoris.
- Windows : yt-dlp, FFmpeg et QuickJS inclus ; conversion MP3 à plusieurs débits et FLAC ; torrents et magnets, sélection, pause/reprise et limites de débit.
- Android : extracteur inclus dans l’APK ; MP3 320 kbps vérifié sur un APK antérieur dans l’émulateur, avec inspection et décodage du fichier. Cela ne valide pas tous les téléphones ni tous les fournisseurs vidéo.
- Extension Windows : envoi explicite de liens Chrome/Edge, mode développeur et configuration de l’identifiant. Ce n’est pas une interception automatique équivalente à IDM.
- Mises à jour 0.1.7 : vérification d’un manifeste Ed25519, taille et SHA-256 de l’artefact ; téléchargement depuis les réglages, installation sur action utilisateur. Windows ouvre NSIS et Android son installateur système. Le parcours complet d’installation depuis l’interface reste à valider.
- Tests rapportés : 79 tests frontend et trois tests spécifiques à la signature/version des mises à jour ; audits de transferts HTTP et torrent local antérieurs. Le nombre de tests n’est pas un score de qualité comparatif.
- Les torrents ne sont pas automatiquement indexés dans la bibliothèque média. Le moteur HTTP segmenté MDM reste désactivé dans les versions publiques.

Preuves : `docs/test-builds.md`, `docs/app-updates.md`, `docs/prebuild-audit-2026-11-09.md`, `docs/android-extractor-validation.md`, `docs/integrations/misterdownloadmanager.md`, `apps/client/src-tauri/src/updates.rs`, `apps/client/src/features/settings/MobileSettings.tsx`.

## Comparaison

| Alternative | Ce qu’elle annonce / documente | Position défendable de Miarina | Écart à combler |
|---|---|---|---|
| IDM | Segmentation dynamique, reprise, capture navigateur, planification, récupération de sites ; essai et offre payante | Une offre gratuite centrée sur les médias, avec bibliothèque, lecteur et version Android | Installation simple de l’extension, reprise après incident et performances mesurées ; aucune preuve de vitesse supérieure |
| Televzr | Téléchargement vidéo/audio, bibliothèque, lecture hors ligne, Windows/macOS et offre Pro | Un parcours comparable orienté médias, également décliné sur Android et sans abonnement actuellement | La bibliothèque et le lecteur ne sont pas uniques ; fiabilité native à démontrer et pas de distribution macOS Miarina |
| Free Download Manager | Gratuit sans publicité, Windows/macOS/Linux/Android, torrents, segmentation, planification et contrôle distant | Mettre en avant le parcours média et son navigateur intégré, sous réserve d’essais d’usage | Gratuité, absence de publicité, torrents et multiplateforme ne sont pas des exclusivités ; FDM est un concurrent direct |
| Seal | Android libre, yt-dlp, playlists, sous-titres, métadonnées et modèles de commandes | Continuité de présentation Windows/Android, navigation et bibliothèque intégrées | Le libre et yt-dlp ne différencient pas à eux seuls ; playlists et sous-titres restent des manques Miarina |
| Mister Download Manager, révision épinglée | Gestionnaire desktop, segmentation, extensions, torrents et nombreuses fonctions avancées décrites dans son README | Transformer une partie de ces composants en une expérience média propre à Miarina, avec Android | Le sous-module n’équivaut pas à une intégration complète ; FTP, RSS, débridage, galeries, planification et contrôle distant restent hors du parcours public Miarina |
| SnapTube | Référence d’expérience mobile donnée par le propriétaire ; site consulté en maintenance | Viser un parcours mobile court : chercher, choisir, télécharger, lire | Comparaison actuelle non vérifiée ; ne pas revendiquer une supériorité, une parité totale ou des défauts concurrents non établis |

Les annonces « jusqu’à 8 fois plus rapide » d’IDM ou les chiffres de comparaison du README MDM ne sont pas des mesures de Miarina. Les reprendre pour Miarina serait incorrect, d’autant que son adaptateur HTTP MDM reste expérimental.

## Valeur à mettre en avant

1. **Un parcours complet pour les médias.** Le bénéfice est de passer de la découverte à une collection locale consultable, sans changer constamment d’application.
2. **Deux plateformes, une même logique d’usage.** Windows et Android partagent une présentation et des étapes proches. Cela ne signifie ni synchronisation des bibliothèques ni parité de fonctions.
3. **Des outils déjà inclus.** L’utilisateur n’installe pas séparément les outils d’extraction/conversion fournis. Contrepartie : environ 70,2 Mio pour l’installateur Windows et 126,8 Mio pour l’APK universel 0.1.7 ; ne pas qualifier l’APK d’ultraléger.
4. **Des choix explicites.** Format, emplacement, démarrage du téléchargement et installation des mises à jour restent visibles. Pas de compte nécessaire dans le parcours actuel.
5. **Une application gratuite au code accessible.** C’est un avantage face aux offres payantes, mais pas face à tous les projets libres. L’inventaire des sources natives Android tierces reste incomplet ; ne pas promettre une reproductibilité intégrale déjà obtenue.

## Texte de positionnement proposé

> **Vos vidéos et votre musique, du lien à votre bibliothèque.**
>
> Recherchez, téléchargez et retrouvez vos médias dans Miarina Media, sur Windows et Android. Choisissez le format, gardez vos fichiers sur votre appareil et lisez-les hors ligne. Sans compte ni publicité dans l’application. Sur Windows, gérez aussi vos torrents et envoyez vos liens depuis Chrome ou Edge.
>
> Préversion en développement. Les fonctions disponibles et leur validation diffèrent selon la plateforme.

À utiliser avec des précisions proches : extension en mode développeur ; torrents Windows uniquement ; mises à jour téléchargées sur demande et installation confirmée. Ne pas écrire « tous les sites », « sans bug », « meilleur que SnapTube », « plus rapide qu’IDM » ou « tout MDM intégré ».

## Priorités pour devenir réellement préférable

### 1. Fiabilité observable avant nouvelles fonctions

Rejouer sur téléphone ARM64 réel et Windows installé : analyse → téléchargement → lecture ; MP3 ; pause/reprise ; réseau coupé puis rétabli ; stockage plein ; mise en arrière-plan ; redémarrage ; conservation des données. Tester aussi une vraie mise à jour signée entre deux versions de test, sans modifier le canal public pour simuler une version. Conserver versions, appareils, étapes et résultats. Critère : aucun échec bloquant non expliqué dans cette matrice et correction de chaque régression reproduite.

### 2. Réduire les étapes imposées à l’utilisateur

Simplifier l’appairage de l’extension et préparer sa distribution en magasin. Unifier la langue de l’interface, actuellement majoritairement anglaise avec le nouvel écran de mise à jour en français. Mettre à disposition des messages d’erreur actionnables, un essai de lecture fiable et un plein écran vérifié. La confiance se gagne ici avant d’ajouter un autre protocole.

### 3. Android et connexions coûteuses

Évaluer un APK ARM64 séparé, proposer une règle Wi-Fi réellement appliquée, puis la reprise des téléchargements de mises à jour et leur gestion en arrière-plan. Aujourd’hui le réglage Wi-Fi pour gros fichiers est encore annoncé à venir. Mesurer taille, mémoire, batterie et taux de reprise sur matériel réel avant toute promesse de légèreté ou d’économie de données.

### 4. Compléter les usages média

Prioriser playlists et sous-titres selon les demandes réelles ; onglets et historique du navigateur ; import explicite des médias issus de torrents dans la bibliothèque. Préserver une interface simple plutôt que d’exposer toutes les fonctions MDM simultanément.

### 5. Produire une comparaison reproductible

Même machine, réseau, serveur et fichiers autorisés ; plusieurs répétitions ; médiane et dispersion. Mesurer délai d’analyse, temps total, réussite/reprise, CPU/RAM, batterie Android et nombre d’actions nécessaires. Comparer chaque produit sur son périmètre réel. Les mesures de performance du dépôt datent de versions antérieures et ne constituent pas un benchmark de la 0.1.7.

## Sources consultées

- IDM : https://www.internetdownloadmanager.com/features2.html
- Televzr : https://televzr.com/
- Free Download Manager : https://www.freedownloadmanager.org/features.htm
- Seal : https://github.com/JunkFood02/Seal
- SnapTube, page de maintenance : https://www.snaptubeapp.com/
- MDM épinglé : https://github.com/anefzaoui/misterdownloadmanager/tree/46bb3bcd316a540a05fc18feff40707afe5a4dee

Aucune modification du landing public ni nouvelle publication de logiciel n’est effectuée par cette analyse. Le texte proposé peut être intégré ensuite en gardant les réserves de plateforme et de validation.
