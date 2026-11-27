# Cahier des charges — Amélioration de Miarina Media

**Référence :** CDC-MIARINA-001 · **Version :** 1.0 · **Date :** 11 novembre 2026  
**Base :** Miarina 0.1.7 Windows et Android.  
**Statut :** document de travail proposé pour réalisation progressive. Les exigences futures ne sont pas des fonctions déclarées livrées.

## Sommaire

1. Vision et objectifs
2. État initial
3. Parcours et priorités
4. Socle lecteur et bibliothèque
5. Lecteur Android inspiré de Lark Player
6. Lecteur Windows de type VLC
7. Téléchargements et navigateur
8. Extension, torrents et MDM
9. Mises à jour
10. Interface et accessibilité
11. Architecture et données
12. Sécurité et dépendances
13. Performances et compatibilité
14. Recette
15. Lots de réalisation
16. Livraison et suivi
17. Risques et décisions ouvertes
18. Références

## 1. Vision et objectifs

**Vos vidéos et votre musique, du lien à votre bibliothèque.** Miarina doit permettre de trouver un média autorisé, le télécharger, le classer et le lire, sans compte obligatoire ni publicité dans l’application.

### Objectifs prioritaires

- Fiabiliser le parcours lien → analyse → téléchargement → bibliothèque → lecture.
- Intégrer un lecteur musical Android complet, inspiré des usages de Lark Player : playlists, écran verrouillé, commandes système, égaliseur et mini-lecteur.
- Intégrer un lecteur Windows de type VLC : lecture native robuste, pistes audio, sous-titres et véritable plein écran.
- Conserver les fichiers, réglages, playlists et positions lors des mises à jour.
- Permettre une réalisation par petits lots testables et indépendamment livrables.
- Aligner le site et les promesses commerciales sur les fonctions réellement validées.

### Règles produit

« Intégré » signifie lecture dans Miarina, sans installer Lark ou VLC séparément. L’ouverture dans un lecteur externe reste un secours facultatif. Lark, VLC, SnapTube, Televzr et IDM sont des références d’usage : ne pas reprendre leur marque, leurs ressources ou leur interface à l’identique.

Windows et Android partagent une logique d’usage, sans promettre une parité immédiate ni une synchronisation entre appareils. Réutiliser l’existant avant de réécrire. Distinguer retirer de la bibliothèque et supprimer un fichier. Ne pas annoncer « tous les formats », « tous les sites », « sans bug » ou une vitesse supérieure sans preuve.

## 2. État initial et écarts

État documentaire au 11 novembre 2026, à recouper avec le code au début de chaque lot.

| Domaine | Base actuelle | Amélioration attendue |
|---|---|---|
| Téléchargement | Analyse, file, reprise selon source, outils intégrés | Recette réelle complète, reprise après incident, playlists et sous-titres |
| Android | Media3/ExoPlayer natif ; MP3 320 kbps testé sur émulateur antérieur | Service musical durable, système/Bluetooth, téléphone réel, égaliseur |
| Windows | Bibliothèque et lecteur dépendant de la lecture WebView | Moteur natif robuste, formats et pistes, correction vérifiée de l’écran blanc |
| Navigateur | Navigation, recherche, favoris et détection | Onglets, historique, coordination des surfaces natives |
| Extension | Envoi explicite Chrome/Edge, mode développeur | Installation simplifiée, validation navigateur réel, distribution magasins |
| Torrents | Windows : sélection, limites, pause/reprise | Règles de partage, import bibliothèque, RSS ultérieur |
| MDM HTTP | Adaptateur expérimental | Crash/reprise/finalisation à valider avant activation publique |
| Mises à jour | Manifeste signé, hash, téléchargement et lancement installation | Recette de bout en bout, reprise et arrière-plan Android |
| Distribution | APK signé ; Windows sans Authenticode | Signature Windows à étudier ; sources natives tierces à compléter |
| Langues | Majoritairement anglais, nouvel écran de mise à jour français | Catalogue français/anglais cohérent |

La 0.1.7 n’a pas de recette complète d’installation depuis l’interface sur appareil réel. Référence de taille : Windows environ 70,2 Mio, APK universel 126,8 Mio. Les anciennes mesures de performance ne sont pas un benchmark de cette version. Les fonctions du sous-module MDM ne sont pas toutes intégrées.

## 3. Parcours, priorités et suivi

### Utilisateurs

- Mobile quotidien : musique hors ligne, casque, playlists, écran verrouillé.
- Windows : fichiers variés, clavier/souris, grands écrans, sous-titres.
- Connexion limitée : reprise fiable et maîtrise des données mobiles.
- Avancé : torrents, pistes, formats et limites de débit.

