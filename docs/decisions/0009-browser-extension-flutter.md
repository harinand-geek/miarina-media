# 0009 — Extension Chrome/Edge de l'app Flutter : identifiant fixe, connexion en un clic, lien ouvert dans l'analyse

Date : 2026-11-23 · Statut : **acceptée** (choix technique délégué) · Écran Réglages › Extension navigateur (EXT-01) du handoff `design/design_handoff_windows_v2/`

## Contexte

La 0.1.x avait une extension en mode développeur : l'utilisateur recopiait son identifiant dans les Réglages, et les liens envoyés s'empilaient dans une boîte « Liens reçus » à vider ensuite. La 0.2.0 l'a retirée. La maquette Windows v2 prévoit un assistant en trois étapes : installer l'extension, appairer ce PC avec un code (« MM-4821 »), tester la connexion. Elle prévoit aussi l'interrupteur « Accepter les liens envoyés par l'extension · Rien n'est capturé automatiquement » et, dans Obtenir, la mention « Ou envoyez-le depuis l'extension Chrome/Edge ».

Chrome et Edge parlent à une application locale par native messaging. Le navigateur ne lance l'hôte que si une clé du registre de l'utilisateur pointe vers un manifeste qui autorise explicitement l'identifiant de l'extension. Il n'y a ni port réseau ni secret à échanger.

## Décision

1. **Identifiant fixe.** Le manifeste de l'extension porte une clé publique (`key`), d'où l'identifiant `dlfhnodjkhddcjeeoaeminkboapodnoa`. La clé privée reste hors du dépôt (`builds/extension-key.pem`).
2. **Connexion par l'application.** « Connecter » (ou l'interrupteur) écrit le manifeste dans le dossier de données de l'app. Ce manifeste désigne le pont `miarina-browser-bridge.exe` installé à côté de l'app, et cette seule extension. L'app inscrit ensuite une valeur par navigateur (Chrome, Edge) sous HKCU, sans droits d'administrateur. « Déconnecter » et la désinstallation ne retirent que les inscriptions de cette copie de l'app.
3. **Écart avec la maquette : pas de code d'appairage.** Le registre et l'identifiant autorisé remplissent déjà ce rôle, et un code n'ajouterait aucune sécurité. L'étape 2 devient « Connecter ce PC », en un clic. Les étapes 1 (installer) et 3 (tester, avec « Dernier test : réussi à … ») restent.
4. **Un lien envoyé ouvre son analyse.** Le pont valide le lien (http(s), sans identifiants, borné) puis lance l'app avec `--link <url>`. La règle d'une seule fenêtre le passe à la fenêtre déjà ouverte. L'app ouvre la page d'analyse d'Obtenir, et rien ne se télécharge sans choix de l'utilisateur. La boîte « Liens reçus » de la 0.1.x disparaît.
5. **Installation.** Tant que l'extension n'est pas publiée dans les boutiques Chrome et Edge, elle est livrée dans `browser-extension\` à côté de l'app. L'utilisateur la charge en mode développeur (« Charger l'extension non empaquetée ») ; l'étape 1 ouvre ce dossier. La publication en boutique est une action extérieure : elle demandera l'accord du propriétaire.

## Conséquences

- L'extension ne lit rien dans les pages. Seul le lien choisi par l'utilisateur part, et seulement vers l'app locale.
- Une mise à jour garde la connexion. Si l'app change de dossier, le manifeste est réécrit à la lecture de l'état.
- Firefox n'est pas pris en charge (pas d'identifiant ni de signature Mozilla).
