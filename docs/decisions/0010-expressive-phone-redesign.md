# 0010 — Refonte « expressive » de l'app téléphone

Date : 2026-11-25 · Statut : accepté par le propriétaire (« ok vasy »)

## Contexte

Le propriétaire a partagé 18 captures d'un lecteur musical Android vu sur
les réseaux sociaux (`C:\Users\HP\Downloads\autre_app`, hors dépôt) et a
demandé le même design et les mêmes fonctions sur mobile, « bien animé,
élégant, premium ». Ces captures suivent **Material 3 Expressive**, le
langage visuel public de Google. Elles servent de référence fonctionnelle
et de style ; l'app reste Miarina Media (logo, Manrope, icônes Phosphor),
rien n'est copié à l'identique et l'app de référence n'est jamais nommée
publiquement.

L'analyse des écarts a été présentée au propriétaire avant toute
modification (fonctions déjà présentes / manquantes).

## Décisions

1. **Navigation inchangée** : les quatre onglets Musique · Cinéma · Focus ·
   Obtenir restent ; Bibliothèque et Artistes restent dans Musique (puces).
2. **Thème** : sombre par défaut comme avant, clair disponible ; les
   couleurs tirées des pochettes marchent dans les deux.
3. **Rien qui passe par Internet** : pas de « compléter les infos depuis un
   service en ligne », pas de photos d'artistes téléchargées. La « photo »
   d'un artiste est la pochette d'un de ses albums.
4. **Couleurs de pochette** : couleur dominante (quantizer + score de
   `material_color_utilities`, déjà livré par `material_ui`, ajouté en
   dépendance directe à la même version 0.13.0), calculée sur une image de
   64 px dans un isolate, au plus deux à la fois, mémorisée pour la
   session (400 entrées). Palette tonale « tonal spot » → fond, boutons,
   lecture, pistes (`lib/design/cover_tones.dart`).
5. **Composants** (`lib/design/widgets/`) : curseur et progression ondulés
   (`wavy_slider.dart`, l'onde ne tourne que pendant la lecture), forme
   « fleur » pour les artistes, boutons dont les coins se resserrent à
   l'appui et groupe dont le bouton tenu s'élargit, titre défilant, disques
   (`expressive.dart`), fiches d'actions en blocs groupés
   (`action_sheet.dart`). Mouvement réduit respecté partout.
6. **Volume** : la barre de volume du lecteur règle le volume musique du
   téléphone (le même que les boutons physiques, suivis par un
   `ContentObserver`), pas un volume interne à l'app.
7. **Journal d'écoute** (étape 3) : secondes de musique réellement
   entendues, par jour et par artiste, 35 jours, dans le magasin local de
   lecture. Podcasts, cours, livres et vidéos ne comptent pas.

## Étapes

1. Bases du style (couleurs de pochette, composants) — fait.
2. Lecteur plein écran, mini-lecteur, fiches d'actions — fait.
3. Accueil Musique (carrousel des dernières écoutes, raccourcis, rangées
   teintées, les plus joués, vos artistes, mix du jour, compteurs, à
   découvrir, album au hasard, artiste de la semaine, 7 derniers jours,
   historique, bouton « Tout mélanger ») — fait. Le Windows garde son
   accueil W-00. Pas d'« Épinglés » ni de « Genre du jour » : il n'existe
   pas encore d'épinglage, et le genre n'est pas exposé par le cœur.
4. Bibliothèque (titre, recherche, onglets avec leurs nombres, tri, filtres,
   grille ou liste mémorisée, lignes en blocs arrondis avec le format du
   fichier), albums en cartes teintées, artistes en forme de fleur, pages
   album / artiste (pochette fondue dans la page, Lecture / Aléatoire aux
   couleurs de la pochette, fiche d'actions partagée) — fait. Le badge de
   qualité montre le format (FLAC, MP3…) : la profondeur en bits n'est pas
   encore exposée par le cœur aux listes.

Chaque étape : analyse, tests, captures (outil
`test/tool/phone_shots_test.dart`, sans appareil), commit et push. Essai
sur le Redmi du propriétaire avant toute publication ; rien n'est publié
sans son accord.

## Windows (2026-11-25)

Après la publication de l'Android 0.2.9, le propriétaire a demandé le même
style sur PC, sans toucher aux fonctions. Fait : barre de lecture aux
couleurs de la pochette (barre ondulée, boutons en pilule, volume),
accueil W-00 avec les sections du téléphone sur deux colonnes, la carte
« Reprendre » et les listes automatiques gardées en tête, grilles albums
(cartes teintées, lecture au survol) et artistes (forme fleur, nombre
d'albums), en-tête des pages album / artiste en panneau teinté, écran
« En lecture » sur le fond de la pochette (le réglage « fond de pochette »
reste respecté). La table des titres, la barre latérale et les menus
gardent leur forme.

