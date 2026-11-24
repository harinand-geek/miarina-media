# Compression vidéo — étude et réglages (Outils PC › Convertir › Compresser)

Date : 2026-11-24 · Demande du propriétaire : la meilleure compression possible à la meilleure qualité possible (exemple : une vidéo de 5 min de 1 Go ramenée vers 200 Mo).

## Contraintes

- Le FFmpeg livré est une build **LGPL** : ni x264 ni x265. Encodeurs vidéo disponibles : H.264 matériel (NVIDIA NVENC, Intel QSV, AMD AMF, Media Foundation) et OpenH264 ; HEVC matériel et kvazaar ; **AV1 : SVT-AV1, libaom, rav1e** (logiciels) et AV1 matériel (NVIDIA Ada, Intel Arc, AMD RDNA3). Mesure de qualité : **libvmaf** est présent.
- Le réglage doit fonctionner sur tous les PC, avec ou sans carte graphique récente.

## Méthode

- Source : deux extraits de 45 s du film libre *Sintel* (Blender Foundation, CC BY 3.0), 1920 × 818, H.264 à 10,5 Mbit/s : une scène calme (2 min 30) et une scène d'action (10 min), copiés sans réencodage.
- Pour chaque réglage : temps d'encodage, taille (son AAC 128 kbit/s stéréo compris) et **VMAF** contre la source (modèle par défaut, 1 image sur 3). Repères : 93 et plus, différence difficile à voir ; 95-96 et plus, transparent pour la plupart des gens.
- Machine : Intel Core i5-8300H (4 cœurs / 8 fils), NVIDIA GeForce GTX 1050 Ti (Pascal), Intel UHD 630. Script : `bench.py` de la session (non versionné), résultats ci-dessous.

## Résultats (45 s, source 60 Mo)

| Réglage | Calme : Mo / VMAF | Action : Mo / VMAF | Temps |
|---|---|---|---|
| Ancien Compresser (H.264 NVENC 2,8 Mbit/s fixe) | 17,9 / 95,1 | 16,7 / 90,2 | 3,5 s |
| H.264 NVENC p7 hq, qualité constante cq 23 | 41,3 / 98,5 | 35,8 / 93,5 | 5 s |
| H.264 NVENC cq 26 | 28,1 / 97,5 | 23,9 / 91,7 | 5 s |
| H.264 NVENC cq 29 | 19,2 / 95,9 | 16,3 / 89,2 | 5 s |
| H.264 QSV (Intel) global_quality 25 | 18,8 / 94,5 | 13,0 / 89,3 | 8 s |
| HEVC NVENC cq 26 | 31,5 / 97,6 | 26,3 / 92,4 | 9 s |
| HEVC NVENC cq 29 | 21,4 / 96,3 | 17,7 / 90,7 | 7 s |
| HEVC NVENC 10 bits cq 29 | 19,9 / 96,0 | 16,2 / 90,3 | 8 s |
| HEVC NVENC cq 32 | 14,6 / 94,2 | 11,9 / 88,3 | 6 s |
| **SVT-AV1 preset 8, crf 26** | 29,6 / 98,0 | 14,7 / 90,8 | 27 s |
| **SVT-AV1 preset 8, crf 30** | 22,2 / 97,5 | 11,1 / 89,5 | 26 s |
| SVT-AV1 preset 8, crf 34 | 16,5 / 96,7 | 8,3 / 87,7 | 26 s |
| SVT-AV1 preset 8, crf 38 | 12,5 / 95,7 | 6,3 / 85,7 | 25 s |
| SVT-AV1 preset 6, crf 36 | 13,1 / 96,9 | 6,5 / 87,4 | 43 s |
| SVT-AV1 preset 8, débit 2 Mbit/s | 12,6 / 95,9 | 9,8 / 88,9 | 30 s |
| HEVC QSV (Intel) | refusé par le pilote (« Invalid FrameType ») | — | — |

À qualité égale, **AV1 (SVT-AV1) donne les plus petits fichiers** : −35 % face au meilleur H.264 sur la scène calme (VMAF ≈ 95,8 : 12,5 contre 19,2 Mo), −21 % à VMAF ≈ 97,5, −12 à −17 % sur la scène d'action (VMAF ≈ 90,5). Le HEVC de la carte Pascal n'apporte presque rien face à son H.264 (pas d'images B en HEVC sur cette génération). Le preset 6 de SVT-AV1 coûte 70 % de temps en plus pour un gain faible. Vitesse de SVT-AV1 preset 8 en 1080p sur ce processeur : environ 1,8 fois le temps réel ; une vidéo de 5 min se compresse en un peu moins de 3 min.

## Réglages retenus (`rust/src/converter.rs`, `("video", "compress")`)

- **Par défaut : AV1**, SVT-AV1 preset 8, **10 bits** (moins de bandes dans les dégradés, profil Main que tout décodeur AV1 lit), MP4 (`+faststart`), son AAC 128 kbit/s stéréo. Qualité : **Haute** crf 26, **Équilibrée** crf 30 (par défaut), **Petite** crf 36. Résolution : celle de la source, 1080p au plus si rien n'est choisi.
- **Taille maximale** (par fichier, en Mo) : débit vidéo = taille × 8 / durée − 128 kbit/s de son, × 0,93 ; mode VBR de SVT-AV1. Le fichier reste sous la taille demandée (essai : objectif 10 Mo sur la scène d'action → 7,7 Mo ; sur une vidéo longue l'écart se réduit). L'exemple du propriétaire (5 min, 200 Mo) donne 5,1 Mbit/s de vidéo, bien au-dessus de ce qu'il faut en AV1 pour une très bonne qualité en 1080p.
- **H.264 « lisible partout »** pour les appareils sans AV1 : qualité constante quand l'encodeur la propose (NVENC p7 hq cq 23 / 26 / 29 avec AQ spatiale et temporelle, look-ahead 32, 3 images B ; QSV veryslow global_quality 22 / 25 / 28), sinon débit selon la hauteur (Media Foundation, OpenH264).

Lecture de l'AV1 : Windows 10 et 11 (extension AV1 gratuite, préinstallée sur les versions récentes), Android 10 et plus, Chrome, Edge, Firefox, Safari récents et Miarina Media (libmpv, Media3). Les vieux appareils lisent le H.264.

## 3GP

Pour les anciens téléphones : H.264 Constrained Baseline (OpenH264, toujours disponible), 480p et 30 images/s au plus, AAC-LC 96 kbit/s (64 kbit/s en 240p et moins), conteneur 3GP (`3gp6`). Débit : 900 / 600 / 300 kbit/s en 480p (Haute / Moyenne / Petite), proportionnel à la hauteur.
