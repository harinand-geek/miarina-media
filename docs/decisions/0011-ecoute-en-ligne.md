# 0011 — Écoute en ligne : rechercher et lire sans télécharger

Date : 2026-11-25 · Statut : **acceptée** par le propriétaire (réponses aux questions ouvertes le 2026-11-25, voir § Décisions du propriétaire)

## Décisions du propriétaire (2026-11-25)

1. **Style** : reprendre le style actuel de l'appli (lignes de la liste Titres, tokens existants). Pas de nouvelle maquette.
2. **Emplacement** : « le meilleur UX possible ». Retenu (voir § 3) : **une seule recherche** pour tout. La recherche globale (Ctrl K sur Windows, champ de recherche sur Android) montre d'abord la bibliothèque puis une section **En ligne**, avec un filtre « En ligne ». En plus, une entrée **En ligne** dans MUSIQUE ouvre cette recherche avec le filtre déjà choisi.
3. **Obtenir** : un petit choix de format au clic, avec le dernier choix retenu.
4. **Obtention automatique** : oui, sous forme d'option dans les Réglages, désactivée par défaut.

## Contexte

Le propriétaire veut une section **En ligne** dans l'espace Écouter, inspirée de ce que font des applis comme Lyrify :

1. on tape un titre ou un artiste ;
2. une liste de résultats s'affiche (pochette, titre, artiste, durée) ;
3. un clic lance le morceau **dans le lecteur existant** (mini-lecteur, En lecture, vitesse, minuteur, vinyle, égaliseur, file) ;
4. un bouton **Obtenir** télécharge le morceau dans la bibliothèque (priorité du propriétaire).

L'essentiel existe déjà :

- yt-dlp est intégré, épinglé et mis à jour sur Windows (décision 0002) et sur Android (décision 0004), avec un moteur JavaScript (`--js-runtimes`) ;
- le cœur Rust pilote yt-dlp (`crates/download-engine/src/ytdlp/`) et l'expose à Dart par `flutter_rust_bridge` (`apps/flutter_client/rust/src/api/`) ;
- les deux moteurs de lecture (`mpv_engine.dart` sur Windows, `media3_engine.dart` sur Android) lisent des URL HTTP, pas seulement des fichiers ;
- l'espace Obtenir sait déjà télécharger une URL YouTube en audio (`get_start_download`).

Il manque une **recherche distante**, une **résolution du flux audio** au moment de la lecture, et l'écran.

## Décisions proposées

1. **Source : YouTube via yt-dlp, côté appareil.** Pas de serveur, pas de conversion en MP3 à distance, pas de compte ni de cookies. Ça respecte le principe « local-first » et ça évite le modèle le plus exposé juridiquement (un serveur qui convertit en MP3, comme Lyrify).
2. **Le flux est lu directement**, sans fichier intermédiaire : le moteur reçoit une URL HTTPS et lit en continu, sans tout charger en mémoire.
3. **Les URL de flux ne sont jamais stockées.** Elles expirent (environ 6 h). La file stocke l'identifiant de la vidéo ; l'URL est résolue juste avant la lecture.
4. **Les moteurs de lecture ne changent pas.** Une étape de résolution est ajoutée dans la file (`playback.dart`), avant `engine.open` et `engine.prepareNext`.
5. **Obtenir réutilise le circuit de téléchargement existant**, sans nouveau code de téléchargement.
6. **Windows d'abord, Android ensuite**, après mesure du délai de résolution sur le téléphone de référence.
7. **Application gratuite, sans abonnement** (confirmé par le propriétaire). C'est ce qui distingue Miarina Media des services comme Lyrify, qui vendent un Premium basé sur du contenu YouTube.
8. **Le hors connexion passe par Obtenir.** Un morceau écouté en ligne peut être obtenu en un clic ; il rejoint alors la bibliothèque locale et se lit sans réseau, avec toutes les fonctions (Favoris, Playlists, Paroles `.lrc`). Il n'y a pas de second stockage caché : un seul endroit pour les fichiers, la bibliothèque.

## Vue d'ensemble

