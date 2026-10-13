# Miarina Media — Faisabilité Android (analyse Phase 0, à valider par un spike en Phase 4)

> Rien ici n'est validé sur appareil. Ce document liste les options, les inconnues et le protocole de validation. **Aucune parité de fonctionnalités avec Windows n'est promise.**

## 1. Ce qui ne fonctionne PAS tel quel sur Android

- `yt-dlp.exe` et `ffmpeg.exe` sont des binaires Windows : inutilisables.
- yt-dlp est un programme **Python** : il faut un interpréteur Python embarqué (par ABI) ou un extracteur alternatif.
- Lancer des processus arbitraires est fortement restreint (exécution depuis le stockage de l'app interdite depuis Android 10 / `targetSdk ≥ 29` ; les binaires doivent être livrés comme bibliothèques natives `lib*.so` dans `jniLibs`).
- Le runtime Tauri est lié à l'Activity ; **un téléchargement long ne peut pas reposer sur la WebView ni sur l'Activity** au premier plan.

## 2. Options d'extraction

| Option | Couverture | Licence | Taille estimée (à mesurer) | Mises à jour des extracteurs | Verdict provisoire |
|---|---|---|---|---|---|
| **A. youtubedl-android** (yt-dlp + Python + FFmpeg packagés pour Android) | ~ celle de yt-dlp | **GPL-3.0** (vérifié) → l'app Android entière devrait être distribuée sous licence compatible GPL | Python + yt-dlp + FFmpeg : plusieurs dizaines de Mo **par ABI** | la bibliothèque sait mettre à jour yt-dlp à l'exécution — **incompatible avec la politique Google Play** (téléchargement de code exécutable) | Candidat principal hors Play Store |
| **B. Chaquopy** (Python embarqué, open source) + yt-dlp en pur Python + FFmpeg séparé | ~ celle de yt-dlp | Chaquopy MIT ; yt-dlp Unlicense ; FFmpeg LGPL/GPL selon build | comparable à A | mise à jour = nouvelle version de l'app (ou même problème de politique) | Alternative si la contrainte GPL de A est refusée |
| **C. NewPipeExtractor** (Java) | quelques services seulement | GPL-3.0 | faible | fréquentes | Trop limité pour le produit visé |
| **D. Moteur HTTP direct** (Rust `HttpEngine`, partagé avec Windows) | liens directs vers fichiers média uniquement | — | négligeable | aucune | **Faisable sans risque**, socle minimal Android |

Recommandation : **D d'abord** (vertical slice Android sûr), puis **spike A vs B** mesurant taille, temps d'analyse, mémoire et succès sur un panel d'URLs autorisées.

## 3. FFmpeg sur Android

- Nécessaire pour fusionner audio/vidéo DASH et convertir en MP3/FLAC ; facultatif si l'on se limite aux formats progressifs (MP4 audio+vidéo déjà multiplexés) et à l'audio d'origine (M4A/Opus).
- `ffmpeg-kit` (projet historique) a été **archivé** par son auteur (2025) : à éviter ou à reprendre via un fork maintenu → à évaluer.
- Alternative partielle : `MediaMuxer` / `MediaExtractor` Android natifs pour le **remux** MP4 (pas de transcodage MP3/FLAC) — zéro surcoût de taille.
- Proposition : MVP Android = remux natif + audio d'origine ; conversion MP3/FLAC Android seulement si le spike la justifie.

## 4. Taille de l'application

- Chaque composant natif est multiplié par le nombre d'ABI (`arm64-v8a`, `armeabi-v7a`, `x86_64`).
- Mesures à faire : APK universel vs **AAB** avec découpage par ABI (Play) vs APK par ABI (distribution directe).
- Hypothèse de cible : ne livrer que `arm64-v8a` (+ `x86_64` pour l'émulateur en debug) — à valider selon le parc visé (Madagascar : beaucoup d'appareils d'entrée de gamme, potentiellement `armeabi-v7a` → **à décider**).

## 5. Téléchargements en arrière-plan

| Mécanisme | Adéquation | Contraintes |
|---|---|---|
| **User-initiated data transfer job** (`JobScheduler`, Android 14 / API 34+) | Conçu exactement pour les téléchargements lancés par l'utilisateur | permission `RUN_USER_INITIATED_JOBS`, notification obligatoire, API 34+ seulement |
| Foreground service type `dataSync` | Fonctionne sur API < 34 | **limite de 6 h / 24 h sur Android 15**, déclaration Play Console requise |
| WorkManager (long-running worker) | Bonne gestion des contraintes (Wi-Fi, batterie) et des redémarrages | s'appuie sur un foreground service en interne ; mêmes limites |

Proposition : user-initiated jobs sur API 34+, WorkManager + foreground service `dataSync` en repli pour les versions antérieures. Le design prévoit déjà la notification de progression (Pause / Cancel / Pause all), « Download complete » et « Waiting for Wi-Fi · Use data » (> 100 MB sur données mobiles).

**Point d'architecture critique** : quand l'Activity est détruite, le code Rust/Tauri ne doit pas être indispensable à la poursuite du téléchargement. Deux options, à trancher par le spike :
1. **Kotlin propriétaire de l'exécution** : le service exécute le téléchargement, persiste sa progression dans un journal local léger ; le core Rust réconcilie la base SQLite au retour de l'app.
2. **Rust appelé depuis le service** : la bibliothèque Rust (`.so`) est chargée dans le processus et le service appelle le moteur via JNI, indépendamment de l'Activity. Plus de code partagé, mais intégration plus risquée avec le runtime Tauri.

## 6. Stockage

- Destination par défaut : `MediaStore` (`Download/Miarina`, `Movies`, `Music`) — pas de permission nécessaire depuis Android 10.
- Dossier choisi par l'utilisateur (dont carte SD, design « Save to » Internal / SD card) : **SAF** `ACTION_OPEN_DOCUMENT_TREE` + permission persistante ; écriture via `ContentResolver` (pas de chemins bruts).
- La bibliothèque stocke des **content URIs** ; vérification d'existence par requête `ContentResolver`.
- Aucune permission `MANAGE_EXTERNAL_STORAGE`.

## 7. Distribution et politique Google Play

- Google Play interdit les applications qui facilitent le téléchargement non autorisé de contenus de services tiers (en particulier YouTube) ; les applications de ce type (dont SnapTube) sont distribuées **hors Play Store**.
- Conséquence probable : distribution **APK directe** (site media.miarina.org) et/ou F-Droid, signature et mises à jour gérées par MIARINA.
- Décision business à prendre avant la Phase 4 (cf. `phase-0-report.md`, question Q4).

## 8. Protocole du spike (Phase 4.0)

1. Prérequis : Rust + cibles Android, NDK 27 (installé), appareil physique API 34+ et un appareil API 29–33.
2. Application Tauri minimale + plugin Kotlin : `HttpEngine` vers MediaStore avec notification et user-initiated job ; tuer l'Activity pendant un téléchargement de 1 Go ; vérifier poursuite, reprise, état final en base.
3. Intégration A puis B : analyse de 20 URLs de test autorisées (domaines publics/CC), mesure taille APK par ABI, RAM, temps d'analyse à froid.
4. Remux natif `MediaMuxer` d'une paire vidéo+audio DASH.
5. Lecture Media3 d'un fichier issu d'un content URI SAF, notification média, PiP.
6. Rapport chiffré dans ce document ; décision go / no-go par fonctionnalité.
