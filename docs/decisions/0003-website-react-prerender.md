# 0003 — Site de présentation en React, pré-rendu avec Vite

- **Date :** 2026-10-18
- **Statut :** accepté (demande de l'utilisateur : « réaliser en React la landing page »)

## Contexte

Le site `media.miarina.org` était écrit en HTML statique avec un petit script. L'utilisateur a demandé une version React. `CLAUDE.md` suggère Next.js pour un site marketing optionnel.

Le vhost nginx impose une CSP stricte : `script-src 'self'; style-src 'self'`, sans `unsafe-inline`.

## Décision

React 19 + Vite, avec **pré-rendu au build** (`vite build --ssr` puis `scripts/prerender.mjs`) : une page HTML complète par route, hydratée ensuite par React. Mêmes versions de React, Vite et TypeScript que `apps/client`.

Écart par rapport à `CLAUDE.md` (Next.js) : l'export statique de Next.js injecte des scripts en ligne (données de route, amorçage), refusés par la CSP. Les autoriser obligerait à affaiblir la CSP ou à gérer des empreintes par build. Le pré-rendu Vite produit uniquement un `<script type="module" src=…>` et une feuille de style externes.

## Conséquences

- Le contenu est lisible sans JavaScript et indexable ; les boutons de téléchargement fonctionnent sans JavaScript.
- Le JavaScript chargé passe d'un petit script à environ 77 Ko compressés (React DOM). Accepté, à la demande de l'utilisateur.
- La version et les empreintes sont saisies une seule fois, dans `src/release.ts`.
- Le déploiement envoie `apps/website/dist/` (voir `apps/website/README.md`).