```text
┌──────────────────────── Flutter (apps/flutter_client/lib) ────────────────────────┐
│                                                                                    │
│  features/online/                         features/playback/playback.dart          │
│  ┌───────────────────────┐   clic        ┌──────────────────────────────────────┐  │
│  │ online_screen.dart    │ ───────────▶  │ QueueNotifier                        │  │
│  │  barre de recherche   │  QueueEntry   │  entrée « en ligne » (videoId)       │  │
│  │  liste de résultats   │  (online)     │        │                             │  │
│  │  bouton Obtenir ──┐   │               │        ▼                             │  │
│  └─────────┬─────────┘   │               │  OnlineResolver ──▶ MediaSource(url, │  │
│            │ recherche   │               │   (cache + retry)    httpHeaders)    │  │
│  online_data.dart        │               │        │                             │  │
│  (Riverpod, anti-rebond) │               │        ▼                             │  │
│            │             │               │  MediaEngine (mpv / Media3) inchangé │  │
│            │             │               └──────────────────────────────────────┘  │
└────────────┼─────────────┼─────────────────────────────┬─────────────────────────────┘
             │ FFI         │ FFI (existant)              │ FFI
┌────────────▼─────────────▼─────────────────────────────▼────── Rust ───────────────┐
│  rust/src/api/online.rs (nouveau)        rust/src/api/get.rs (existant)            │
│   online_search(query, limit)             get_start_download(StartRequest)         │
│   online_resolve(video_id)                                                         │
│            │                                                                       │
│  crates/download-engine/src/ytdlp/                                                 │
│   search.rs (nouveau) : ytsearchN:, analyse du JSON, validation                    │
│   mod.rs : Ytdlp::search / Ytdlp::resolve_audio  ──▶ processus yt-dlp (borné)      │
└────────────────────────────────────────────────────────────────────────────────────┘
```

## Composants

### 1. Cœur Rust — `crates/download-engine/src/ytdlp/search.rs` (nouveau)

**Recherche.** `Ytdlp::search(query, limit)` lance :

```text
yt-dlp <args de base> --flat-playlist --dump-single-json --no-warnings -- "ytsearch<limit>:<query>"
```

- `limit` borné à 1–30 (20 par défaut).
- La requête est une donnée non fiable : passée en un seul argument après `--`, longueur bornée (200 caractères), caractères de contrôle retirés.
- Le JSON est analysé avec les mêmes règles tolérantes que `info.rs` (taille de sortie bornée, champs optionnels).
- Résultat : `OnlineHit { video_id, title, channel, duration, thumbnail, is_live }`. Les directs (`is_live`) et les entrées sans durée sont filtrés.

**Résolution.** `Ytdlp::resolve_audio(video_id)` lance :

```text
yt-dlp <args de base> -f "bestaudio[ext=m4a]/bestaudio" --dump-single-json --no-playlist -- https://www.youtube.com/watch?v=<id>
```

- `video_id` validé par `^[A-Za-z0-9_-]{11}$`. L'URL est **construite par Rust** : l'interface ne peut pas faire lire une URL arbitraire.
- Résultat : `OnlineStream { url, http_headers, expires_at, duration, codec, bitrate }`. `expires_at` est lu dans le paramètre `expire=` de l'URL ; sinon on prend maintenant + 1 h.
- Refus clairs : DRM, contenu réservé aux membres, restriction d'âge, vidéo privée ou supprimée → erreur typée `Unavailable`, jamais de contournement.

**Limites.**

- Délais : 30 s pour une recherche comme pour une résolution (yt-dlp en Python démarre plus lentement sur Android).
- Mesuré le 2026-11-25 sur le PC Windows de référence (yt-dlp embarqué, QuickJS) : recherche de 10 résultats en **4,1 à 4,8 s**, résolution du flux en **7,9 s** (M4A AAC 129 kbit/s, URL valable 6 h). La résolution est plus lente que prévu : le préchargement du morceau suivant (§ 4) et le cache des résolutions sont donc indispensables, et la piste « lancer la lecture pendant la résolution » est à étudier au lot 3.
- Au plus 1 recherche, 1 résolution et 1 préchargement en même temps.
- Une nouvelle recherche tue le processus de la précédente.

### 2. API FFI — `apps/flutter_client/rust/src/api/online.rs` (nouveau)