| ID | Parcours de référence | Réussite attendue |
|---|---|---|
| PAR-01 | Partager/coller → MP4 → télécharger → lire | Bon média dans la bibliothèque, sans tâche dupliquée |
| PAR-02 | MP3 → playlist → verrouiller Android | Musique et commandes système continuent |
| PAR-03 | MKV Windows → piste audio → SRT → plein écran | Lecture dans Miarina et retour à la fenêtre intact |
| PAR-04 | Coupure réseau → retour → reprendre | Octets corrects ; sinon redémarrage explicitement proposé |
| PAR-05 | Mise à jour → télécharger → plus tard → installer | Authenticité et données conservées, rien de forcé |
| PAR-06 | Torrent terminé → importer média | Fichier complet indexé sans modifier le partage |
| PAR-07 | Fichier déplacé/accès révoqué | Indisponibilité expliquée et relocalisation proposée |

Priorités : **P0** sécurité/perte de données/parcours bloqué ; **P1** cœur produit ; **P2** confort ; **P3** extension avancée.

Statuts : À faire → En étude → Prêt → En cours → À tester → Validé → Publié, ou Bloqué avec raison. Toutes les exigences commencent **À faire ou à auditer** : certaines sont partiellement existantes. Chaque ID reste stable. Pas de date ni de version promise avant étude et accès au matériel de recette.

## 4. Socle lecteur et bibliothèque

| ID | Priorité | Exigence | Critère de réception |
|---|---|---|---|
| COM-01 | P1 | Contrat lecteur commun, adaptateurs natifs | Un seul moteur propriétaire du média ; état UI synchronisé |
| COM-02 | P1 | Play/pause/stop/seek/volume/précédent/suivant | Actions testées pendant chargement, fin et erreur |
| COM-03 | P1 | File de lecture distincte des téléchargements | Ajouter après le titre, réordonner, retirer, vider sans effacer les fichiers |
| COM-04 | P1 | Reprise par média | Position persistante, restauration après fermeture ; fin de lecture explicitement traitée |
| COM-05 | P1 | Mini-lecteur pendant navigation | Aucun redémarrage ni double son ; agrandissement conserve la position |
| COM-06 | P1 | Playlists et favoris locaux | Créer, renommer, réordonner, retirer et restaurer après redémarrage |
| COM-07 | P1 | Pochettes et métadonnées | Titre/artiste/album/durée ; logo discret si image absente |
| COM-08 | P1 | Import fichiers/dossiers autorisés | Scan incrémental annulable, déduplication, accès révoqué géré |
| COM-09 | P1 | Recherche et filtres | Audio/vidéo, titre, artiste, album, dossier et favoris |
| COM-10 | P0 | Retrait distinct de suppression | Confirmation nommant les fichiers ; aucune suppression en cascade implicite |
| COM-11 | P2 | Import/export M3U/M3U8 | UTF-8, chemins documentés, entrées absentes expliquées |
| COM-12 | P2 | Aléatoire et répétition | Off/un titre/file ; comportement correct après modification de la file |
| COM-13 | P2 | Historique de lecture effaçable | Local et distinct de l’historique de téléchargement |

Un téléchargement, un média et une entrée de playlist sont trois objets distincts. Utiliser des identifiants persistants ; ne pas identifier uniquement un média par son titre. Sous Android gérer URI et permissions persistantes, pas seulement des chemins supposés permanents.

## 5. Lecteur Android — usages inspirés de Lark Player

### Écrans et portée

Bibliothèque musicale : Titres, Albums, Artistes, Dossiers, Playlists, Favoris. Mini-lecteur permanent pendant la navigation. Écran « En lecture » : pochette, titre/artiste, progression, commandes, file et accès aux réglages audio. Vidéo adaptée au paysage et au tactile.

Lark présente notamment écoute hors ligne, égaliseur, vitesse, minuteur et thèmes : références fonctionnelles, pas engagement de reproduire tout Lark. Cloud, création de sonneries et amplification « 200 % » sont hors première livraison.

| ID | Priorité | Exigence | Critère de réception |
|---|---|---|---|
| AND-01 | P1 | Lecture audio dans service indépendant de l’écran | Continuité écran verrouillé et changement d’app sur téléphone réel |
| AND-02 | P1 | MediaSession et notification musicale | Commandes et métadonnées reflètent l’état réel |
| AND-03 | P1 | Focus audio, appel et retrait casque | Pause/atténuation appropriée, aucune reprise intempestive |
| AND-04 | P1 | Bluetooth et écran verrouillé | Play/pause/suivant/précédent testés avec casque réel |
| AND-05 | P1 | Persistance de la file | Restauration après arrêt ; après mort du processus, reprise proposée sans son surprise |
| AND-06 | P1 | MediaStore et import SAF | Permissions minimales, refus/révocation, carte SD et URI indisponible gérés |
| AND-07 | P1 | Vrai plein écran vidéo | Orientation/barres système/retour Android cohérents ; pas simple agrandissement React |
| AND-08 | P2 | Image dans l’image si supportée | Détection de capacité ; retour vers la vidéo ; pas d’exigence PiP sur Android 7 |
| AND-09 | P2 | Vitesse 0,5× à 2× | Effet et persistance vérifiés sur audio/vidéo |
| AND-10 | P2 | Égaliseur, préréglages, personnalisé | Détection capacité périphérique, bypass/reset et restitution normale |
| AND-11 | P2 | Minuteur durée/fin de titre | Annulation et arrêt musique sans fermeture forcée de l’app |
| AND-12 | P2 | Gapless et fondu optionnel | Étude séparée, corpus validé, modes compatibles décrits ; fondu off par défaut |
| AND-13 | P2 | Pistes audio et sous-titres | Sélection réelle, import SRT/VTT, erreur propre si non pris en charge |
| AND-14 | P2 | Gestes et verrouillage commandes | Seek/volume/luminosité, indication et alternative accessible ; désactivables |
| AND-15 | P3 | Paroles locales LRC/texte | Import utilisateur ; aucune collecte distante implicite |

