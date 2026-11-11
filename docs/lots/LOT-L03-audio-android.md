# Fiche LOT-L03a — Audio Android durable (service de lecture)

- Statut : À tester (recette téléphone ARM64 obligatoire, CDC §5)
- Exigences CDC : AND-01 (service indépendant de l'écran), AND-02 (MediaSession + notification), AND-03 (focus audio, appel, retrait du casque), AND-04 (Bluetooth, écran verrouillé), AND-05 partiel (file confiée au natif ; restauration après mort du processus non faite)
- Version de départ / commit : voir git log (après `0b3f2a4`)
- Objectif utilisateur : la musique continue écran verrouillé et en changeant d'app, avec les commandes système, et enchaîne les titres de la file.
- Inclus :
  - `PlaybackService` (Media3 `MediaSessionService`) propriétaire d'ExoPlayer : attributs audio musique, gestion du focus audio, pause au retrait du casque (`becoming noisy`), wake lock local, retour à l'app depuis la notification, arrêt si l'app est balayée alors que rien ne joue.
  - `NativePlayerPlugin` devient un contrôleur (`MediaController`) : file complète avec métadonnées (titre, artiste, album, pochette) pour la notification et l'écran verrouillé ; saut, file réordonnée sans interruption, répétition native.
  - Rust : `player_open(ids, index, position)` résout chaque entrée depuis la bibliothèque (jamais de chemin venant de la page, file bornée à 500, fichiers absents écartés) ; nouvelles commandes `player_queue`, `player_skip`, `player_repeat` ; statut avec `index` et `mediaId`.
  - JS : une session native par file ; l'interface suit le titre courant du service (avance automatique, boutons système) et transmet saut, ordre, aléatoire, répétition ; un saut demandé par l'interface attend la confirmation du service (2 s max).
  - Manifest : service `mediaPlayback` exporté pour les contrôleurs système, permission `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- Exclus : restauration de la file après mort du processus (AND-05), MediaStore/SAF (AND-06), égaliseur, vitesse dans la notification, vidéo plein écran natif (L07), minuteur « fin du titre » fiable écran verrouillé (il dépend du JS : la pause intervient au retour à l'écran si le JS est suspendu).
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