| Fonction | Rôle |
|---|---|
| `online_search(query, limit) -> OnlineResults` | Résultats ; cache mémoire de 50 requêtes pendant 10 min |
| `online_resolve(video_id) -> OnlineStream` | URL de flux ; cache jusqu'à `expires_at` − 5 min |
| `online_watch_url(video_id) -> String` (sync) | URL canonique pour le bouton Obtenir |
| `online_available() -> bool` (sync) | Faux si yt-dlp manque : l'écran propose d'installer les outils (`get_install_tools`) |

Aucun stockage SQLite en V1 : les caches sont en mémoire et disparaissent à la fermeture.

### 3. Parcours et écran — `features/search/` (existant) + `features/online/` (nouveau)

**Une seule recherche.** L'utilisateur n'a pas à choisir où chercher.

- La recherche globale existante (`search_screen.dart` : Ctrl K dans la barre de titre sur Windows, champ dédié sur Android) garde ses filtres Tout / Musique / Cinéma / Focus et gagne un filtre **En ligne**.
- Avec **Tout** : les résultats de la bibliothèque s'affichent tout de suite, comme aujourd'hui. En dessous, une section **En ligne** se remplit quand l'utilisateur s'arrête de taper (700 ms) ou appuie sur Entrée. Ça évite d'interroger YouTube à chaque lettre.
- Avec **En ligne** : seulement les résultats distants (20, puis « Plus de résultats »).
- Un résultat déjà obtenu porte le badge **Hors connexion ✓** et se lit depuis le fichier local.

**Une entrée de menu** pour qu'on trouve la fonction :

- Windows : **En ligne** dans la barre latérale, rubrique MUSIQUE (route `Routes.online` = `/listen/online`).
- Android : la même entrée dans l'accueil Écouter.
- Cette entrée ouvre la recherche avec le filtre En ligne déjà choisi, le champ actif, et les **recherches récentes** (stockées localement, effaçables).

**Ligne de résultat** : même composant que la liste Titres (pochette, titre, chaîne, durée, barres « en cours de lecture »).

- Clic : lire. La suite des résultats devient la file, comme dans un album.
- Menu « ⋯ » : Lire ensuite, Ajouter à la file, **Obtenir…**.
- Bouton Obtenir visible au survol (Windows) ou par appui long (Android).

**États** : vide (recherches récentes), chargement (lignes squelettes), résultats, aucun résultat, **hors connexion** (raccourci vers les morceaux obtenus), **outils manquants** (bouton Installer), erreur (Réessayer, Mettre à jour yt-dlp).

**Fichiers** :

