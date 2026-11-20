# 0008 — Mini-lecteur Windows : la fenêtre principale en mode compact

Date : 2026-11-20 · Statut : **acceptée** (choix technique délégué) · Écran W-M4 du handoff `design/design_handoff_lecture_ecouter/`

## Contexte

Le handoff décrit le mini-lecteur Windows comme une « fenêtre séparée 340 × 120, toujours au premier plan (épingle), redimensionnable jusqu'à 340 × 340 : la pochette passe alors au-dessus. La fenêtre principale est réduite et revient avec le bouton agrandir. Commandes aussi dans la miniature de la barre des tâches Windows (précédent, lecture, suivant). »

Dans Flutter, une seconde fenêtre native est une seconde instance du moteur Flutter (paquet multi-fenêtres tiers). Elle aurait sa propre mémoire de rendu et ne partagerait ni les providers ni le lecteur libmpv, qui vivent dans le moteur principal : il faudrait relayer l'état de lecture et les commandes entre les deux.

## Décision

1. **Le mini-lecteur est la fenêtre principale passée en mode compact.** Ctrl M, le bouton de la barre de lecture ou l'option de démarrage la réduisent à 340 × 120 (zone client). Elle est toujours au premier plan sauf si l'épingle est relâchée, redimensionnable en hauteur jusqu'à 340 × 340 (la pochette passe au-dessus à partir de 220 px) et déplaçable par toute sa surface. « Agrandir » lui rend sa taille, sa position et son état agrandi d'avant. Les écrans restent montés sans être dessinés : une vidéo garde sa surface et la navigation reprend où elle était.
2. **Boutons de la miniature de la barre des tâches** (précédent, lecture/pause, suivant) : code natif dans le runner Windows (`windows/runner/taskbar_buttons.cpp`, `ITaskbarList3`). Les pictogrammes viennent des polices système Segoe Fluent Icons (Windows 11) ou Segoe MDL2 Assets (Windows 10), donc ils suivent le style de Windows. Aucune dépendance ajoutée ; canal `miarina/taskbar` ; l'état n'est envoyé que s'il change, jamais à chaque tic de position.

## Conséquences

- Même résultat à l'écran que la maquette, sans second moteur ni synchronisation, conformément à la règle « performance d'abord ».
- Écart : la fenêtre principale n'existe pas à côté du mini-lecteur, elle devient le mini-lecteur. La maquette la réduit de toute façon pendant ce temps.
- La vidéo n'est pas affichée dans le mini-lecteur : il montre la pochette ou la vignette, et la lecture continue.