### Orientation technique

Conserver Media3/ExoPlayer comme premier candidat. Déplacer la propriété du lecteur vers un `MediaSessionService` ou `MediaLibraryService` ; React et le plugin deviennent contrôleurs. Documenter lifecycle, contrôleurs externes autorisés, permissions de service média selon SDK, arrêt et restauration.

N’ajouter un autre moteur que si le corpus démontre un besoin non satisfait. Ne pas embarquer deux moteurs complets sans mesurer taille, RAM, stabilité et batterie.

### Recette Android spécifique

30 minutes audio verrouillé puis 30 minutes avec autre application ; 20 changements de titres et 20 seeks ; appel, perte de focus, retrait/reconnexion casque ; rotation/PiP/retour ; accès révoqué, stockage presque plein et arrêt système. Téléphone ARM64 physique obligatoire : l’émulateur ne valide pas batterie, Bluetooth et politiques constructeur.

## 6. Lecteur Windows — expérience de type VLC

### Objectif et décision technique

Lecture native dans Miarina, sans VLC externe obligatoire. **Candidat recommandé : libVLC embarqué, sous réserve de prototype.** VLC est le lecteur de référence ; libVLC est le moteur intégrable. Choisir une version stable, le wrapper Rust/FFI, les DLL et les modules exacts après étude. La documentation de développement ne garantit pas l’API du paquet stable retenu.

### Prototype obligatoire WIN-SPIKE

Comparer moteur actuel et candidat sur le même corpus. Tester HWND enfant avec Tauri/WebView2, redimensionnement, DPI, menus au-dessus de la vidéo, focus, plein écran, GPU, callbacks, libération, taille du paquet et machine sans VLC. Aucune fenêtre vidéo orpheline ne doit apparaître.

Étudier l’exécution dans le processus principal ou un processus isolé contre les plantages. Livrer une décision motivée, inventaire des dépendances, mesures et tableau succès/échecs. Si libVLC est inadapté, étudier un autre moteur comme libmpv dans une décision distincte ; ne pas changer silencieusement le choix.

| ID | Priorité | Exigence | Critère de réception |
|---|---|---|---|
| WIN-01 | P1 | Lecture native intégrée | Média reste dans Miarina sans VLC installé séparément |
| WIN-02 | P0 | Corriger écrans blancs/erreurs trompeuses | Chargement/accès/décodage distingués ; reprise et secours externe utiles |
| WIN-03 | P1 | Plein écran de fenêtre/écran | Sidebar/titre masqués, image ajustée ; Échap restaure géométrie et commandes |
| WIN-04 | P1 | Ouvrir fichier/dossier, glisser-déposer | Unicode, espaces, chemins longs dans limites supportées ; erreur d’accès claire |
| WIN-05 | P1 | Pistes audio et sous-titres internes | Liste langues/libellés et changement conservant position |
| WIN-06 | P1 | Sous-titres externes SRT/VTT | Chargement/désactivation, accents et délai ajustable |
| WIN-07 | P2 | ASS/SSA et styles | Support annoncé selon moteur et corpus, limites précisées |
| WIN-08 | P2 | Synchronisation audio/sous-titres | Décalages visibles, reset, pas de modification du fichier |
| WIN-09 | P2 | Chapitres, ratio et recadrage | Chapitres si présents ; ratio original accessible |
| WIN-10 | P2 | Vitesse 0,25× à 3× et boucle A–B | Bornes validées, reset et limites du moteur gérées |
| WIN-11 | P1 | Raccourcis | Espace, flèches, volume, F/Échap ; pas de conflit en saisie texte |
| WIN-12 | P2 | Sortie audio et décodage matériel | Périphérique retiré géré ; repli logiciel testé |
| WIN-13 | P2 | Fenêtre compacte toujours visible | Mode explicite, retour/fermeture cohérents, un seul lecteur |
| WIN-14 | P2 | Associations de fichiers facultatives | Choix utilisateur, respect du système ; aucune association imposée |
| WIN-15 | P3 | Flux réseau utilisateur | HTTP(S) d’abord, timeout, secrets masqués ; autres protocoles étudiés séparément |

### Corpus cible — pas de promesse universelle