- `features/online/online_data.dart` : providers Riverpod (requête, résultats, recherches récentes, état) ;
- `features/online/online_tile.dart` : la ligne et son menu ;
- `features/online/obtain_sheet.dart` : le choix de format ;
- `features/search/search_screen.dart` : filtre et section En ligne.
- Pochettes : l'interface ne charge jamais d'image distante (règle de `crates/download-engine/src/thumbnail.rs`). Le cœur télécharge la miniature (`online_thumbnail` : hôtes `*.ytimg.com` en https seulement, taille bornée, JPEG/PNG/WebP vérifiés) dans le dossier des miniatures sources ; la ligne et le lecteur affichent ce fichier local. Ce cache est compté et vidé par le réglage existant « Vider les miniatures », et c'est le seul dossier dont Obtenir accepte une pochette (lot 4). Le lot 2 chargeait les images par Flutter : corrigé au lot 3.
- Riverpod 3 relance par défaut un provider en échec : désactivé pour la recherche en ligne (chaque essai lance l'extracteur), l'écran propose « Réessayer ».
- Un clic sur un résultat lit la liste à partir de lui (lot 3).

### 4. Intégration au lecteur — `features/playback/playback.dart`

- `MediaSource` reçoit un champ optionnel `httpHeaders` (en-têtes renvoyés par yt-dlp). `mpv_engine` les passe à `Media(httpHeaders: …)` ; `media3_engine` à la source HTTP de Media3.
- `QueueEntry` reçoit un champ optionnel `onlineId`. Une entrée en ligne a `libraryId == null`.
- **`OnlineResolver`** (nouveau, dans `features/playback/`) :
  - avant `engine.open` : résout l'URL (état « chargement » déjà géré par le lecteur) ;
  - avant `engine.prepareNext` : résout le morceau suivant à l'avance, pour enchaîner sans attendre ;
  - en cas d'erreur d'accès pendant la lecture (URL expirée, 403) : une seule nouvelle résolution, puis reprise à la dernière position ; sinon, erreur normale du lecteur.
- **Ce qui marche tel quel** : lecture/pause, avance, vitesse, minuteur, vinyle, égaliseur, file, mini-lecteur, lecture en arrière-plan Android (MediaSession).
- **Masqué ou désactivé en V1** pour une entrée en ligne, selon la règle « une fonction absente est masquée, jamais simulée » (décision 0007) : Favoris, ajout à une playlist, informations du fichier. L'onglet Paroles affiche son état vide actuel.

**Réalisé au lot 3** (écarts avec ce qui précède) :

- `MediaSource.uri` reste `miarina-online:<id>` (identité stable : file, mémoire de lecture, comparaisons) ; `MediaSource.stream` porte l'URL du flux et `httpHeaders` ses en-têtes. Les moteurs ouvrent `playable` (`stream ?? uri`) ; mpv passe les en-têtes à `Media(httpHeaders:)`, Media3 les reçoit dans le message (`headers`, seulement s'il y en a), appliqués par le plugin au lot 5.
- Pendant la résolution (environ 7,5 s mesurés, même avec le cache de yt-dlp ; les autres clients YouTube échouent), le morceau précédent se met en pause et le bouton lecture de la barre (Windows) et du mini-lecteur (Android) affiche une roue.
- Échec : la barre affiche la raison sous le titre, l'écran En lecture la carte d'erreur (« Réessayer », « Titre suivant ») ; le bouton lecture réessaie aussi.
- Le flux du morceau suivant est cherché dès que le morceau courant démarre, avec ou sans enchaînement sans blanc ; le cache du cœur le rend instantané au changement.
- Un flux refusé pendant la lecture est cherché à nouveau (sans cache) une fois, et la lecture reprend à la dernière position ; un second refus montre la carte d'erreur.
- Non vérifié à ce stade : la lecture réelle par libmpv dans l'appli Windows (les tests utilisent un moteur factice).

### 5. Bonus : Obtenir

- Bouton sur chaque résultat et dans l'écran En lecture pour une entrée en ligne.
- **Petit choix au clic** (`obtain_sheet.dart` : menu sur Windows, feuille du bas sur Android). Trois options, avec une explication honnête puisque la source YouTube est déjà compressée :
  - **Original** (M4A ou Opus, sans conversion) : meilleure qualité, plus rapide ;
  - **MP3 320** : se lit partout ;
  - **MP3 128** : léger, pour garder de la place.

  Pas de FLAC : convertir une source compressée en FLAC grossit le fichier sans améliorer le son. Le dernier choix est présélectionné, et une case « Toujours utiliser ce format » permet de sauter le choix ensuite (modifiable dans les Réglages).
- Appelle le `get_start_download` existant avec :
  - `url` = `online_watch_url(id)`, `is_audio = true`, `start_now = true` ;
  - `format_id` et `extension` = l'offre choisie dans `get_preset_offers().audio` ;
  - `title` et `thumbnail` repris du résultat.
- Le suivi, les erreurs, les notifications et l'arrivée dans la bibliothèque sont ceux d'Obtenir, sans code nouveau.
- Quand le téléchargement se termine, l'entrée en ligne de la file bascule vers le fichier local, ce qui active Favoris, Playlists et Paroles `.lrc`.
- Un résultat déjà obtenu affiche « Hors connexion ✓ » et se lit depuis le fichier local, sans réseau. Il faut vérifier si la bibliothèque garde l'URL d'origine ; sinon, une migration SQLite ajoute une colonne `source_id` (ID de la vidéo) à la table des médias.

### 6. Hors connexion

