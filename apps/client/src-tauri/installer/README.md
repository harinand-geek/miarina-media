# Installateur Windows Miarina

Personnalisation NSIS via les options et hooks Tauri, sans copie du template
complet : mises à jour, raccourcis, WebView2 et désinstallation restent gérés
par Tauri.

- Logo officiel provenant de `icons/128x128.png` et `icons/icon.ico`.
- Panneau 164 × 314 et en-tête 150 × 57, palette du design approuvé.
- Accueil/fin personnalisés en français et anglais, langue du système.
- Contrôles natifs Windows conservés pour le clavier, le focus et l'accessibilité.
- Cases à cocher de fin en rendu classique NSIS : le thème Windows ignorait
  la couleur claire des libellés sur le panneau sombre.
- Segoe UI dans les bitmaps : adaptation à la petite taille des panneaux NSIS,
  sans dépendance à une police installée chez le destinataire.

Régénérer les images : `powershell -File installer/generate-assets.ps1` depuis
`src-tauri`. Générer une release complète : `pnpm tauri build --bundles nsis`
depuis `apps/client`.

Vérification du 28 octobre 2026 : `tauri bundle --bundles nsis` réussi et écran
d'accueil français inspecté dans Windows. Cette commande réutilise le binaire
release existant ; ce paquet de prévisualisation 0.1.3 ne constitue pas une
nouvelle version de l'application et n'a pas été publié.

Contraste de fin revérifié le 28 octobre sur un aperçu NSIS sans installation :
les deux cases à cocher utilisent maintenant des libellés clairs sur fond sombre.
L'aperçu a également été recompilé en UTF-8 explicite (`/INPUTCHARSET UTF8`) :
« Créer un raccourci » et le titre sont lisibles, et `MUI_ICON` affiche l'icône
officielle dans la barre de titre. Cet aperçu n'exécute aucune installation.