| Famille | Priorité | Extension ultérieure |
|---|---|---|
| Vidéo | MP4/H.264/AAC, MKV/H.264, WebM/VP9/Opus | HEVC, AV1, MPEG-2, AVI selon build et matériel |
| Audio | MP3, FLAC, WAV/PCM, M4A/AAC, Ogg/Opus | Autres après validation des modules |
| Sous-titres | SRT UTF-8, WebVTT, pistes internes courantes | ASS/SSA avancés et formats image selon moteur |
| Cas particuliers | Multipistes, vidéo sans audio, VFR, longue durée | HDR, 4K, 10 bits après recette matérielle |

L’extension de fichier n’est pas le codec. Afficher les informations techniques réelles et conserver les cas échoués dans le rapport de compatibilité.

## 7. Téléchargements et navigateur intégré

| ID | Priorité | Exigence | Critère de réception |
|---|---|---|---|
| DL-01 | P0 | État durable et exact | Après arrêt : partiels/terminés cohérents ; jamais terminé avant finalisation |
| DL-02 | P1 | Reprise selon source | Range accepté/refusé, ETag changé et URL expirée testés ; jamais concaténation corrompue |
| DL-03 | P1 | Concurrence et annulation | Tâches/conversions bornées, workers et temporaires libérés |
| DL-04 | P0 | Stockage et noms | Disque plein, accès refusé, conflit : aucun écrasement silencieux |
| DL-05 | P1 | MP3 128/192/256/320 et FLAC si supporté | Options reliées au moteur ; ffprobe et décodage complet du résultat |
| DL-06 | P1 | Progression honnête | Téléchargement et conversion distingués ; pas de pourcentage inventé |
| DL-07 | P2 | Playlists de téléchargement | Aperçu, sélection, limite, ordre, échecs réessayables individuellement |
| DL-08 | P2 | Sous-titres téléchargeables | Langues/formats sélectionnables et association au bon média |
| DL-09 | P1 | Android en arrière-plan | Services/notifications adaptés ; Doze, batterie et arrêt système testés |
| DL-10 | P2 | Réseau mesuré/Wi-Fi | Règle appliquée par le moteur ; dépassement explicite, pas simple toggle |
| DL-11 | P2 | HTTP segmenté MDM | Activer après tests crash/reprise/finalisation/no-overwrite et octets exacts |
| DL-12 | P1 | Limites fournisseurs | Connexion/DRM/live non supportés expliqués ; pas de promesse tous sites |
| NAV-01 | P1 | Navigation dans fenêtre principale | Aucune fenêtre native incontrôlée ; exceptions explicites |
| NAV-02 | P2 | Onglets | Création/fermeture/changement/restauration ; grille Android, barre Windows, budget mémoire |
| NAV-03 | P2 | Historique et favoris | Local, recherche et effacement sans supprimer les médias |
| NAV-04 | P1 | Détection fiable | Média et page d’origine cohérents ; pas de bouton promettant un flux non supporté |
| NAV-05 | P1 | Coordination surfaces natives | Dialogues, clavier, lecteur et navigateur ne recouvrent pas les actions essentielles |

## 8. Extension, torrents et intégration MDM

Chaque capacité MDM doit disposer de son propre parcours, de sa persistance et de tests ; la présence du sous-module ne suffit pas.

| ID | Priorité | Exigence | Critère de réception |
|---|---|---|---|
| EXT-01 | P1 | Assistant Chrome/Edge | Appairage, test connexion et diagnostic hôte manquant ; pas de registre manuel |
| EXT-02 | P2 | Distribution magasins | Paquets/notices/validation ; accès comptes et publication à traiter explicitement |
| EXT-03 | P1 | Envoi manuel fiable | App ouverte/fermée, page/lien/média, doublons et messages invalides |
| EXT-04 | P3 | Capture automatique optionnelle | Consentement, exclusions, arrêt facile ; pas de collecte globale des cookies |
| TOR-01 | P1 | Torrent/magnet Windows robuste | Métadonnées lentes, aucun pair, reprise, redémarrage et retrait conservant fichiers |
| TOR-02 | P1 | Partage visible et maîtrisé | Montant/quantité, pause/arrêt session ; activité après achèvement expliquée |
| TOR-03 | P2 | Ratio et durée de partage | Seuils persistants, unités claires, arrêt effectif |
| TOR-04 | P2 | Import média terminé | Choix utilisateur, fichier complet, pas de déplacement des fichiers partagés |
| TOR-05 | P3 | RSS | Aperçu, filtres, limites et déduplication ; automatisation explicitement activée |
| TOR-06 | P3 | Lecture avant achèvement | Étude conteneur/mode séquentiel ; désactiver si lecture sûre impossible |
| MDM-01 | P3 | FTP(S), galeries, packages | Un sous-lot par capacité avec credentials, sélection et reprise |
| MDM-02 | P3 | Extraction archives | Chemins, quotas, liens, bombes de décompression ; dossier dédié |
| MDM-03 | P3 | Planification | Persistance/fuseaux ; extinction/réveil sur demande explicite |
| MDM-04 | P3 | Proxy, débridage, contrôle distant/API/MCP | Études séparées, secrets protégés, authentification et périmètre réseau |

