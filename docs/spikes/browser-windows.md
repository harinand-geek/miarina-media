# Spike — navigateur intégré sous Windows

Date : 2026-10-14 · Décision liée : `docs/decisions/0001-embedded-browser-p0.md` · Code : `spikes/browser-windows/` (jetable, hors workspace, **non livré**).

Environnement : Windows 11 Pro 22000, WebView2 155, Tauri 2.12.3 avec la feature `unstable` (spike uniquement), build debug. Vérifications faites en pilotant la vraie fenêtre (clics, clavier) et via le protocole DevTools de WebView2.

## Montage testé

Une fenêtre, trois webviews enfants (`Window::add_child`, feature `unstable`) :

| Webview | Contenu | Accès IPC |
|---|---|---|
| `chrome` | barre d'outils de l'app (HTML local) | commandes accordées par capability |
| `page` | site visité (URL externe) | **aucune capability** |
| `overlay` | bouton flottant + feuille de formats, `transparent(true)` | commandes accordées par capability |

Détection côté Rust uniquement, sans rien injecter dans la page :
- **réseau** : événement natif WebView2 `WebResourceResponseReceived` (via `with_webview`), lecture du type MIME et de l'URL ;
- **DOM** : `ExecuteScript` lancé par Rust (à la fin du chargement puis toutes les 3 s), qui renvoie les `src` des `<video>`/`<audio>`. Le résultat est un simple indice, parsé et filtré en Rust.

## Résultats

| # | Critère | Résultat |
|---|---|---|
| 1 | Un vrai site se charge et se navigue | ✅ Wikimedia Commons, YouTube ; back / forward / reload via l'API native |
| 2 | Couche transparente au-dessus de la page | ✅ le bouton flottant s'affiche par-dessus la page ; la **feuille avec voile à 62 %** laisse voir la page en dessous (D2 réalisable tel que maquetté) ; Échap ferme |
| 2b | Clics à travers la zone transparente | ❌ le rectangle transparent de l'overlay **intercepte les clics** (testé : un clic dans la zone transparente n'arrive pas à la page) → l'overlay doit être dimensionné au pixel près sur le bouton (taille remontée par l'overlay) |
| 3 | Détection de médias | ✅ page Commons : 5 médias via DOM (original + 4 transcodages) ; fichier vidéo direct : `video/webm` via réseau ; liste remise à zéro à chaque navigation |
| 3b | Lecteurs MSE (`blob:`) | ⚠️ YouTube : la vidéo est en `blob:` (signalé) ; le réseau ne remonte que des sons d'interface (`open.mp3`, `failure.mp3`…) — **faux positifs**, et la vraie vidéo n'est pas détectable ainsi |
| 4 | La page ne peut appeler aucune commande | ✅ commandes de l'app, `event.emit/emit_to/listen`, `window.close`, `webview.set_*`, `app.version`, `path.*` : **toutes refusées** par l'ACL |
| 4b | Exposition de l'IPC à la page | ⚠️ Tauri injecte `__TAURI_INTERNALS__` (et `__TAURI__` si `withGlobalTauri`) **dans la page externe** : rien n'est autorisé, mais le site peut savoir qu'il tourne dans Tauri |
| 5 | Raccourcis quand la page a le focus | ✅ `AcceleratorKeyPressed` intercepte Ctrl+L (focus barre d'adresse), Ctrl+T/W/H/D, Ctrl+Shift+S (ouvre la feuille), F5 |
| 6 | Schémas non web | ✅ `file:` refusé depuis la barre (validation Rust) et depuis la page (`on_navigation`) ; `window.open` rouvert dans le même onglet ; téléchargements natifs du navigateur refusés (`on_download`) |
| 7 | Mémoire (Commons + YouTube chargés) | processus Rust ~5 Mo privés ; WebView2 9 processus, **~361 Mo privés** dont renderers : page ~137 Mo, barre ~24 Mo, overlay ~29 Mo ; navigateur ~52 Mo, GPU ~82 Mo |

## Conclusions

1. **Faisable sous Windows avec Tauri**, maquettes D1/D2 comprises (overlay translucide au-dessus de la page). Le coût de la barre et de l'overlay en webviews séparées est d'environ 50 Mo de renderers.
2. **Risque `unstable`** : `add_child` / `WebviewBuilder` sont derrière la feature `unstable` de Tauri 2 (API susceptible de changer). À accepter explicitement, version de Tauri épinglée, et isolé dans un module `browser` côté Rust.
3. **Détection = deux voies complémentaires** :
   - médias directs (réseau + DOM), avec filtres : ignorer les petites réponses (`Content-Length`), les segments, et dédupliquer ;
   - **URL de la page → analyse yt-dlp existante** quand un lecteur MSE est détecté ou que le site est pris en charge (cas YouTube et la plupart des grandes plateformes). Le bouton flottant doit donc pouvoir afficher « Analyse de la page » et non seulement une liste de fichiers.
4. **Isolation** : l'ACL tient. Pour ne même pas exposer les objets IPC à la page, pistes à évaluer avant livraison : créer la webview de page avec un environnement WebView2 séparé hors Tauri, ou demander l'option en amont (Tauri). Sinon, risque accepté et documenté.
5. **Profil de navigation** : dans le spike, la page partage le profil WebView2 (cookies, stockage) avec l'UI de l'app. À séparer en production (dossier de données ou profil distinct) — coût mémoire à mesurer.
6. **Overlay** : redimensionner la webview overlay à la taille réelle du bouton (et pleine page seulement quand la feuille est ouverte).

## Non testé dans ce spike

Onglets multiples (une webview de page par onglet, ou suspension des onglets inactifs), flux HLS/DASH réels, pages avec iframes de lecteur, historique/favoris (SQLite), Alt+←/→, DPI élevés et redimensionnement, fenêtre dédiée avec onglets dans la barre de titre (D1), build release, consommation CPU.

## Android

Non commencé : nécessite un appareil Android physique (WebView native via plugin Kotlin, `shouldInterceptRequest` pour la détection).
