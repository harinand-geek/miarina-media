# media.miarina.org — site de présentation

Site statique (HTML, CSS, un petit script), d'après `design/Miarina Media - Landing.dc.html`. Le **contenu décrit ce que fait réellement la version publiée** (la maquette sert pour l'apparence, pas pour les promesses). Aucune ressource externe : polices et icônes auto-hébergées, aucune mesure d'audience.

```
index.html
assets/site.css, site.js
assets/fonts/   Manrope, JetBrains Mono (latin), icons.woff2 = Material Symbols Rounded réduit aux icônes utilisées
assets/img/     captures réelles de l'application (contenus sous licence libre uniquement)
deploy/nginx/   vhost du VPS
```

Les fichiers téléchargeables (`downloads/`) ne sont pas versionnés : ils viennent des builds (`docs/test-builds.md`).

## Aperçu local

```bash
python -m http.server 8090 --directory apps/website   # http://127.0.0.1:8090
```

## Hébergement

VPS `169.58.142.102` (aaPanel, nginx 1.30), même serveur que `cv.harinjaka.org`, accès SSH root avec la clé `~/.ssh/digitalsub_vps` (le `ssh` de Git Bash ; celui de Windows refuse la clé à cause de ses droits NTFS). DNS : Cloudflare (proxifié), `media.miarina.org` pointe déjà sur ce VPS.

```
/www/wwwroot/media.miarina.org/
├── public_html/          index.html, assets/, downloads/
└── acme/                 défis Let's Encrypt (certbot webroot, renouvellement automatique)
/www/server/panel/vhost/nginx/media.miarina.org.conf   ← deploy/nginx/media.miarina.org.conf
```

### Mettre à jour le site ou publier une version

1. Mettre à jour `index.html` : version, tailles, **empreintes SHA-256**, tableau des plateformes, journal des versions.
2. Envoyer :

```bash
stage=$(mktemp -d)
cp -r apps/website/index.html apps/website/assets "$stage/"
mkdir "$stage/downloads"   # y copier les nouveaux fichiers, noms versionnés
tar czf /tmp/site.tar.gz -C "$stage" .
scp -i ~/.ssh/digitalsub_vps /tmp/site.tar.gz root@169.58.142.102:/root/
ssh -i ~/.ssh/digitalsub_vps root@169.58.142.102 \
  'tar xzf /root/site.tar.gz -C /www/wwwroot/media.miarina.org/public_html && chown -R www:www /www/wwwroot/media.miarina.org && rm /root/site.tar.gz'
```

3. Vérifier (télécharger **dans un fichier** : sous Git Bash, `curl | sha256sum` altère les données binaires) :

```bash
curl -s -o /tmp/f.apk https://media.miarina.org/downloads/<fichier>.apk && sha256sum /tmp/f.apk
```

Après une modification du vhost : le recopier, puis `nginx -t && nginx -s reload` (ne jamais recharger si le test échoue : les autres sites du VPS partagent nginx).
