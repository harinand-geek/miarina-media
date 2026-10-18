# 0002 — yt-dlp et FFmpeg inclus dans l'installeur Windows

Date : 2026-10-17 · Statut : **acceptée** (demande du propriétaire du produit) · Remplace en partie D3

## Contexte

D3 (Phase 0, Q5) faisait télécharger yt-dlp et FFmpeg au premier besoin, après accord de l'utilisateur, pour garder un installeur léger. À l'usage, l'écran « This page needs the media tools » interrompt la première analyse d'une page web : 85 Mo à télécharger avant de pouvoir faire quoi que ce soit.

## Décision

1. **Windows : les outils sont livrés dans l'installeur**, dans `<dossier d'installation>\tools\<id>\<préfixe SHA-256>\`. L'application les cherche d'abord là, puis dans `%APPDATA%` (téléchargement D3).
2. Ils sont préparés au build par `cargo run -p download-engine --example fetch_tools -- src-tauri/tools`, lancé automatiquement par `tauri.windows.conf.json` (`beforeBuildCommand` / `beforeDevCommand`). Ce programme réutilise le code de téléchargement de l'app : mêmes URL, tailles et **SHA-256 épinglés** ; une archive différente fait échouer le build. Le dossier `src-tauri/tools/` n'est pas versionné.
3. **Le téléchargement au premier besoin reste en secours** (exécutable lancé hors installeur, dossier `tools` supprimé) : l'écran de consentement ne s'affiche que si un outil manque.
4. **Android n'est pas concerné** : `yt-dlp.exe` et les DLL FFmpeg ne fonctionnent pas sur Android ; la configuration est propre à Windows et l'APK ne change pas.
5. Les notices sont livrées à côté des outils : `tools\THIRD-PARTY-TOOLS.txt` (versions, empreintes, liens vers les sources correspondantes), `LGPL-3.0.txt` et `GPL-3.0.txt`.

## Complément du 2026-10-17 : moteur JavaScript QuickJS-NG

yt-dlp a besoin d'un moteur JavaScript pour répondre aux défis de YouTube (wiki yt-dlp « EJS » ; le solveur `yt-dlp-ejs` est déjà dans `yt-dlp.exe`). Mesures sur Sintel (YouTube, CC BY) avec yt-dlp 2026.08.19 :

| | Sans moteur | QuickJS-NG 0.17.0 | Deno 2.9.7 |
|---|---|---|---|
| Analyse | 15,8 s + avertissement « deprecated » | 6,9 s | 7,7 s |
| Formats | 47 | 47 | 47 |
| Audio 14,4 Mo (format 251) | 89 s | 37 s | — |
| Taille | — | 2,1 Mo (exe) | 42,6 Mo zip / 97 Mo exe |

Décision : **QuickJS-NG 0.17.0** (MIT), inclus et épinglé comme les autres outils, passé à yt-dlp par `--js-runtimes quickjs:<chemin>` (analyse et téléchargement). Deno, recommandé par yt-dlp, coûterait ~40 Mo d'installeur pour un temps équivalent. Limite connue (wiki yt-dlp) : avec QuickJS, yt-dlp écrit des fichiers temporaires pour chaque exécution (risque TOCTOU théorique, local). Si YouTube impose un jour Deno, le changement se limite à `components.rs`.

## Complément du 2026-10-18 : mises à jour automatiques et vérifiées de yt-dlp

Décision du propriétaire du produit : yt-dlp reste inclus, **et se met à jour seul** (FFmpeg et QuickJS-NG ne changent qu'avec l'app).

- Vérification au plus **une fois par jour** (2 min après le démarrage, puis toutes les heures si la dernière date de plus de 24 h), plus le bouton « Check for updates » (Réglages › Media tools). Échec (hors ligne…) : silencieux, nouvel essai à l'heure suivante.
- Source : release officielle GitHub (`api.github.com/repos/yt-dlp/yt-dlp/releases/latest`, puis `SHA2-256SUMS`, `SHA2-256SUMS.sig`, `yt-dlp.exe`). Tailles bornées.
- **Acceptée seulement si** la signature OpenPGP de `SHA2-256SUMS` est valide pour la clé de signature de yt-dlp épinglée dans l'app (`crates/download-engine/keys/yt-dlp-signing-key.asc`, empreinte `AC0C BBE6 848D 6A87 3464 AF4E 57CF 6593 3B5A 7581`, vérifiée aussi avec GnuPG le 2026-10-18), que `yt-dlp.exe` a l'empreinte signée, et que le nouvel exécutable répond `--version` avec le numéro attendu. Sinon rien ne change.
- Activation par `components/yt-dlp/active.json` ; une version plus ancienne que celle de l'installeur ou un fichier illisible est ignoré : la version incluse reste le secours.
- Dépendance ajoutée : `pgp` 0.21.0 (rPGP, MIT OR Apache-2.0, sans fonctionnalités par défaut).
- Confidentialité : l'app contacte `api.github.com` et `github.com` une fois par jour (aucune donnée personnelle envoyée, en-tête User-Agent « MiarinaMedia/<version> »). À indiquer sur la page Confidentialité à la prochaine publication.
- Limite : pas encore de retour automatique à la version précédente si une nouvelle version de yt-dlp fonctionne mal sur un site (le test `--version` ne le détecte pas).

## Conséquences

- Installeur NSIS : **8,2 Mo → 68,1 Mo**, puis **68,8 Mo** avec QuickJS-NG (mesurés le 2026-10-17) ; ~157 Mo d’outils une fois installés.
- En redistribuant FFmpeg nous-mêmes, les obligations de la LGPL nous reviennent : texte de licence fourni, accès aux sources correspondantes (BtbN/FFmpeg-Builds) indiqué ; à reprendre dans l'écran « À propos / Licences ».
- Mise à jour de yt-dlp : uniquement avec une nouvelle version de l'application (nouvelle empreinte dans `components.rs`). Les sites changent souvent : prévoir des versions plus fréquentes, ou une mise à jour vérifiée de yt-dlp seul (à décider).
- L'antivirus / SmartScreen peut examiner plus longuement un installeur plus gros et non signé ; la signature Authenticode reste à décider.
