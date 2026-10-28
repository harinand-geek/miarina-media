# Landing v3 — vérification du 28 octobre 2026

Référence : `design/design_handoff_landing_v3/README.md` et prototype autonome.
Implémentation React pré-rendue, styles externes, polices existantes auto-hébergées.

Contrôles exécutés dans Edge headless :
- Démo analyse → formats → audio 128 kbps → progression → fin → recommencer.
- Onglets formats, filtre plateformes, thème conservé après rechargement, menu mobile.
- Largeurs 320, 390, 768, 900, 1280 et 1440 px : aucun débordement horizontal.
- Sans JavaScript : menu natif, trois catégories de formats et tableau complet.
- CSP de production : aucune erreur de script, aucun style inline ; mouvement réduit,
  chargement différé des captures, section active et indicateur des versions vérifiés.
- Captures clair/sombre/mobile examinées, comparaison avec le prototype à 1440 px.
- Build TypeScript/Vite/SSR réussi. Pas de test sur téléphone physique.

Adaptations factuelles : tailles de démo fictives explicites, aucun transfert réel,
reprise conditionnelle à la source, limites YouTube/MP3 de l'APK public, versions
Windows et Android distinctes. Confidentialité : thème enregistré localement et
constat du script Cloudflare précédemment bloqué, sans promesse générale non vérifiée.

Publication effectuée sur media.miarina.org après sauvegarde du site et contrôle
SHA-256 de l'archive et du paquet Windows. Vérification publique : hydratation,
démo interactive et pages accueil/licences/confidentialité ; téléchargements HTTP 200,
Windows 0.1.4 (72 483 476 octets), Android 0.1.3 (36 928 485 octets).
L'APK 0.1.4 n'est pas publié : voir android-extractor-validation.md.