Torrents Android non requis pour la première amélioration du lecteur : éventuel portage séparé, avec budget batterie, stockage et réseau.

## 9. Mises à jour et distribution

| ID | Priorité | Exigence | Critère de réception |
|---|---|---|---|
| UPD-01 | P0 | Recette réelle entre deux versions | Versions de test isolées ; base/fichiers/playlists préservés et version après relance vérifiée |
| UPD-02 | P0 | Authenticité obligatoire | Fausse signature, manifeste altéré/trop grand, URL étrangère, hash incorrect/troncature refusés |
| UPD-03 | P1 | Annulation/reprise et cache prêt | Validateur ressource, état retrouvé après relance, nettoyage maîtrisé |
| UPD-04 | P1 | Installation au bon moment | Pas pendant conversion ; tâches/partage/lecture traités explicitement avec l’utilisateur |
| UPD-05 | P2 | Téléchargement automatique configurable | Off par défaut initialement, règles réseau/batterie ; installation jamais forcée |
| UPD-06 | P1 | Android arrière-plan et permission | Service adapté, retour des paramètres, refus/annulation sans perte du fichier prêt |
| UPD-07 | P1 | Clés et canaux | Sauvegarde privée, rotation documentée, stable/bêta distincts |
| UPD-08 | P0 | Publication cohérente | Artefacts vérifiés avant manifeste, anciennes versions conservées, liens valides |
| UPD-09 | P2 | Authenticode Windows | Étude certificat/coût/procédure ; distinct de la signature du manifeste |
| UPD-10 | P0 | Échec de migration/retour arrière | Sauvegarde base et récupération ; pas de downgrade sur schéma incompatible |

La 0.1.7 doit être installée manuellement depuis la 0.1.6. Le parcours actuel ouvre l’installateur système depuis Miarina ; « dans l’app » ne veut pas dire installation silencieuse. Tester la mise à jour sur un canal de test, jamais en inventant une nouvelle version sur le canal public.

## 10. Interface, langues et accessibilité

- **UX-01 P1 :** catalogue centralisé français/anglais, aucun mélange involontaire dans les écrans livrés.
- **UX-02 P1 :** design Miarina commun adapté tactile/souris ; maquettes avant nouveau parcours.
- **UX-03 P1 :** chargement/vide/hors-ligne/erreur, action utile et libellés compréhensibles.
- **UX-04 P1 :** clavier, focus visible, TalkBack et Narrator sur parcours essentiels.
- **UX-05 P1 :** contraste clair/sombre, agrandissement texte, petits écrans, cibles tactiles ; couleur jamais seule information.
- **UX-06 P2 :** options avancées regroupées, fonctions futures non présentées comme actives.
- **UX-07 P1 :** focus et dialogues corrects au-dessus des surfaces vidéo/WebView natives.
- **WEB-01 P1 :** site/FAQ/changelog basés sur versions réelles ; fonctions présentes, validées et prévues distinguées.

Recette : téléchargement, lecteur, erreur et mise à jour dans les deux langues/thèmes, au clavier et avec texte agrandi. Ne pas revendiquer de certification d’accessibilité sans audit.

## 11. Architecture et données

### Responsabilités

- React : présentation et commandes ; aucune autorité sur chemins/signatures.
- Rust : validation, métier, stockage, orchestration et commandes Tauri limitées.
- Android : service/session, moteur, audio focus, contrôles système, stockage et permissions.
- Windows : moteur natif retenu, surface, pistes, callbacks et libération.
- SQLite : bibliothèque, playlists, file de lecture, positions, préférences et migrations.

### Contrat lecteur à figer avant migration

Commandes minimales : `load`, `play`, `pause`, `stop`, `seek`, `setVolume`, `setRate`, `selectAudioTrack`, `selectSubtitle`, `setQueue`, `next`, `previous`, `dispose`.

État : ID média/instance, idle/loading/ready/playing/paused/buffering/ended/error, position, durée éventuellement inconnue, capacité seek, pistes et capacités natives, erreur structurée. Une réponse asynchrone obsolète ne doit pas remplacer le média courant. Limiter la fréquence des événements de position ; interpolation UI possible sans inventer de progression de téléchargement.

### Données conceptuelles

| Entité | Informations principales |
|---|---|
| Média | ID, fichier/URI, type, métadonnées, disponibilité |
| Playlist | ID, nom, dates ; éléments référencés et ordre |
| File de lecture | Session, média courant, ordre, répétition/aléatoire |
| Position | Média, position, date, lecture achevée |
| Préférences lecteur | Moteur/capacités, vitesse, égaliseur, comportement plateforme |
| Migration | Version du schéma et procédure de récupération |

