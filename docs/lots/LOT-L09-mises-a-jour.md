# Fiche LOT-L09 — Mises à jour robustes (Windows)

- Statut : fait et recetté pour Windows ; Android (UPD-06) et Authenticode (UPD-09) hors lot
- Exigences CDC : § 9 UPD-01 à UPD-05, UPD-07, UPD-08, UPD-10 ; test T-06
- Protocole et limites : `docs/app-updates.md`

## Ce qui change

| Exigence | Réalisation |
|---|---|
| UPD-01 recette entre deux versions | Canal de test local (fonction cargo `update-test-channel` : serveur en boucle locale, clé de test) ; deux versions de recette installées sous un autre nom, identifiant et exécutable que l'application réelle (voir « Recette » ci-dessous) |
| UPD-02 authenticité | Manifeste limité à 64 Kio (annoncé et lu), signature Ed25519 par une clé épinglée (liste prête pour la rotation), canal signé, URL exacte du serveur et du nom d'artefact, taille et format d'empreinte ; fichier refusé dès qu'il dépasse la taille, s'il est tronqué ou si son SHA-256 diffère ; nouvelle vérification en flux juste avant l'installation |
| UPD-03 annulation, reprise, cache prêt | Bouton Annuler ; fichier partiel gardé après annulation ou coupure ; reprise `Range` + `If-Range` (ETag fort, sinon Last-Modified), recommencement si le serveur renvoie le fichier entier, partiel supprimé si la plage est refusée ; manifeste signé gardé à côté et revérifié à chaque lancement ; téléchargement terminé retrouvé « prêt » après relance ; nettoyage au lancement des fichiers d'une version installée ou dépassée (et des restes de 0.1.7) |
| UPD-04 installation au bon moment | Refusée pendant une conversion (bouton désactivé, raison affichée) ; la carte dit avant le clic ce qui sera interrompu : téléchargements (retrouvés en pause), lecture, partage torrent |
| UPD-05 téléchargement automatique | Réglage réel, désactivé par défaut ; seulement si Windows annonce un réseau sans coût (ni itinérance, ni limite de données atteinte ou proche) et hors économiseur de batterie ; n'installe jamais |
| UPD-07 clés et canaux | Canal Stable / Bêta dans les réglages ; la bêta reçoit aussi les versions stables plus récentes ; procédure de rotation et de sauvegarde de la clé dans `app-updates.md` |
| UPD-08 publication cohérente | `sign-app-update.mjs` signe le canal et refuse un manifeste trop grand ; nouveau `verify-app-update.mjs` (lecture seule) : signature avec la clé épinglée, canal, noms, et chaque artefact téléchargé et comparé (taille, SHA-256) |
| UPD-10 migration et retour arrière | Copie `VACUUM INTO` de la base avant toute migration (3 copies gardées) ; migrations dans une transaction ; base d'un schéma plus récent jamais ouverte ni modifiée ; message Windows clair (FR/EN selon la langue de Windows) au lieu d'une fenêtre qui ne s'ouvre pas |

Fichiers principaux : `crates/storage/src/upgrade.rs`, `apps/client/src-tauri/src/data_guard.rs`, `apps/client/src-tauri/src/updates.rs`, `apps/client/src/features/settings/useUpdates.ts`, `SettingsScreen.tsx` (onglet Mises à jour), `apps/client/scripts/sign-app-update.mjs`, `verify-app-update.mjs`.

## Tests automatiques