- **Écouter sans réseau** : tout ce qui a été obtenu est dans la bibliothèque (Titres, Albums, Artistes, Playlists) et se lit comme aujourd'hui.
- **Écran En ligne sans réseau** : état « Hors connexion » avec un raccourci vers les morceaux obtenus, au lieu d'une erreur.
- **File de lecture** : si le réseau tombe, les entrées en ligne non obtenues sont sautées avec un message ; les entrées locales continuent.
- **Obtention automatique** (validée) : dans Réglages › Écoute en ligne, un interrupteur **« Obtenir automatiquement les morceaux que j'écoute en entier »**, désactivé par défaut.
  - « En entier » : le morceau arrive à la fin, ou au moins 90 % de sa durée est écouté.
  - Format : celui de « Toujours utiliser ce format », sinon Original.
  - Pas de doublon : un morceau déjà obtenu ou déjà en file de téléchargement est ignoré.
  - Android : sous-option **« Uniquement en Wi-Fi »**, activée par défaut.
  - Un petit message discret (« Ajouté hors connexion ») confirme chaque ajout.

**Réalisé au lot 4** (écarts avec ce qui précède) :

- Le bouton Obtenir est **toujours visible** en bout de ligne (Windows et Android), plutôt qu'au survol ou à l'appui long : plus facile à découvrir, utilisable au doigt. Il devient une roue pendant le téléchargement, puis une coche « Hors connexion ».
- Formats : Original (`ba[ext=m4a]/ba`, sans conversion), MP3 320 et MP3 128 (avec FFmpeg seulement). Le choix « Toujours utiliser ce format » est enregistré, et modifiable dans **Réglages › Lecture › Écoute en ligne** (« Format d'Obtenir » : Demander, Original, MP3 320, MP3 128).
- « Déjà obtenu » : la bibliothèque garde l'adresse d'origine d'un fichier obtenu (`media.source_url`) ; `Storage::media_by_source_urls` retrouve les titres d'une liste de résultats (fichiers présents seulement). Aucune migration. La liste est relue à chaque téléchargement terminé.
- Un résultat obtenu se lit depuis son fichier, même au milieu d'une file de résultats en ligne.
- Obtention automatique : interrupteur dans le même groupe de réglages, désactivé par défaut ; « en entier » = fin du titre, ou 90 % d'un titre d'au moins 30 s ; une fois par titre et par session, jamais si le titre est déjà obtenu ou en cours ; message « Ajouté hors connexion ». Le format est celui des réglages, sinon le dernier choisi, sinon Original.
- **Reporté au lot 5** : « Uniquement en Wi-Fi » (il faut connaître le type de réseau côté Android ; une option qui ne ferait rien n'est pas affichée).
- **Non fait** : une entrée en ligne de la file ne bascule pas vers le fichier quand son téléchargement se termine pendant la lecture ; c'est la prochaine lecture du titre qui utilise le fichier.

### 7. Android

- Même API Rust : yt-dlp et QuickJS sont déjà embarqués (décision 0004).
- Media3 lit l'URL HTTPS avec les en-têtes ; arrière-plan et écran verrouillé déjà en place.
- À mesurer avant de livrer : délai de résolution avec yt-dlp en Python sur le Redmi Note 10 Pro, consommation de données, comportement quand l'URL expire écran éteint.

**Réalisé au lot 5** (2026-11-26) :

- `Media3EnginePlugin.parseUri` traitait toute adresse autre que `content://` et `file://` comme un chemin : un flux `https://` ne pouvait pas jouer. Corrigé.
- En-têtes : le plugin les note dans `OnlineHeaders` (même processus, les 8 derniers) ; le lecteur de `PlaybackService` passe par un `ResolvingDataSource` qui les ajoute aux requêtes de ce flux. Fichiers et URI de contenu inchangés.
- « Uniquement en Wi-Fi » (Réglages › Lecture › Écoute en ligne, sur téléphone, activé par défaut) : l'obtention automatique attend le Wi-Fi ou l'Ethernet (`media_tools.onWifi`, `ConnectivityManager`). `ACCESS_NETWORK_STATE` était déjà dans l'APK (fusionnée par une bibliothèque) ; déclarée dans le manifeste pour la clarté, sans changer les permissions de l'app.
- Lecteur du téléphone : Obtenir dans son menu « ⋯ » pour un titre en ligne. Puce « En ligne » dans la rangée Albums / Titres / Artistes / Playlists, pour qu'elle soit accessible même bibliothèque vide.
- Obtention automatique : le titre entendu est retrouvé par son flux, car à sa fin la file est déjà passée au suivant (défaut aussi sur Windows).
- Une réponse lente (`slow`) est retentée une fois avant d'afficher « YouTube ne répond pas » : vu sur Windows quand l'ordinateur compilait en même temps.
- Recette par le propriétaire sur le Redmi Note 10 Pro (Android 13, APK bêta `org.miarina.media.beta`) : recherche et lecture en ligne fonctionnent. Journal Android pendant l'essai : aucune erreur liée à l'écoute en ligne. Non mesuré : délai de résolution sur le téléphone, données consommées.

## Risques

| Risque | Effet | Parade |
|---|---|---|
| Conditions d'utilisation YouTube | Lecture hors lecteur officiel : non autorisée par YouTube. Même niveau de risque que la section Obtenir actuelle | Appli gratuite sans abonnement, pas de serveur, pas de compte ; décision assumée par le propriétaire |
| Changements de YouTube (signatures, jetons, protocole) | Recherche ou lecture cassée du jour au lendemain | Mise à jour de yt-dlp déjà en place (`get_update_ytdlp`) ; message clair « mettre à jour les outils » |
| Délai de démarrage (1–3 s Windows, plus sur Android) | Sensation de lenteur | État chargement, préchargement du suivant, cache des résolutions |
| URL expirée pendant une longue pause | Erreur à la reprise | Nouvelle résolution automatique, une fois |
| Blocage par adresse IP (trop de requêtes) | Erreurs 429 | Anti-rebond, cache, processus bornés ; aucune requête en arrière-plan sans action de l'utilisateur |
| Requête ou JSON malveillant | Injection d'option, sortie énorme | Argument unique après `--`, ID validé, URL construite par Rust, sortie bornée |

## Tests

- **Rust :** analyse d'un JSON `ytsearch` de référence (fixture), filtrage des directs, validation des ID, lecture de `expire=`, refus des requêtes vides ou trop longues, mise à mort de la recherche précédente.
- **Dart :** tests de widgets pour chaque état de l'écran ; tests du résolveur (résolution avant ouverture, préchargement, une seule nouvelle tentative sur 403).
- **Recette manuelle :** recherche, lecture, morceau suivant sans coupure, pause de 7 h puis reprise, coupure réseau, outils absents, Obtenir puis lecture du fichier depuis la bibliothèque.
- Mesures (délai de résolution, RAM en lecture en ligne) consignées dans `docs/performance.md`.

## Découpage en lots

| Lot | Contenu | Vérification |
|---|---|---|
| 1 ✅ | Rust : `search.rs`, `Ytdlp::search`, `Ytdlp::resolve_audio`, `api/online.rs`, liaisons Dart, tests | `cargo test`, clippy, appel réel par `examples/online_probe.rs` |
| 2 ✅ | Filtre et section En ligne dans la recherche globale, entrée de menu, recherches récentes, états | Tests de widgets (`test/online_test.dart`, 15 tests) ; capture d'écran Windows à faire par le propriétaire |
| 3 ✅ | Lecteur : `MediaSource.stream` et `httpHeaders`, `QueueEntry.onlineId`, résolution avant ouverture, préchargement du suivant, reprise sur refus, roue de chargement, carte d'erreur | Tests de widgets (20 au total) ; recette dans l'appli par le propriétaire |
| 4 ✅ | Obtenir avec choix de format, badge « Hors connexion ✓ », lecture depuis le fichier, option d'obtention automatique | Tests de widgets (26 au total) et de stockage ; téléchargement réel et mode avion à vérifier par le propriétaire |
| 5 ✅ | Android : lecture des flux `https`, en-têtes Media3, Wi-Fi seulement, Obtenir sur téléphone | Recette du propriétaire sur le Redmi ; mesures sur téléphone encore à faire |

## Questions encore ouvertes

1. **Historique** : enregistrer les écoutes en ligne dans Historique (stocké localement) ?
2. **Paroles en ligne** : récupérer des paroles synchronisées depuis un service public (par exemple LRCLIB) ? Ce serait un service distant, donc à approuver (principe 3).