Réutiliser les tables existantes lorsque pertinent ; noms ci-dessus non imposés. Définir la règle de doublon dans une playlist. Toute migration doit être testée depuis la base publiée, transactionnelle autant que possible, sauvegardée et récupérable. Les caches/pochettes sont bornés, reconstructibles et générés hors thread UI.

## 12. Sécurité, confidentialité et dépendances

- **SEC-01 P0 :** aucune commande privilégiée accessible aux pages distantes du navigateur intégré.
- **SEC-02 P0 :** validation URI/chemins/liens symboliques/entrées extension ; limites de taille et fréquence.
- **SEC-03 P0 :** médias, playlists, sous-titres et archives considérés non fiables ; composants maintenus et versions épinglées.
- **SEC-04 P1 :** journaux locaux sans cookies/tokens/URL signées ; export volontaire et aperçu avant partage.
- **SEC-05 P1 :** permissions minimales et révocables ; utiliser MediaStore/SAF lorsque suffisant au lieu d’un accès global aux fichiers.
- **SEC-06 P1 :** aucune télémétrie ajoutée implicitement ; services réseau et diagnostics explicités.
- **DEP-01 P1 :** nomenclature des composants, provenance, versions, hashes et notices de chaque build.
- **DEP-02 P1 :** compléter les sources correspondant aux dépendances natives distribuées ; l’archive applicative seule n’atteste pas un ensemble complet.
- **DEP-03 P1 :** examiner le bundle libVLC exact, ses modules, linkage, sources et notices ; ne pas attribuer automatiquement une licence unique à toutes les DLL.
- **DEP-04 P1 :** préserver la marque Miarina ; références Lark/VLC sans revendication de partenariat.

Ce CDC prescrit une vérification des licences et des sources effectivement utilisées, sans constituer une attestation juridique de conformité.

## 13. Performances et compatibilité

### Objectifs proposés, à confirmer au lot de référence

Ces chiffres sont des seuils de recette proposés, pas des performances mesurées. Consigner matériel, OS, build, corpus et méthode ; modifier un seuil seulement avec justification documentée.

| Mesure | Cible initiale | Conditions |
|---|---|---|
| Premier son/image local | p95 ≤ 2 secondes | Fichier complet courant, hors scan ; 20 essais ; froid et chaud séparés |
| Réponse visuelle play/pause | p95 ≤ 200 ms | 30 actions ; distinguer retour UI et effet natif |
| Seek local indexé | p95 ≤ 1 seconde | 20 positions ; gros fichiers/stockage lent consignés séparément |
| Recherche 10 000 médias | p95 ≤ 500 ms | Index prêt, pagination et saisie réactive |
| Endurance | Aucun crash/blocage sur 60 minutes | Lecture, navigation, changements de pistes sur chaque cible |
| Mémoire | Pas de croissance persistante inexpliquée | 20 ouvertures/fermetures puis repos ; ne pas exiger libération immédiate par allocateur |
| Batterie Android | Établir référence avant seuil définitif | 60 minutes audio verrouillé, réseau/casque constants ; comparaison version précédente |
| Taille | Écart mesuré et justifié | Référence 0.1.7, modules inclus ; étude APK ARM64 séparé |

### Matrice matérielle

- Windows 10/11 x64 : machine modeste avec GPU intégré et machine récente ; DPI 100/150/200 %, deux écrans, casque et sortie intégrée.
- Android : minimum 7 actuellement déclaré, version intermédiaire et récente. Au moins un ARM64 physique modeste et un récent ; émulateur pour complément.
- Inscrire les appareils réellement disponibles avant planification. Une ligne non exécutée reste « non validée ».
- Tests Bluetooth, batterie et restrictions constructeur ne sont pas validés par un émulateur.

## 14. Recette et qualité

### Corpus

Fichiers personnels, générés ou sous licence autorisant les tests. Enregistrer provenance/licence, SHA-256, conteneur/codecs, pistes, durée, taille et résultat attendu. Inclure fichiers vides/tronqués, métadonnées absentes, Unicode, multipistes et sous-titres décalés.

### Niveaux

1. Unitaires : états, signature/version, playlists, validation et migrations.
2. Intégration : octets transférés, reprise, persistance, incidents stockage et session.
3. UI : actions, états, erreurs, clavier et absence de doubles déclenchements.
4. Natif : vidéo, plein écran, focus audio, casque, permissions et installation.
5. Endurance : scénarios longs et performances, avec résultats bruts conservés.