- Rust `storage::upgrade` (5) : base neuve sans copie ; schéma 5 copié puis migré avec ses données ; schéma plus récent refusé sans écrire un octet ; migration qui échoue → schéma précédent conservé et copie présente ; seules les 3 copies les plus récentes restent.
- Rust `updates` (8) : manifeste signé accepté pour sa plateforme ; autre clé, charge modifiée, signature invalide refusées ; manifeste trop grand ; URL étrangères ou incohérentes (http, autre hôte, suffixe d'hôte, autre version, `..`, mauvais type) ; taille nulle ou trop grande, empreinte trop courte, version non numérique ; canaux non interchangeables ; taille et empreinte du fichier (tronqué, trop long, altéré) ; validateurs et `Content-Range`.
- Rust `data_guard` (1) : messages.
- Frontend : store des mises à jour (8 cas : pas d'installation automatique, téléchargement automatique seulement autorisé, échec de vérification, annulation, reprise après relance, refus Android, conversion, réglages) ; écran Réglages › Mises à jour (états de la maquette).

## Recette (T-06) — 2026-11-12, Windows 11 (machine de L00)

Montage : versions **0.1.98**, **0.1.99** puis **0.1.100** compilées depuis ces sources avec `update-test-channel`, identifiant `org.miarina.media.recette`, nom « Miarina Media Recette », exécutable `miarina-media-recette.exe` (installation et données séparées de l'application réelle, jamais touchée). Serveur de test en boucle locale (`127.0.0.1:8742`, ETag, Last-Modified, plages, ralentissement et coupure simulés), manifestes signés par une clé de test jetable. Interface pilotée par le port de débogage de la WebView, installateur NSIS piloté par ses propres fenêtres (aucune saisie clavier ou souris sur le bureau).

| Étape | Résultat |
|---|---|
| Base de recette ramenée au schéma 8 (table de la v9 retirée), installation silencieuse de 0.1.98, premier lancement | copie `backups/miarina-schema8-….db` créée (schéma 8, mêmes données), base migrée au schéma 9 ; 28 médias, 1 playlist (3 éléments), 10 positions, historique et tâches identiques dans la copie et la base |
| Manifestes altérés servis à 0.1.98 | refusés : signature modifiée (« signature is invalid »), URL d'un autre serveur (« Invalid release metadata »), manifeste de 70 Ko (« too large »), manifeste bêta servi comme stable (« another channel ») ; empreinte fausse : téléchargement complet puis refus (« checksum mismatch »), fichier partiel supprimé |
| Réglages › Mises à jour, Télécharger puis Annuler après 10 s | carte conforme à la maquette (disponible → téléchargement « x / y · vérification à la fin » + Annuler) ; 16,8 Mio gardés, « Reprendre le téléchargement » proposé |
| Fermeture et relance de 0.1.98 | téléchargement partiel retrouvé (17 629 184 octets, manifeste revérifié) |
| Reprise avec coupure réseau simulée après 20 Mo | requête `Range: bytes=17629184-` + `If-Range` (ETag) → 206 ; coupure : partiel = 17 629 184 + 19 988 480 octets exactement ; message brut de la bibliothèque HTTP affiché (corrigé, voir ci-dessous) |
| Nouvelle reprise | `Range: bytes=37617664-` → 206, 58 042 191 octets ; total 95 659 855 = taille signée ; SHA-256 vérifié, « 0.1.99 est prête » |
| Relance avec la mise à jour prête | « prête » retrouvée sans aucune requête au serveur |
| Lecture en cours, carte prête | « La lecture en cours sera arrêtée » affiché avant le clic |
| « Installer maintenant » | 0.1.98 se ferme, l'installateur s'ouvre (pages : bienvenue, « déjà installé », dossier, installation, terminé), 0.1.99 démarre ; version rapportée par l'application 0.1.99, aucune mise à jour plus récente, fichiers de mise à jour du cache supprimés au lancement ; données identiques (schéma 9, mêmes comptes, playlist « Recette native ») ; icônes 4d dans l'installateur et la barre de titre |
| Base passée au schéma 10, lancement de 0.1.99 | base **non modifiée** (même empreinte, schéma 10, aucune copie), mais l'application **s'arrêtait** (code 0xC0000409) au lieu d'afficher le message : la boîte de message ouverte pendant le démarrage de Tauri laissait traiter des événements de fenêtre avant l'existence de l'état (« state() called before manage() »). Corrigé : sous Windows la base est ouverte avant la construction de l'application, la boîte s'affiche sans fenêtre ni boucle d'événements ; repli dans `setup` affiché depuis un autre fil |

Correctifs issus de la recette, compilés dans **0.1.100** :

| Correctif | Vérification |
|---|---|
| Base refusée : message affiché avant la création de l'application (Windows), repli dans `setup` depuis un autre fil | 0.1.100, base passée au schéma 10 : seule fenêtre du processus, la boîte « Cette bibliothèque a été mise à jour par une version plus récente de Miarina Media : la version 0.1.100 ne peut pas l'ouvrir sans risque (schéma 10, cette version s'arrête au schéma 9). Vos données n'ont pas été modifiées… » ; après OK le processus se termine, aucun plantage enregistré, base identique (même empreinte SHA-256, schéma 10, aucune copie) ; remise au schéma 9 : l'application s'ouvre normalement |
| Coupure réseau : code `update_network` et message « Connexion au serveur de mises à jour perdue. Réessayez : un téléchargement reprend là où il s'est arrêté. » au lieu du texte de la bibliothèque HTTP | 0.1.100, serveur arrêté : la vérification renvoie `update_network` ; affichage couvert par le test du store |

Mise à jour 0.1.99 → 0.1.100 par l'interface : trouvée (comparaison numérique 0.1.100 > 0.1.99), téléchargée, vérifiée, installée ; 0.1.100 rapporte sa version, ne trouve rien de plus récent, cache nettoyé, données identiques (schéma 9, 28 médias, playlist et positions). Pendant ce second passage, le pilote de l'installateur n'a vu aucun changement de page pendant 4 minutes après « déjà installé » puis l'installation s'est terminée : cause non établie (désinstallation de l'ancienne version plus longue, ou interaction dans la fenêtre).

## Points ouverts

- Versions de recette désinstallées après l'essai (désinstallation silencieuse : dossier, raccourcis et entrée de désinstallation supprimés ; données de recette conservées).

- Textes français de l'installateur fournis par Tauri fautifs (« La version ancien de … est installée », « Déja installé ») : fichier de langue NSIS personnalisé à prévoir.
- Android : UPD-06 (service de premier plan, règles réseau, écran de migration du handoff splash) ; Authenticode : UPD-09.
