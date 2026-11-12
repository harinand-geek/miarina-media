# media.miarina.org — site de présentation

> Note (2026-11-12) : les anciennes maquettes citées ici (`design/*.dc.html` v1, `design/design_handoff_landing_v3/`) ont été retirées du dépôt sur décision du propriétaire ; elles restent consultables dans l'historique git (`git show 63f712a:design/…`). Les maquettes en vigueur sont `design/design_handoff_windows_v2`, `design_handoff_android_v2` et `design_handoff_splash`.

Site en React (Vite), d'après `design/Miarina Media - Landing.dc.html`. Le **contenu décrit ce que fait réellement la version publiée** (la maquette sert pour l'apparence, pas pour les promesses). Aucune ressource externe : polices et icônes auto-hébergées, aucune mesure d'audience.

Les pages sont **pré-rendues au build** : chaque fichier HTML contient déjà tout le texte (lisible sans JavaScript, indexable), puis React prend le relais dans le navigateur. Pas de script ni de style en ligne : la CSP du vhost l'interdit (`docs/decisions/0003-website-react-prerender.md`).

```
index.html               gabarit (<!--head-->, <!--app--> remplis au pré-rendu)
src/release.ts           version, fichiers, tailles, empreintes, journal, tableau des plateformes
src/routes.tsx           pages et balises <head> (titre, description, Open Graph)
src/pages/               Home, Licences, Confidentialite
src/components/          barre du haut, pied de page, boutons de téléchargement
src/styles/site.css      feuille de style (reprend la maquette)
src/entry-server.tsx     rendu HTML d'une page (build uniquement)
scripts/prerender.mjs    écrit dist/index.html, licences.html, confidentialite.html
public/assets/fonts/     Manrope, JetBrains Mono (latin), icons.woff2 = Material Symbols Rounded réduit aux icônes utilisées
public/assets/img/       captures réelles de l'application (contenus sous licence libre uniquement)
deploy/nginx/            vhost du VPS
```

Les fichiers téléchargeables (`downloads/`) ne sont pas versionnés : ils viennent des builds (`docs/test-builds.md`).

## Développement

```bash
pnpm --filter @miarina/website dev        # http://localhost:5173 (page d'accueil)
pnpm --filter @miarina/website build      # typecheck + build + pré-rendu → apps/website/dist
pnpm --filter @miarina/website preview    # sert dist/ : /, /licences.html, /confidentialite.html
```

Une nouvelle icône Material doit être ajoutée au sous-ensemble `icons.woff2`, sinon elle s'affiche comme du texte.

## Hébergement

VPS `169.58.142.102` (aaPanel, nginx 1.30), même serveur que `cv.harinjaka.org`, accès SSH root avec la clé `~/.ssh/digitalsub_vps` (le `ssh` de Git Bash ; celui de Windows refuse la clé à cause de ses droits NTFS). DNS : Cloudflare (proxifié), `media.miarina.org` pointe déjà sur ce VPS.

```
/www/wwwroot/media.miarina.org/
├── public_html/          contenu de dist/, plus downloads/
└── acme/                 défis Let's Encrypt (certbot webroot, renouvellement automatique)
/www/server/panel/vhost/nginx/media.miarina.org.conf   ← deploy/nginx/media.miarina.org.conf
```

### Mettre à jour le site ou publier une version

1. Mettre à jour `src/release.ts` : version, tailles, **empreintes SHA-256**, journal des versions, tableau des plateformes. Les liens de téléchargement reçoivent `?v=<8 premiers caractères de l’empreinte>` automatiquement (**Cloudflare met en cache par URL**) ; le JS et le CSS ont un nom haché par Vite.
2. `pnpm --filter @miarina/website build`
3. Envoyer :

```bash
stage=$(mktemp -d)
cp -r apps/website/dist/. "$stage/"
mkdir "$stage/downloads"   # y copier les nouveaux fichiers, noms versionnés
tar czf /tmp/site.tar.gz -C "$stage" .
scp -i ~/.ssh/digitalsub_vps /tmp/site.tar.gz root@169.58.142.102:/root/
ssh -i ~/.ssh/digitalsub_vps root@169.58.142.102 \
  'tar xzf /root/site.tar.gz -C /www/wwwroot/media.miarina.org/public_html && chown -R www:www /www/wwwroot/media.miarina.org && rm /root/site.tar.gz'
```

Les anciens `assets/index-*.js|css` peuvent ensuite être supprimés du serveur.

4. Vérifier (télécharger **dans un fichier** : sous Git Bash, `curl | sha256sum` altère les données binaires) :

```bash
curl -s -o /tmp/f.apk https://media.miarina.org/downloads/<fichier>.apk && sha256sum /tmp/f.apk
```

Après une modification du vhost : le recopier, puis `nginx -t && nginx -s reload` (ne jamais recharger si le test échoue : les autres sites du VPS partagent nginx).