| Test | Exigences liées | Preuve attendue |
|---|---|---|
| T-01 Lien → fichier → lecture sur deux plateformes | PAR-01, DL-01, COM-02 | Versions, étapes et hash résultat |
| T-02 MP3 et écran verrouillé | DL-05, AND-01/02/03/04 | Inspection/décodage fichier, appareil et événements audio |
| T-03 MKV multipistes, SRT et plein écran | WIN-01/03/05/06 | Capture, état avant/après et logs expurgés |
| T-04 Mort du processus/redémarrage | COM-04, AND-05, DL-01/02 | État durable, aucune corruption |
| T-05 Disque plein/permission révoquée | COM-08/10, DL-04 | Erreur utile, récupération et absence d’écrasement |
| T-06 Mise à jour et échecs simulés | UPD-01/02/04/10 | Versions installées, données avant/après, refus authentification |
| T-07 Extension réelle | EXT-01/03 | Chrome/Edge, app ouverte/fermée, entrées invalides |
| T-08 Torrent terminé → bibliothèque | TOR-01/02/04 | Octets exacts, partage maîtrisé et indexation |
| T-09 Langues/accessibilité | UX-01/04/05/07 | Checklist, appareils et anomalies |
| T-10 Endurance/performance | §13 | Méthode, mesures brutes et synthèse |

Gravité : critique = sécurité/perte de données ; majeure = parcours principal impossible ; mineure = gêne avec contournement. Avant publication, corriger les défauts critiques/majeurs connus du périmètre annoncé, ou retirer explicitement la fonction concernée. Le nombre de tests ne prouve pas à lui seul l’absence de bugs.

## 15. Lots de réalisation progressive

Efforts relatifs : S limité, M plusieurs composants, L chantier natif/architecture. Ce ne sont pas des estimations en jours. Les cases suivent l’acceptation du lot complet, pas le début du code.

| Suivi | Lot | Portée | Dépendances | Effort | Condition de sortie |
|---|---|---|---|---|---|
| [ ] | L00 — Référence | Bugs réels, corpus, appareils, mesures, audit des fonctions existantes | Aucune | M | Matrice initiale et défauts prioritaires |
| [ ] | L01 — Fiabilité | Corruption/reprise/stockage, lecture blanche et erreurs | L00 | L | Parcours essentiels et régressions testés |
| [ ] | L02 — Contrat et données | COM-01/03/04/06, migration et capacités moteur | L00 | M | Contrat stable, données et anciens parcours préservés |
| [ ] | L03 — Audio Android durable | AND-01 à AND-06, mini-lecteur et système | L01, L02 | L | T-02/T-04 sur téléphone réel et casque |
| [ ] | L04 — Prototype Windows | WIN-SPIKE, rendu libVLC, formats, modules/licences | L00, L02 | M | Décision technique avec mesures et limites |
| [ ] | L05 — Lecteur Windows | WIN-01 à WIN-06 et WIN-11 | L01, L04 accepté | L | T-03, machine sans VLC, installation validée |
| [ ] | L06 — Bibliothèque musicale | Albums/artistes/dossiers, playlists, import/export | L02, lecteur principal validé | M | Persistance, recherche et fichiers absents testés |
| [ ] | L07 — Confort Android | AND-07 à AND-14 ; fondu selon prototype | L03, L06 | L | Plein écran/PiP compatible et fonctions audio testés |
| [ ] | L08 — Windows avancé | WIN-07 à WIN-14 selon ordre de priorité | L05 | M | Corpus avancé et contrôles validés |
| [ ] | L09 — Mise à jour robuste | UPD-01 à UPD-08/10, reprise et cycle de vie | L01, coordination lecteurs | L | T-06, données préservées et sauvegarde de clé |
| [ ] | L10 — Téléchargements média | Qualités Android, playlists, sous-titres, réseau mesuré | L01, L02 | L | T-01/T-05 et conversions/playlist sélectionnée |
| [ ] | L11 — Navigateur/extension | Onglets/historique/appairage ; magasins en sous-lot | L01, coordination surfaces | L | T-07 et aucune superposition bloquante |
| [ ] | L12 — Torrents média | Fiabilité, limites partage et import bibliothèque | L01, L06 | M | T-08 et arrêt du partage vérifiés |
| [ ] | L13 — Finition diffusion | Langues, accessibilité, sources natives, perf, packaging | Lots retenus | L | T-09/T-10 et recette de publication |
| [ ] | L14 — MDM avancé | Sous-lots séparés MDM-01 à MDM-04 et TOR-05/06 | L13 et études dédiées | L | Chaque fonction a son périmètre et ses preuves |

**Ordre conseillé en solo :** L00 → L01 → L02 → L03 → L04 → L05 → L06 → L09 → L07/L08 → L10 → L11 → L12 → L13. L04 peut être étudié en parallèle de L03 par une autre personne, mais éviter des migrations concurrentes du contrat lecteur. Les bugs P0 interrompent cet ordre. Sécurité, langues et accessibilité sont traitées dans chaque lot, pas repoussées entièrement à L13.

**Première étape concrète :** L00 ; puis AND-01/02 pour la musique Android et WIN-SPIKE pour Windows. Ne pas commencer par tous les protocoles MDM ni par une refonte purement graphique.

## 16. Livrables, publication et fiche de suivi

### Définition de terminé par lot

