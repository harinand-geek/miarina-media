# Handoff : Miarina Media — Splash screen Android

## Vue d'ensemble
Refonte du lancement de l'app Android (`apps/client/src-tauri/gen/android`) : splash système AndroidX avec le logo 4d animé, continuité vers l'Accueil, écran de migration après mise à jour et état de démarrage long. Répond au CDC-MIARINA-001 (UX-03, UPD-01, UPD-10).

## À propos des fichiers
`Miarina Media Splash.dc.html` est une **référence de design en HTML** (prototype cliquable + planches), pas du code de production. À recréer en natif Android (`themes.xml`, AnimatedVectorDrawable, `MainActivity.kt`) et dans le client React (`MobileShell`, `MobileHome`). Ouvrir le fichier dans un navigateur avec `support.js` à côté.

## Fidélité
Haute fidélité : couleurs, géométrie du logo, durées et courbes définitives.

## Quand chaque écran apparaît
| Écran | Fréquence |
|---|---|
| Splash système (icône animée) | À chaque **démarrage à froid** (processus tué). Pas au retour depuis l'arrière-plan (démarrage à chaud) : Android réaffiche l'app directement. |
| Animation logo → en-tête + cascade de l'Accueil | Après chaque démarrage à froid uniquement. |
| Squelettes « Reprendre » | Seulement si les données ne sont pas prêtes au premier rendu, et pas avant 200 ms. Souvent invisibles avec une base locale rapide. |
| Migration de la bibliothèque | **Une seule fois** au premier lancement après une mise à jour qui change le schéma, et seulement si elle dure plus de 400 ms. |
| Démarrage long | Exceptionnel : uniquement si l'interface n'est pas prête après 3 s. |

