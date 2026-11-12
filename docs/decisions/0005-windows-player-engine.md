# 0005 — Moteur du lecteur Windows : libVLC (prototype WIN-SPIKE)

Date : 2026-11-12 · Statut : **acceptée** le 2026-11-12 par le propriétaire du produit (option « libVLC » : fenêtre transparente au-dessus de la vidéo si son rendu est bon, sinon barres hors de l'image) · Lot : L04

## Question

Le lecteur Windows utilise la balise `<video>` de WebView2 (Chromium). Le CDC (§ 6) demande une lecture « de type VLC » sans VLC installé : formats courants (MKV, AVI, HEVC…), pistes audio et sous-titres internes, sous-titres externes, vitesses 0,25×–3×. Il recommande libVLC **sous réserve de prototype** : rendu dans la fenêtre Tauri/WebView2, commandes au-dessus de la vidéo, ressources, taille, licences, fenêtres orphelines.

## Ce qui a été fait

Prototype mesuré dans l'application elle-même (`apps/client/src-tauri/src/spike_libvlc.rs`, compilé seulement avec la fonctionnalité Cargo `libvlc-spike`, jamais dans une version publiée ; retiré de l'arborescence en L05, consultable au commit `63f712a`) :

- libVLC **chargé dynamiquement** (`LoadLibraryExW` + `GetProcAddress`, aucune bibliothèque liée au build, aucune nouvelle dépendance Rust) depuis un dossier quelconque : celui de l'application en production ;
- une **fenêtre enfant native** (`WS_CHILD`) dans la fenêtre principale reçoit la vidéo (`libvlc_media_player_set_hwnd`), souris et clavier laissés à l'application ;
- un scénario lit tout un corpus, change de piste, ajoute un sous-titre externe, essaie les vitesses, redimensionne, ouvre et libère 10 fois le même fichier, puis écrit les mesures (JSON) ;
- moteur actuel mesuré sur le même corpus (Chromium d'Edge 157, même moteur que WebView2).

Environnement : Intel Core i5-8300H, Intel UHD 630 + NVIDIA GTX 1050 Ti, 15,8 Go, Windows 11 Professionnel, WebView2 157.0.4341.46, **VLC 3.0.24 « Vetinari »** (binaires officiels VideoLAN, avec FFmpeg 8.1). Corpus généré avec FFmpeg : MKV H.264 1080p avec 2 pistes audio nommées (français, anglais) et sous-titre SRT intégré accentué, MP4 HEVC 1080p, WebM VP9/Opus, MKV AV1, AVI MPEG-4/MP3, MP4 H.264 4K 60 Mbit/s, MP4 tronqué, copie du MKV dans « dossier avec espaces/été – 测试 ✓.mkv », SRT et VTT externes accentués.

## Résultats

| Cas | `<video>` WebView2 (actuel) | libVLC 3.0.24 (prototype) |
|---|---|---|
| MKV H.264 + 2 pistes audio + SRT intégré | lu ; 1 seule piste audio, pas d'API de piste (`audioTracks` absent), sous-titre intégré invisible | lu ; pistes « Français », « English » listées ; changement de piste en gardant la position ; SRT intégré listé |
| SRT externe accentué | non (WebVTT `<track>` seulement) | ajouté, sélectionné, affiché correctement (« « déjà vu » »), désactivable |
| HEVC 1080p | son seul, image 0 × 0 | lu |
| VP9 / AV1 | lus | lus (AV1 : 0,7–1 s avant lecture) |
| AVI MPEG-4 | refusé (« DEMUXER_ERROR_COULD_NOT_OPEN ») | lu |
| H.264 4K 60 Mbit/s | lu | **figé vers 6 s** dans la fenêtre enfant (matériel et logiciel) ; VLC seul avec sortie factice : temps réel en décodage matériel (15,9 s pour 15 s), trop lent en logiciel (23,7 s) — à résoudre en L05 |
| Fichier tronqué | erreur propre | fin immédiate, pas de plantage |
| Chemin Unicode avec espaces | lu | lu |
| Vitesses | — | 0,25×, 3× et 4× acceptées |
| Recherche (50 %) | — | position juste |

Intégration à la fenêtre Tauri :

- Fenêtre vidéo enfant affichée au bon endroit (DPI 100 %), redimensionnements « plein cadre » puis retour en 1–2 ms, **aucune fenêtre orpheline** pendant ni après (seules les fenêtres Tauri restent) ; aucune fenêtre VLC séparée.
- `libvlc_new` : **30–120 ms** avec un cache de modules valide ; **1,6 s** quand le cache `plugins.dat` est invalide (fichiers copiés, dates changées) → le cache doit être régénéré (`vlc-cache-gen`) au moment de préparer le paquet.
- Mémoire de travail du processus : 28 Mo avant, 30–58 Mo après `libvlc_new`, ~60–90 Mo en lecture 720p/SD, ~255–306 Mo en lecture 1080p (décodage dans le processus de l'application ; WebView2, lui, décode dans ses propres processus, non mesurés ici) ; 10 ouvertures/libérations : pas de croissance (≈ 243 → 246 Mo).
- Arrêt + libération : 50–180 ms en général, **8 s une fois** (premier fichier 4K à froid) → jamais sur le fil de l'interface.
- **Commandes HTML au-dessus de la vidéo** :
  - vue web enfant transparente au-dessus de la fenêtre vidéo (ordre d'empilement réglé par `SetWindowPos`) : elle s'affiche **au-dessus**, mais sa transparence montre la page de l'application, **pas la vidéo** (WebView2 en fenêtre enfant ne se compose pas avec une fenêtre native sœur) ; la vidéo est donc masquée sous toute la zone de la vue ;
  - fenêtre de premier niveau transparente **possédée** par la fenêtre principale (composée par DWM, au-dessus de son propriétaire) : créée sans erreur ; **rendu non vérifié visuellement** (une capture de l'écran réel n'est pas acceptable ici) — à confirmer à l'œil par le propriétaire.
- Créer une vue web depuis le fil principal de Tauri bloque l'application (interblocage) : à faire depuis un autre fil.

Taille (DLL + modules, VLC 3.0.24 64 bits) :

| Ensemble | Sur disque | Zip | Modules |
|---|---|---|---|
| Complet | 141 Mo | 63,3 Mo | 360 |
| Réduit à la lecture locale (sans interfaces Qt/skins, sortie de flux, multiplexeurs, Lua, visualisations, découverte réseau, encodeurs x264/x265, accès disques/DVB/SRT/RIST…) | 78 Mo | 35,1 Mo | 281 |

Le jeu réduit a lu tout le corpus (mêmes résultats que le complet).

## Licences (DEP-03)

`libvlc.dll` et `libvlccore.dll` : LGPL 2.1 ou ultérieure. Les modules et les bibliothèques qu'ils embarquent n'ont **pas tous la même licence** : un inventaire module par module (notices `COPYING.txt`, `AUTHORS.txt` de la distribution VideoLAN, versions des bibliothèques tierces) est à faire sur l'ensemble réduit retenu avant toute publication, avec les sources correspondantes indiquées comme pour FFmpeg (décision 0002). Aucune licence unique n'est attribuée au paquet.

## Proposition

1. **Adopter libVLC 3.0.x comme moteur du lecteur Windows en L05**, chargé dynamiquement depuis le dossier de l'application, `<video>` WebView2 restant le repli si libVLC manque ou échoue (et le moteur de l'aperçu / des tests).
2. Livrer l'**ensemble réduit** (≈ 35 Mo compressés), préparé au build depuis l'archive officielle VideoLAN avec **SHA-256 épinglé** (même principe que 0002), cache des modules régénéré, notices jointes.
3. Exécution **dans le processus** de l'application (aucun plantage observé, y compris fichier tronqué), toutes les commandes libVLC hors du fil de l'interface ; processus séparé seulement si des plantages réels apparaissent.
4. Commandes du lecteur : la zone vidéo est une fenêtre native ; les commandes HTML vont **hors de l'image** (barres opaques au-dessus/dessous) ou, si le propriétaire valide le rendu, dans une **fenêtre transparente possédée** au-dessus de la vidéo.
5. Conditions de réception de L05 : machine sans VLC installé, lecture 4K matérielle sans gel, inventaire des licences, plein écran / Échap (WIN-03), pistes et sous-titres (WIN-05/06), raccourcis (WIN-11).

Non étudié : libmpv (à faire seulement si cette proposition est refusée, dans une décision distincte), DPI différent de 100 %, multi-écrans, périphérique audio retiré (WIN-12).
