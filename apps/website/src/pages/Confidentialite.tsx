import { Footer, TopBar } from '../components/Common';
import { RELEASE } from '../release';

export function Confidentialite() {
  return (
    <>
      <TopBar home={false} />
      <main className="doc">
        <span className="eyebrow">CONFIDENTIALITÉ</span>
        <h1>Ce que Miarina Media traite, et ce qu’il ne fait pas</h1>
        <p className="doc-lead">
          Description factuelle de la version {RELEASE.version} et de ce site, mise à jour le 18
          octobre 2026.
        </p>

        <h2>Dans l’application</h2>
        <ul>
          <li>
            <strong>Aucun compte, aucune publicité, aucune télémétrie.</strong> L’application
            n’envoie ni statistiques d’usage, ni rapports de plantage, ni identifiant d’appareil.
          </li>
          <li>
            <strong>Données enregistrées sur votre appareil uniquement :</strong> la file et
            l’historique des téléchargements (adresse source, titre, format, emplacement du
            fichier), l’index de la bibliothèque, les miniatures (Windows) et vos réglages. Elles ne
            sont envoyées nulle part. L’historique peut être effacé depuis l’application.
          </li>
          <li>
            <strong>Connexions réseau :</strong> l’application ne contacte que les adresses que vous
            lui donnez à analyser ou à télécharger, et, sous Windows, le serveur d’images du site
            analysé pour afficher la miniature de la vidéo (par exemple{' '}
            <span className="mono">i.ytimg.com</span> pour YouTube) ; cette image est enregistrée sur
            votre appareil. yt-dlp, FFmpeg et QuickJS-NG sont inclus dans l’installateur Windows ;
            s’ils manquent, l’application propose de les télécharger depuis GitHub, avec votre
            accord (versions et empreintes fixées, voir <a href="/licences.html">Licences</a>).
          </li>
          <li>
            <strong>Mise à jour de yt-dlp (Windows) :</strong> au plus une fois par jour,
            l’application demande à GitHub (<span className="mono">api.github.com</span>,{' '}
            <span className="mono">github.com</span>) si une nouvelle version de yt-dlp existe, et
            la télécharge si c’est le cas. Elle n’est utilisée que si sa signature est celle des
            développeurs de yt-dlp. Aucune donnée personnelle n’est envoyée.
          </li>
          <li>
            <strong>Permissions Android :</strong> Internet ; notifications (demandées au premier
            téléchargement, pour la progression et « Téléchargement terminé » ; vous pouvez
            refuser) ; service de premier plan pour continuer les téléchargements quand
            l’application est en arrière-plan ; garder l’écran allumé pendant la lecture. Aucun
            accès à vos contacts, photos ou position.
          </li>
          <li>
            <strong>Navigateur intégré (Windows) :</strong> comme tout navigateur, il charge les
            pages que vous ouvrez ; ces sites peuvent déposer leurs propres cookies, conservés sur
            votre appareil. Les pages visitées n’ont aucun accès aux fonctions de l’application.
          </li>
          <li>
            <strong>Vos fichiers</strong> restent dans le dossier de votre appareil où ils sont
            enregistrés.
          </li>
        </ul>

        <h2>Sur ce site</h2>
        <ul>
          <li>
            Pas de cookies, pas de mesure d’audience, pas de publicité, aucune ressource chargée
            depuis un autre site (polices et images sont hébergées ici).
          </li>
          <li>
            Comme tout serveur web, le serveur qui héberge ce site enregistre des journaux
            techniques (adresse IP, date, page demandée, navigateur) pour son fonctionnement et sa
            sécurité. Ils ne servent pas à mesurer l’audience.
          </li>
          <li>
            Le site passe par Cloudflare (réseau de diffusion et protection), qui traite les
            requêtes pour les acheminer.
          </li>
        </ul>
      </main>
      <Footer other={{ href: '/licences.html', label: 'Licences' }} />
    </>
  );
}
