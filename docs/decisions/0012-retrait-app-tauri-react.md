# 0012 — Retrait de l'ancienne app Tauri + React

Date : 2026-11-27. Statut : acceptée.

## Contexte

Depuis la décision [0007](0007-flutter-migration.md), l'interface est en Flutter (`apps/flutter_client`). Les versions Flutter ont remplacé les 0.1.x sur Android (0.2.5) puis sur Windows, et la 0.3.0 publiée est entièrement Flutter. L'app Tauri + React (`apps/client`) n'était plus construite ni publiée, mais elle restait dans le dépôt (environ 470 fichiers suivis et 900 Mo de `node_modules` et de builds).

## Décision

Supprimés du dépôt :

- `apps/client/` : l'app Tauri 2 + React (Windows et Android) ;
- `spikes/browser-windows/` : le spike Tauri du navigateur intégré, terminé ;
- `crates/mdm-adapter/` : utilisé uniquement par l'app Tauri (option `mdm-http`). Le client Flutter utilise directement `mdm-torrent` (dossier `vendor/`).

Déplacés vers le client Flutter, parce qu'il les utilisait encore depuis `apps/client` :

| Avant | Après |
| --- | --- |
| `apps/client/src-tauri/resources/update-public-key.bin` | `apps/flutter_client/rust/update-public-key.bin` |
| `apps/client/src-tauri/resources/{GPL-3.0,LGPL-3.0,QuickJS-NG-LICENSE,MDM-NOTICE}.txt` | `apps/flutter_client/windows/notices/` |
| `apps/client/src-tauri/gen/android/keystore.properties` (hors git) | `apps/flutter_client/android/key.properties` (hors git) |

Le keystore `.jks` lui-même reste hors du dépôt, à l'endroit indiqué dans `key.properties`.

Les rapports de phases et les audits de l'époque Tauri sont rangés dans [`docs/archive/`](../archive/).

## Récupérer l'ancien code

Le tag git `archive/tauri-react-client` pointe sur le dernier commit qui contient l'app Tauri (27194c0, release 0.3.0). Par exemple :

```powershell
git show archive/tauri-react-client:apps/client/src-tauri/src/updates.rs
```

Les commentaires du code Flutter qui disent « comme l'app Tauri » renvoient à ce code-là.

## Conséquences

- Le workspace Cargo ne contient plus `apps/client/src-tauri` ni `crates/mdm-adapter`.
- Le workspace pnpm ne contient plus que le site (`apps/website`) ; les scripts racine sont `website:dev`, `website:build`, `typecheck` et `format`.
- Le site reste en React (décision [0003](0003-website-react-prerender.md)) : il n'est pas concerné.
