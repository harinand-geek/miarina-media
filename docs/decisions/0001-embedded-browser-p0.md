# 0001 — Navigateur intégré en P0

Date : 2026-10-14 · Statut : **acceptée** (décision du propriétaire du produit)

## Contexte

`CLAUDE.md` classait le navigateur intégré et la détection de médias en « Later, not MVP ». La vision produit (Android proche de SnapTube, Windows proche de Televzr) et le cahier des charges `docs/requirements/android-mvp.md` en font une fonction P0. Le design approuvé ne contient pas les écrans du navigateur, et le multi-webview de Tauri 2 est une fonction `unstable` sur desktop, absente sur mobile (risque R3 de `android-feasibility.md`).

## Décisions

1. **Navigateur intégré + détection de médias + bouton de téléchargement contextuel : P0 sur Android et Windows.** `CLAUDE.md` mis à jour.
2. **Spike de faisabilité avant toute implémentation** :
   - Windows : webview enfant Tauri (`unstable`) ou fenêtre dédiée ; isolation de la page visitée (aucun accès IPC), détection des médias, coût mémoire mesuré.
   - Android : WebView native via un plugin Kotlin ; interception des requêtes médias, cycle de vie, mémoire.
3. **Navigation Android** : Home / Browser / Downloads / Library. Settings quitte la barre du bas (emplacement défini par la maquette). *Remplacé le 2026-11-15 par [0006](0006-android-player-first.md) : Musique / Vidéos / Téléchargements, navigateur ouvert depuis la recherche.*
4. **Écrans du navigateur** : fournis par le propriétaire sous forme de maquettes Claude Design ; pas d'implémentation visuelle avant leur réception.

## Conséquences

- La Phase 4 commence par le spike navigateur (résultats et mesures documentés), puis le spike Android déjà prévu (extracteur, FFmpeg, taille, stockage, tâches de fond).
- Les pages visitées sont du contenu non fiable : elles ne doivent jamais accéder aux commandes Tauri ; seules des URL de médias détectées, validées côté Rust, entrent dans le moteur de téléchargement.
- Aucune détection ne contourne DRM, paywall, authentification ou contrôles d'accès ; les flux chiffrés ne sont pas proposés.
