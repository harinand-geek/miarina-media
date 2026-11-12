# Fiche — Android : splash screen (logo 4d animé) et écrans de démarrage

- Statut : fait et vérifié sur émulateur Android 15 ; Android 7–11 et téléphone réel non vérifiés ; écran de migration (S4) non fait
- Maquette : `design/design_handoff_splash` (S1–S6)

## Réalisé

| Élément de la maquette | Réalisation |
|---|---|
| Icône du splash (S2) | `res/drawable/splash_icon.xml` : logo 4d sur tuile `#182530`, 112 dp dans le canevas 240 dp (translate 64, scale 3,5), dans le cercle de 160 dp ; remplace l'ancien logo teal |
| Animation (S6) | `res/drawable/splash_icon_animated.xml` : tuile visible à 0 ; barres teal translateX −5 → 0 + opacité, 400 ms chacune, départs 0 / 100 / 200 ms ; triangle corail 0,6 → 1 autour de son centre + opacité, 600 ms dès 400 ms ; `interpolator/mm_standard.xml` = cubic-bezier(.2, 0, 0, 1) ; durée 1000 ms dans `values-v31/themes.xml`. Animations système coupées : Android affiche l'image finale |
| Branding (S2) | `splash_branding.png` en mdpi → xxxhdpi (200 × 80 dp) : « Miarina Media » Manrope 22/800 −2 % `#F5F7FA` + « MIARINA » 11/600 +8 % `#64748B`, rendus avec la police Manrope du dépôt |
| Android ≤ 11 | `values/themes.xml` : le style `Theme.miarina_media.Splash` n'existait que pour Android 12+ ; ajouté pour Android 7–11 (compat AndroidX, icône statique, sans branding) |
| Maintien et sortie | Maintien inchangé (`ready` ou 3 s) ; sortie : fondu 300 ms, courbe de sortie (.3, 0, 1, 1), supprimée si les animations système sont coupées (`MainActivity.kt`) |
| Continuité → Accueil | `app/launch.ts` : une fois par chargement, le logo de l'en-tête part du centre de l'écran à la taille du splash (112 dp) et rejoint l'en-tête en 460 ms ; titre, carte de lien, actions rapides et « Reprendre » montent (380 ms, départs 300 / 140 / 200 / 260 ms) ; barre du bas 360 ms dès 220 ms. Mouvement réduit / Éco : fondus de 120 ms, pas de déplacement du logo |
| Démarrage long (S5) | `public/boot-slow.js` (script simple, chargé avant l'application) : si l'interface n'est pas là 2,5 s après le début de la page, sur Android, affiche logo, « Le démarrage prend plus de temps », « Miarina prépare l'interface. La lecture en cours n'est pas interrompue. » et « Relancer » (FR / EN selon la langue du système) ; React le remplace dès son premier rendu |

## Écarts

- **Migration (S4)** non faite : la base est ouverte et migrée avant que l'interface existe (copie préalable, UPD-10), l'écran React ne peut pas s'afficher pendant ce temps. Si la migration est longue, le splash reste au plus 3 s puis l'avis de démarrage long prend le relais.
- **Diagnostic (S5)** non fait : le journal local expurgé n'existe pas encore ; seul « Relancer » est proposé.
- **Mode Éco au lancement** : le splash système ne peut pas lire ce réglage de l'application avant le démarrage ; seule la coupure des animations système remplace l'animation par l'image finale. Côté React, Éco donne bien des fondus seuls.
- **Thème clair (S3)** : non appliqué, comme prévu par la maquette tant que le thème clair Android n'est pas livré.

## Vérifications

- Tests : `src/app/launch.test.ts` (une fois par chargement, pas de déplacement en mouvement réduit, trajectoire et taille), `src/test/boot-slow.test.ts` (avis après 2,5 s sur Android, rien si l'interface est là, rien sous Windows) ; 192 tests frontend, TypeScript, ESLint ; build Android x86_64 sans avertissement.
- Émulateur Android 15 (1080 × 2400, 420 dpi), APK release x86_64, enregistrements de l'écran de l'émulateur : barres puis triangle visibles pendant l'animation, branding sous le logo, maintien jusqu'au rendu, Accueil apparaissant sous le splash qui s'efface ; icône 4d dans le lanceur. Au premier lancement après installation l'Accueil est arrivé après le plafond de 3 s (écran vide ~1 s : cas que couvre désormais l'avis S5).
- Non vérifié : Android 7–11, téléphone réel, l'avis S5 en situation réelle (couvert par les tests).