## Splash screen (AndroidX SplashScreen, `MainActivity.kt`)
Page séparée `Miarina Media Splash.dc.html` : prototype cliquable (lancement normal / après mise à jour / démarrage long) + planches S1–S6. **À corriger** : `res/drawable/splash_icon.xml` dessine l'ancien logo (tuile teal `#35C9BD`, glyphes `#101820`) → remplacer par le logo 4d.
- **Thème** (`values-v31/themes.xml`, `Theme.miarina_media.Splash`) : `windowSplashScreenBackground = @color/mm_bg (#101820)` ; `windowSplashScreenAnimatedIcon = @drawable/splash_icon_animated` (AnimatedVectorDrawable) ; `windowSplashScreenAnimationDuration = 1000` ; `android:windowSplashScreenBrandingImage = @drawable/splash_branding` (200 × 80 dp) ; `windowSplashScreenIconBackgroundColor` non défini.
- **Icône** : canevas 240 dp, cercle visible 160 dp, tuile 112 dp centrée (translate 64, scale 3.5 sur viewBox 32). Tuile `#182530` radius 8/32 ; triangle `M13 9.5v13l10-6.5z` `#FF7A45` ; barres teal `#35C9BD` (x6 y10.5 4×2.5, x4 y14.75 6×2.5, x6 y19 4×2.5, rx 1.25).
- **Animation** (S6) : tuile visible à 0 ms. Barres : `translateX −5 → 0` + alpha 0 → 1, 400 ms chacune, départs 0 / 100 / 200 ms (ordre haut, milieu, bas). Triangle : scale 0.6 → 1 (pivot au centre du triangle) + alpha, 600 ms, départ 400 ms. Interpolateur `PathInterpolator(.2,0,0,1)`. Fin à 1000 ms. Animations système désactivées ou mode Éco : AVD remplacée par l'icône statique.
- **Branding** : PNG « Miarina Media » Manrope 22/800 −2 % `#F5F7FA` + overline « MIARINA » 11/600 +8 % `#64748B`, centrés dans 200 × 80 dp ; densités mdpi → xxxhdpi. Jamais de tagline.
- **Maintien** : inchangé, `setKeepOnScreenCondition { !AppShellPlugin.ready && elapsed < 3000 }`. Sortie : `setOnExitAnimationListener` → fondu alpha 1 → 0 en 300 ms sur la vue du splash (l'Accueil est déjà rendu dessous). Pas d'écran de lancement React supplémentaire.
- **Clair** (S3) : `values` fond `#F6F8FA`, tuile `#101820`, wordmark `#101820` / overline `#526072`, seulement quand le thème clair de l'app est livré. Sinon, sombre partout (pas de flash clair → sombre).
- **Android ≤ 11** : `Theme.SplashScreen` compat, icône statique, pas de branding.
- **Continuité splash → Accueil** (prototype) : dans `setOnExitAnimationListener`, le logo du splash (112 dp, x150 y390) se déplace et rétrécit jusqu'au logo de l'en-tête (26 dp, x16 y51) en 460 ms `cubic-bezier(.2,0,0,1)` (translate −134/−339, scale .232, origine haut-gauche) ; le fond `#101820` s'efface en 360 ms (départ 60 ms) ; le branding disparaît en 150 ms. Le logo réel de l'en-tête apparaît à 460 ms. Accueil en cascade : opacité 0 → 1 + translateY 8 → 0 px, 380 ms — titre 300 ms, carte lien 140 ms, actions rapides 200 ms, Reprendre 260 ms ; barre de navigation translateY 100 % → 0 en 360 ms dès 220 ms. Côté natif, le plus simple est que le splash disparaisse sans animation de logo et que l'Accueil React joue lui-même le déplacement du logo à son premier rendu.
- **Chargement** : miniatures « Reprendre » en squelettes `#1F2F3B` (pulse d'opacité .6 ↔ 1, 1.2 s, décalage 150 ms), remplacées par un fondu de 240 ms quand les données sont prêtes.
- **Splash → Migration / Démarrage long** : le logo passe de 112 à 72 dp en remontant (translateY 84 px, scale 1.556 → 1, 420 ms) ; titre, texte et actions apparaissent en cascade (200 / 260 / 320 ms). Migration → Accueil : même déplacement vers l'en-tête (translate −154/−275, scale .361).
- Reduce motion / mode Éco : seulement des fondus de 120 ms, pas de déplacement.
- **S4 Migration** (UPD-01/10, écran React) : affiché après le splash si la migration dure plus de 400 ms. Logo 72, « Mise à jour de votre bibliothèque » 18/800, « Vos fichiers, playlists et positions de lecture sont conservés. » 14 `muted`, barre 240 × 6 teal (réelle, sinon indéterminée), compteur mono 12, pied mono 11 `#64748B` « 0.1.7 → 0.1.8 · sauvegarde créée ».
- **S5 Démarrage long** (UX-03) : si le plafond de 3 s est atteint sans `ready`. Titre « Le démarrage prend plus de temps », texte « Miarina prépare l'interface. La lecture en cours n'est pas interrompue. », « Relancer » (secondaire pill 48) + « Diagnostic » (ghost, journal local expurgé, aperçu avant partage).


## Design tokens
bg `#101820` · tuile du logo `#182530` · coral `#FF7A45` (ink `#1F0C03`) · teal `#35C9BD` (subtle `#1F3A3C`, chip `#5FE0D5`) · surface-2 `#1F2F3B` · line `#243545` · fg `#F5F7FA` · muted `#94A3B8` · faint `#64748B`. Clair : bg `#F6F8FA`, tuile `#101820`, texte `#101820` / `#526072`.
Typo : Manrope (wordmark 22/800 −2 %, overline 11/600 +8 %, titres 18/800, texte 14/500) ; JetBrains Mono 11–12 pour versions et compteurs.
Easing : standard `cubic-bezier(.2,0,0,1)`, sortie `cubic-bezier(.3,0,1,1)`.

## Assets
- `assets/miarina-media-icon-on-dark.svg` : logo 4d sur tuile `#182530` (source de l'icône du splash).
- Géométrie (viewBox 32) : tuile rx 8 ; triangle `M13 9.5v13l10-6.5z` ; barres x6 y10.5 4×2.5, x4 y14.75 6×2.5, x6 y19 4×2.5, rx 1.25.
- À produire : `drawable/splash_icon_animated.xml` (AVD), `drawable/splash_branding.png` (mdpi → xxxhdpi).

## Fichiers
- `Miarina Media Splash.dc.html` (prototype + planches S1–S6), `support.js`.
- Code concerné : `MainActivity.kt`, `AppShellPlugin.kt`, `res/values-v31/themes.xml`, `res/drawable/splash_icon.xml`, `features/home/MobileHome.tsx`.
