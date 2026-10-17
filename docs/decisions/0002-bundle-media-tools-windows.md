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

## Conséquences

- Installeur NSIS : **8,2 Mo → 68,1 Mo**, puis **68,8 Mo** avec QuickJS-NG (mesurés le 2026-10-17) ; ~157 Mo d’outils une fois installés.
- En redistribuant FFmpeg nous-mêmes, les obligations de la LGPL nous reviennent : texte de licence fourni, accès aux sources correspondantes (BtbN/FFmpeg-Builds) indiqué ; à reprendre dans l'écran « À propos / Licences ».
- Mise à jour de yt-dlp : uniquement avec une nouvelle version de l'application (nouvelle empreinte dans `components.rs`). Les sites changent souvent : prévoir des versions plus fréquentes, ou une mise à jour vérifiée de yt-dlp seul (à décider).
- L'antivirus / SmartScreen peut examiner plus longuement un installeur plus gros et non signé ; la signature Authenticode reste à décider.
