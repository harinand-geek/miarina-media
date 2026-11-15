# 0006 — Android : le lecteur d'abord, le téléchargement en dernier

Date : 2026-11-15 · Statut : **acceptée** (décision du propriétaire du produit) · Remplace le point 3 de [0001](0001-embedded-browser-p0.md)

## Contexte

Depuis l'ajout du lecteur de musique (accès aux médias du téléphone, playlists, égaliseur), l'usage quotidien de l'app Android est l'écoute ; le téléchargement est occasionnel. Or l'app s'ouvrait sur l'Accueil (coller un lien) et la barre comptait 5 onglets : `Accueil · Navigateur · Téléch. · Musique · Vidéos`.

Le propriétaire a pris Lark Player comme **référence fonctionnelle** (captures fournies le 2026-11-15) : la bibliothèque s'ouvre en premier, une seule recherche en haut mène à la musique locale et aux sites, et le navigateur n'est pas un onglet. Comme pour Televzr et SnapTube (`CLAUDE.md`), on ne reprend ni la marque, ni le logo, ni les icônes, ni les couleurs de Lark : Miarina garde son identité (sombre, accent `#35C9BD`, corail pour la lecture).

## Décisions

1. **Barre du bas : `Musique · Vidéos · Téléchargements`.** L'app s'ouvre sur Musique ; Retour ramène à Musique, puis quitte l'app.
2. **L'Accueil disparaît.** La carte « Coller un lien » et ses actions rapides passent en tête de Téléchargements. « Reprendre » (COM-04) passe en tête de Vidéos, pour les vidéos commencées (la musique reprend déjà via la session du lecteur). Le logo de fin de splash et le bouton Paramètres (avec le point de mise à jour) passent dans l'en-tête de Musique.
3. **Le navigateur est masqué, pas supprimé.** Il s'ouvre depuis la recherche (sites, « Chercher sur YouTube / sur le web »), depuis l'action « Navigateur » de Téléchargements, ou sur une demande (`browserRequest`). « Retour à Miarina » ramène à l'onglet d'où il a été ouvert. Les règles de 0001 (pages non fiables, pas de contournement de DRM, paywall ou authentification) restent inchangées.
4. **Une seule recherche** (loupe de Musique et de Vidéos), en plein écran :
   - champ vide : raccourcis vers des sites (tuiles avec une lettre, aucun logo distant à cause de la CSP), bouton Coller ;
   - des mots : d'abord les résultats sur le téléphone (musique et vidéos), puis « Chercher « … » sur YouTube » et « … sur le web » ;
   - **Entrée sans aucun résultat local : ouvre directement la recherche YouTube** dans le navigateur intégré (demande du propriétaire : si la musique n'est pas là, la chercher automatiquement) ;
   - un lien : « Analyser le lien », comme la carte de Téléchargements.
5. **Pas de saut automatique vers Téléchargements** quand la bibliothèque est vide : l'écran vide de Musique propose « Télécharger de la musique » (un tap), en plus de la carte d'accès à la musique du téléphone.

6. **Style inspiré de Lark, identité Miarina** (précision du propriétaire, même jour : « garder le logo et les couleurs, copier le style, arrondi, élégant ») :
   - en-tête de Musique et Vidéos : logo Miarina + « Miarina Media », le titre de l'onglet reste un titre pour les lecteurs d'écran ;
   - sous-onglets en pilules (corail quand actif, `surface` sinon), ordre Titres · Playlists · Dossiers · Artistes · Albums · Favoris ;
   - dossiers, artistes, albums et playlists en cartes arrondies d'une colonne (`LibraryCard` : pochette 76 px, nom, deux lignes de détail, nombre en haut à droite ; ▶ corail sur les albums) ; « Nouvelle playlist » en grande carte ;
   - lignes de titres 72 px, pochettes 56 px arrondies ; vignettes vidéo plus arrondies ;
   - mini-lecteur 76 px arrondi, ombre, pause dans un cercle corail ;
   - Paramètres : grand titre, réglages groupés dans des cartes arrondies, chevron sur les lignes cliquables.
7. **Grand lecteur : glisser vers le bas pour réduire.** La ligne de prise, la barre du haut et la pochette suivent le doigt ; le lecteur rétrécit un peu et s'arrondit, puis se réduit en mini-lecteur (au-delà de 20 % de la hauteur ou sur un geste rapide) ou revient en place. Le bouton ⌄ joue la même animation. Mouvement réduit ou Éco : réduction directe, sans glissement. Un petit mouvement (< 8 px) reste un tap.

8. **Attente de l'analyse d'un lien** (recette téléphone : « Reading formats… » seul faisait abandonner) : écran `AnalysisWaiting` sur Android et Windows — ce qui se passe, depuis combien de secondes, une astuce ; aucune durée ni progression inventée.
9. **Windows suit la même logique** (demande du propriétaire, 2026-11-15) : ouverture sur Écouter › Titres, sélecteur « Écouter | Obtenir » ; recherche unique dans la barre de titre (Ctrl K) — sites avec logos, résultats de l'ordinateur, « Chercher sur YouTube / sur le web », Entrée sans résultat local → YouTube dans le navigateur intégré, Entrée avec résultats → lit le premier, lien → analyse ; la page web du navigateur s'efface pendant que le panneau est ouvert (la vue native le cacherait) ; formes arrondies (jetons de rayon relevés, menu latéral en pilules, mini-lecteur flottant). Le menu latéral garde ses deux espaces : sur grand écran, un seul clic sépare écouter et obtenir.

## Conséquences

- Le design approuvé (écran 01 Accueil, barre M5 à 5 onglets) n'est plus suivi sur ces points ; les écrans touchés sont mis à jour dans `docs/design-implementation-map.md`. Une maquette Claude Design de la nouvelle barre et de la recherche reste souhaitable.
- Windows n'est pas concerné (barre latérale inchangée).
- Prochaines étapes inspirées des captures, à valider : lecteur et feuilles teintés par la pochette, cartes de liste avec deux titres d'exemple, historique de recherche. À corriger aussi : les fichiers téléchargés n'ont ni tags ni pochette intégrés (aucun `--embed-metadata` / `--embed-thumbnail`) ; les autres lecteurs affichent alors le nom du dossier « Miarina » à la place de l'artiste.