- [ ] Périmètre avec IDs inclus/exclus et dépendances.
- [ ] Diagnostic/architecture et maquette lorsque nécessaire.
- [ ] Code, migrations et notices revus ; aucun secret ni donnée privée versionné.
- [ ] Tests pertinents exécutés, preuves consultables.
- [ ] Recette native sur le matériel requis ; limites non testées explicites.
- [ ] Guide utilisateur et capacités plateforme actualisés.
- [ ] Récupération/retour arrière documenté pour moteur ou données.
- [ ] Commit autonome et push, révision/build enregistrés.
- [ ] Publication si prévue et autorisée ; une étude peut être validée sans nouvelle release.

### Publication

Vérifier versions, hashes, signatures/certificats, contenu du paquet et migrations. Envoyer les artefacts avant le manifeste signé ; sauvegarder le site ; conserver la version précédente ; vérifier les URLs publiques. Mettre à jour landing/changelog/sources et préciser le matériel testé. Ne pas annoncer un test téléphone à partir d’un simple build ou d’un émulateur.

### Fiche à copier pour travailler petit à petit

```markdown
# Fiche LOT-XX — Titre
- Statut : À faire
- Exigences CDC :
- Version de départ / commit :
- Objectif utilisateur :
- Inclus :
- Exclus :
- Dépendances :
- Décision technique / maquette :
- Risques et données concernées :
- Travail :
  - [ ] Diagnostic
  - [ ] Implémentation
  - [ ] Tests automatisés pertinents
  - [ ] Recette native
  - [ ] Documentation
- Tests (appareil, OS, build, fichier, résultat) :
- Critères de réception satisfaits :
- Défauts / limites restantes :
- Retour arrière / récupération :
- Commit et preuves :
- Publication : non prévue / candidate / publiée (version)
- Prochaine petite étape :
```

Exemple de demande : « Réaliser L03, uniquement AND-01 et AND-02, en conservant le lecteur existant et sans publier avant recette ». Mettre à jour la fiche et les statuts après chaque étape.

## 17. Risques, décisions ouvertes et hors périmètre

| Sujet | Risque ou décision | Réponse attendue |
|---|---|---|
| libVLC/Tauri | HWND, focus, z-order, GPU, crash, sorties multiples | Prototype et choix processus principal/isolé |
| Service Android | Arrêt constructeur, focus, permission, batterie | Lifecycle natif et matrice réelle |
| Taille des paquets | Moteurs et outils lourds | Mesure avant/après, modules sélectionnés, APK par ABI étudié |
| Formats | Différences matériel/build | Corpus précis ; pas de promesse universelle |
| Accès fichiers | URI révoquée, média déplacé | Références persistantes et relocalisation |
| Sources natives | Inventaire incomplet | Clore DEP-01/02 avant qualifier la distribution de reproductible |
| Signature Windows | Certificat, coût, accès | Proposition actualisée puis décision propriétaire |
| Langues | Français prioritaire proposé, anglais conservé | Catalogue validé ; malgache éventuel après traduction qualifiée |
| Matériel | Appareils non garantis disponibles | Identifier modèles et responsables ; ne pas valider sans essai |
| Périmètre | Trop de fonctions fragiles simultanément | Un lot actif en solo et priorité usages quotidiens |

Hors première livraison : cloud et synchronisation, sauvegarde Drive, publicité/monétisation, magasin de contenus, DRM, casting/DLNA, Android Auto/TV, édition vidéo complète, sonneries, télécommande publique, portages iOS/macOS/Linux. Ajouter ces besoins par avenant testable ; « comme Lark/VLC » ne les inclut pas automatiquement.

## 18. Références et portée des sources

### Dépôt Miarina

- [Analyse comparative](competitive-positioning-2026-11-11.md)
- [Versions et validations](test-builds.md)
- [Audit](archive/prebuild-audit-2026-11-09.md)
- [Validation Android](android-extractor-validation.md)
- [Lecture Windows](archive/desktop-playback-validation.md)
- [Mises à jour](app-updates.md)
- [Inventaire MDM](integrations/misterdownloadmanager.md)
- [Performances historiques](performance.md)
- [Architecture historique](architecture.md) : confronter au code actuel.

### Sources officielles consultées le 11 novembre 2026

- [Lark Player](https://www.larkplayer.com/) : référence d’expérience musicale, déclarations éditeur non auditées ici.
- [Android Media3 : lecture en arrière-plan](https://developer.android.com/media/media3/session/background-playback) : service et MediaSession ; adapter aux SDK retenus.
- [Documentation libVLC](https://videolan.videolan.me/vlc/master/libvlc.html) : moteur intégrable ; documentation de développement, vérifier version stable choisie.
- [API libVLC 3](https://videolan.videolan.me/vlc-3.0/group__libvlc__media__player.html) : surface native et commandes ; vérifier ABI exacte.
- [Sources VideoLAN](https://github.com/videolan/vlc) : versions et licences à examiner pour le bundle distribué.

Ce CDC prescrit des améliorations. Il n’atteste ni leur réalisation ni une parité totale avec les produits de référence. Chaque extension doit garder ses critères de recette et sa propre étape de livraison.
