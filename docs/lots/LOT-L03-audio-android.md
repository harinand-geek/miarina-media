# Fiche LOT-L03a — Audio Android durable (service de lecture)

- Statut : À tester (recette téléphone ARM64 obligatoire, CDC §5)
- Exigences CDC : AND-01 (service indépendant de l'écran), AND-02 (MediaSession + notification), AND-03 (focus audio, appel, retrait du casque), AND-04 (Bluetooth, écran verrouillé), AND-05 (file confiée au natif ; reprise après redémarrage sans son surprise ; reconnexion à une lecture toujours en cours)
- Version de départ / commit : voir git log (après `0b3f2a4`)
- Objectif utilisateur : la musique continue écran verrouillé et en changeant d'app, avec les commandes système, et enchaîne les titres de la file.
- Inclus :
  - `PlaybackService` (Media3 `MediaSessionService`) propriétaire d'ExoPlayer : attributs audio musique, gestion du focus audio, pause au retrait du casque (`becoming noisy`), wake lock local, retour à l'app depuis la notification, arrêt si l'app est balayée alors que rien ne joue.
  - `NativePlayerPlugin` devient un contrôleur (`MediaController`) : file complète avec métadonnées (titre, artiste, album, pochette) pour la notification et l'écran verrouillé ; saut, file réordonnée sans interruption, répétition native.
  - Rust : `player_open(ids, index, position)` résout chaque entrée depuis la bibliothèque (jamais de chemin venant de la page, file bornée à 500, fichiers absents écartés) ; nouvelles commandes `player_queue`, `player_skip`, `player_repeat` ; statut avec `index` et `mediaId`.
  - JS : une session native par file ; l'interface suit le titre courant du service (avance automatique, boutons système) et transmet saut, ordre, aléatoire, répétition ; un saut demandé par l'interface attend la confirmation du service (2 s max).
  - Manifest : service `mediaPlayback` exporté pour les contrôleurs système, permission `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- Exclus : MediaStore/SAF (AND-06), égaliseur, vitesse dans la notification, vidéo plein écran natif (L07), minuteur « fin du titre » fiable écran verrouillé (il dépend du JS : la pause intervient au retour à l'écran si le JS est suspendu).
- Dépendance ajoutée : `media3-session` 1.11.1 (Apache-2.0).
- Risques : comportement constructeur (arrêt agressif des services), batterie, focus audio pendant un appel — non vérifiables sans téléphone.
- Tests :
  - `cargo test --lib player` (bornes de file et de répétition), `cargo check` desktop et `--target aarch64-linux-android`.
  - Gradle `:app:compileUniversalDebugKotlin` : OK.
  - Front : `tsc`, `eslint`, `vitest` (session native simulée : file transmise, suivi du service, saut confirmé, file réordonnée, répétition, minuteur fin de titre).
  - Émulateur : voir la section « Essai émulateur » ci-dessous.
  - Non testé : téléphone physique, Bluetooth, appel entrant, retrait du casque, 30 min écran verrouillé, restrictions constructeur.
- Retour arrière : revert du commit (le lecteur revient dans l'activité, sans service).

## Essai émulateur (2026-11-11)

Émulateur Android 15 x86_64 (`voakajy_test`), APK release x86_64 signé avec la clé de publication, installé par-dessus la 0.1.7 de recette (données conservées).

| Vérification | Résultat |
|---|---|
| Téléchargement d'un MP3 libre (SoundHelix) depuis l'app, visible dans Musique | OK |
| Lecture : session Media3 active, `PLAYING`, métadonnées du titre | OK (`dumpsys media_session`) |
| Notification média au premier plan (`category=transport`, 3 actions) | OK |
| Écran éteint 30 s : la lecture continue | OK (position 60,1 s après 60,1 s, dont 30 s écran éteint) |
| Touche système « suivant » (équivalent bouton casque/Bluetooth) | OK : le service passe au titre suivant de la file |
| App en arrière-plan 20 s | OK (lecture continue) |
| Carte média du volet : titre, pochette, précédent / pause / suivant | OK (capture) |
| Retour dans l'app : l'écran « En lecture » suit le titre choisi par le service | OK |
| Touche système « pause » | OK (`PAUSED`) |

Non vérifiable sur émulateur : Bluetooth réel, appel entrant, retrait du casque, batterie, restrictions constructeur, 30 minutes écran verrouillé. Recette téléphone ARM64 toujours obligatoire.

## AND-05 — reprise (ajout du 2026-11-11)

- La file Android (titres, titre courant, source, répétition) est enregistrée localement (`mm:mobile:session:v1`, bornée à 500 entrées) ; les positions l'étaient déjà.
- Au lancement : si le service joue encore un titre de cette file (app balayée pendant la lecture), l'interface s'y rebranche sans rouvrir ni redémarrer le son ; sinon la file revient dans le mini-lecteur, **en pause**, et le premier appui sur Lecture l'ouvre à la position enregistrée.
- `status` se connecte au service si besoin (sinon une lecture en cours serait invisible après réouverture) ; au lancement, l'attente est bornée à 3 s, après quoi la file est proposée en pause.
- La position du titre en cours est enregistrée toutes les 5 s pendant la lecture et au passage en arrière-plan : après un arrêt du processus, la reprise se fait au plus ~5 s en arrière (avant : position 0).
- Retour sur l'écran d'accueil met l'app en arrière-plan (comme la touche Accueil) au lieu de fermer l'activité : la fermeture de l'activité terminait le processus et coupait la musique et les téléchargements (`MainActivity`, rappel placé sous celui de Tauri).
- Fermer le lecteur efface la session enregistrée.

### Essai émulateur AND-05 (2026-11-11, APK release x86_64)

| Scénario | Résultat |
|---|---|
| Lecture, arrêt forcé (`am force-stop`), réouverture | OK : mini-lecteur sur le bon titre, **en pause**, aucun son ; Lecture rouvre la file |
| Reprise de position après arrêt forcé (lecture à ~23 s) | OK : reprise à 19 s (dernier enregistrement périodique) |
| Retour depuis l'accueil pendant la lecture | OK après correctif : app en arrière-plan, même processus, lecture continue (avant : processus terminé, musique coupée) |
| Réouverture pendant la lecture | OK : mini-lecteur en « Pause », la lecture n'est ni relancée ni interrompue |
| Tâche retirée des applis récentes pendant la lecture | **Limite** : la destruction de l'activité fait planter le processus (SIGSEGV dans le GPU de la WebView, `pthread_mutex_lock called on a destroyed mutex`) ; la musique s'arrête, puis la file revient en pause à la réouverture. Le cas « service toujours actif → rattachement » est couvert par les tests unitaires mais pas observable tant que ce plantage existe. À traiter dans un lot dédié (service dans un processus séparé ou correctif Tauri/WebView). |

Incident d'environnement : sur cet émulateur, le journal LevelDB du stockage local de la WebView contenait une zone de zéros (écriture interrompue antérieure) ; Chromium ignorait tout ce qui suivait, donc aucune donnée locale récente (session, positions) ne survivait au redémarrage. Stockage local de l'app de test réinitialisé (`Local Storage` supprimé, appli arrêtée) avant les essais ci-dessus. Le même risque existe sur téléphone après une coupure brutale : la reprise reste « au mieux », jamais bloquante.

## APK de test téléphone

`builds/test/MiarinaMedia-0.1.7-L03-arm64-test.apk` (ARM64, signé clé de publication, 70 001 748 octets, SHA-256 `efdd4b6f70e5f7d9310716a7148cdcd95e4ae76e139c63d2a61999946a7caabf`) — correspond au commit `e025417` (sans la reprise AND-05). S'installe par-dessus la 0.1.7 publiée. Version affichée : 0.1.7 (build de test, ne pas publier).

Recette proposée (téléphone ARM64 physique) :
1. Lire un titre de Musique avec « Tout lire », verrouiller 30 min : la musique continue, les titres s'enchaînent.
2. Écran verrouillé : pause / suivant / précédent depuis les commandes système.
3. Casque Bluetooth : bouton lecture/pause et suivant.
4. Appel entrant pendant la lecture : pause pendant l'appel, pas de reprise intempestive.
5. Retrait du casque filaire ou déconnexion Bluetooth : pause.
6. Changer d'app 30 min (navigation, messagerie) : la musique continue.
7. Noter le modèle, la version Android et la consommation batterie affichée.
