import { Footer, Icon, SectionHead, TopBar } from '../components/Common';
import { Downloads } from '../components/Downloads';
import { CHANGELOG, PLATFORMS, RELEASE } from '../release';

const FEATURES = [
  [
    'link',
    'Collez un lien',
    'Miarina Media lit l’adresse et vous montre ce qui peut être téléchargé.',
  ],
  [
    'tune',
    'Choisissez le format',
    'Qualité vidéo ou audio seul, avec la taille du fichier affichée avant de lancer.',
  ],
  [
    'download',
    'File de téléchargements',
    'Mettez en pause, reprenez plus tard. Si la connexion coupe, le téléchargement repart tout seul.',
  ],
  [
    'speed',
    'Éco, Équilibré, Performance',
    'Réglez combien de téléchargements tournent en même temps, selon votre machine.',
  ],
  [
    'video_library',
    'Bibliothèque',
    'Vos fichiers rangés par vidéo et audio, avec une recherche, des miniatures et la durée.',
  ],
  ['contrast', 'Clair ou sombre', 'Thème sombre par défaut, thème clair et mode système.'],
] as const;

const FORMATS: { icon: string; title: string; rows: [string, string, boolean?][] }[] = [
  {
    icon: 'movie',
    title: 'Vidéo',
    rows: [
      ['Jusqu’à 4K', 'si la source le propose'],
      ['MP4', 'H.264'],
      ['WebM', 'VP9'],
      ['Fichier original', 'lien direct'],
    ],
  },
  {
    icon: 'music_note',
    title: 'Audio',
    rows: [
      ['MP3 · 320, 256, 192 ou 128 kbps', 'conversion · Windows'],
      ['FLAC', 'conversion · Windows'],
      ['Piste audio d’origine', 'selon la source'],
      ['Fichier original', 'lien direct'],
    ],
  },
  { icon: 'closed_caption', title: 'Sous-titres', rows: [['SRT', 'Bientôt', true]] },
];

const PRIVACY = [
  ['block', 'Aucune publicité', 'Ni dans l’application, ni dans l’installateur.'],
  ['person_off', 'Aucun compte', 'Rien à créer pour utiliser l’application.'],
  [
    'hard_drive',
    'Vos fichiers restent chez vous',
    'Fichiers, historique et bibliothèque restent sur votre appareil.',
  ],
] as const;

const FAQ: [string, string][] = [
  [
    'Miarina Media est-il gratuit ?',
    'Oui. L’application est gratuite, sans publicité et sans compte.',
  ],
  [
    'Quels sites sont pris en charge ?',
    'Les liens directs vers un fichier vidéo ou audio fonctionnent sur Windows et Android. Sous Windows, les pages de nombreux sites vidéo sont analysées avec yt-dlp, inclus dans l’installateur avec FFmpeg et QuickJS-NG : rien à télécharger en plus. Les contenus privés, protégés par connexion ou par DRM, et les diffusions en direct ne sont pas pris en charge.',
  ],
  [
    'Ai-je le droit de télécharger ces contenus ?',
    'Cela dépend du contenu et de sa licence. Téléchargez uniquement ce que vous avez le droit de conserver, par exemple des œuvres sous licence libre, dans le domaine public, ou vos propres contenus.',
  ],
  [
    'Où sont enregistrés les fichiers ?',
    'Sous Windows, dans le dossier choisi dans les réglages (par défaut Vidéos\\Miarina). Sous Android 11 et plus, les vidéos vont dans Films/Miarina et l’audio dans Musique/Miarina : ils apparaissent dans la galerie et restent sur le téléphone si vous désinstallez l’application. Sous Android 7 à 10, ils restent pour l’instant dans l’espace de l’application.',
  ],
  [
    'Faut-il une connexion pour lire mes fichiers ?',
    'Non. La bibliothèque et le lecteur fonctionnent hors ligne, sous Windows comme sous Android.',
  ],
  [
    'Pourquoi Windows affiche-t-il un avertissement ?',
    'Cette préversion n’est pas encore signée numériquement, donc Windows SmartScreen peut afficher « Windows a protégé votre ordinateur ». Comparez l’empreinte SHA-256 du fichier avec celle indiquée sur cette page, puis choisissez « Informations complémentaires » et « Exécuter quand même ».',
  ],
  [
    'Comment installer l’APK sur Android ?',
    'Ouvrez le fichier téléchargé : Android vous demandera d’autoriser l’installation depuis votre navigateur la première fois. Les versions publiées ici sont toutes signées avec la même clé : les mises à jour s’installent par-dessus la version précédente. Si vous aviez installé l’APK du tout premier test (avant le 15 octobre 2026), désinstallez-le une fois avant d’installer celui-ci.',
  ],
];

function Cell({ value }: { value: boolean | string }) {
  if (value === true)
    return (
      <td className="yes">
        <Icon name="check" label="Oui" />
      </td>
    );
  if (value === false) return <td className="no">—</td>;
  if (value === 'soon') return <td className="soon-text">Bientôt</td>;
  return <td>{value}</td>;
}

export function Home() {
  return (
    <>
      <TopBar home />
      <main>
        <header id="top" className="hero">
          <span className="pill">Préversions de test · Windows &amp; Android</span>
          <h1>
            Your media.
            <br />
            <span className="accent">Your freedom.</span>
          </h1>
          <p className="lead">
            Collez un lien, choisissez le format, gardez le fichier. Miarina Media télécharge vidéos
            et audio, puis les range dans une bibliothèque sur votre appareil.
          </p>
          <Downloads />
          <div className="hero-shots">
            <figure className="shot-windows">
              <img
                src="/assets/img/windows-hero.jpg?v=013"
                width={1280}
                height={800}
                alt="Miarina Media sous Windows : navigateur intégré sur une page Wikimedia Commons, bouton « Download · 5 »"
              />
            </figure>
            <figure className="shot-android">
              <img
                src="/assets/img/android-home.jpg"
                width={540}
                height={1200}
                alt="Miarina Media sous Android : écran d'accueil"
              />
            </figure>
          </div>
        </header>

        <section id="fonctions" className="section">
          <SectionHead
            eyebrow="01 · FONCTIONNALITÉS"
            title="Du lien au fichier, en trois gestes."
          />
          <div className="cards">
            {FEATURES.map(([icon, title, text]) => (
              <div key={title} className="card">
                <Icon name={icon} className="card-icon" />
                <span className="card-title">{title}</span>
                <span className="card-text">{text}</span>
              </div>
            ))}
          </div>
        </section>

        <section id="navigateur" className="section split">
          <div className="stack">
            <div className="eyebrow-row">
              <span className="eyebrow">02 · NAVIGATEUR INTÉGRÉ</span>
            </div>
            <h2>Naviguez. Le bouton apparaît quand il y a quelque chose à garder.</h2>
            <p className="body">
              Sous Windows comme sous Android, tapez une adresse ou une recherche : dès qu’une page
              contient une vidéo ou un son, un bouton de téléchargement apparaît au-dessus de la
              barre. Sur Android, seuls les fichiers vidéo et audio d’une page sont proposés pour
              l’instant.
            </p>
            <ul className="checks">
              <li>
                <Icon name="check" />
                Détection des médias de la page
              </li>
              <li>
                <Icon name="check" />
                Bouton de téléchargement flottant
              </li>
              <li>
                <Icon name="check" />
                Choix du format sans quitter la page
              </li>
              <li>
                <Icon name="check" />
                Recherche et favoris
              </li>
              <li className="soon">
                <Icon name="schedule" />
                Onglets et historique : bientôt
              </li>
            </ul>
          </div>
          <figure className="frame">
            <img
              src="/assets/img/windows-browser.jpg?v=013"
              width={1280}
              height={800}
              loading="lazy"
              alt="Navigateur intégré sous Windows, dans la fenêtre principale : page Wikimedia Commons et bouton « Download · 5 »"
            />
          </figure>
        </section>

        <section className="section">
          <SectionHead
            eyebrow="03 · FORMATS ET QUALITÉS"
            title="Vous choisissez la qualité. Nous affichons la taille avant."
          >
            <p className="body">Seuls les formats réellement proposés par la source sont listés.</p>
          </SectionHead>
          <div className="tables">
            {FORMATS.map((table) => (
              <div key={table.title} className="table-card">
                <div className="table-head">
                  <Icon name={table.icon} />
                  {table.title}
                </div>
                {table.rows.map(([label, detail, soon]) => (
                  <div key={label} className="row">
                    <span>{label}</span>
                    <span className={soon ? 'soon-text' : 'mono'}>{detail}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </section>

        <section className="section split reverse">
          <figure className="frame">
            <img
              src="/assets/img/windows-library.jpg"
              width={1280}
              height={800}
              loading="lazy"
              alt="Bibliothèque sous Windows : bandes-annonces sous licence libre avec miniatures, qualité et durée"
            />
          </figure>
          <div className="stack">
            <span className="eyebrow">04 · BIBLIOTHÈQUE ET LECTEUR</span>
            <h2>Tout ce que vous gardez, au même endroit.</h2>
            <p className="body">
              Les fichiers téléchargés arrivent dans la bibliothèque, triés par vidéo et audio. Sous
              Windows, le lecteur intégré gère la vitesse, le plein écran, l’image dans l’image et
              reprend là où vous vous étiez arrêté. Rien ne nécessite de connexion.
            </p>
            <p className="body small">
              Sur Android, le lecteur intégré gère la lecture, la vitesse et la reprise ; le plein
              écran et l’image dans l’image arrivent dans une prochaine version.
            </p>
          </div>
        </section>

        <section className="section">
          <div className="privacy">
            <div className="stack">
              <span className="eyebrow">05 · CONFIDENTIALITÉ</span>
              <h2>Sans publicité. Sans compte. Sans pistage.</h2>
            </div>
            <ul className="privacy-list">
              {PRIVACY.slice(0, 2).map(([icon, title, text]) => (
                <li key={title}>
                  <Icon name={icon} />
                  <div>
                    <strong>{title}</strong>
                    <span>{text}</span>
                  </div>
                </li>
              ))}
              <li>
                <Icon name="visibility_off" />
                <div>
                  <strong>Aucun pistage</strong>
                  <span>
                    Ni télémétrie, ni traceurs, y compris sur ce site (
                    <a href="/confidentialite.html">détails</a>).
                  </span>
                </div>
              </li>
              {PRIVACY.slice(2).map(([icon, title, text]) => (
                <li key={title}>
                  <Icon name={icon} />
                  <div>
                    <strong>{title}</strong>
                    <span>{text}</span>
                  </div>
                </li>
              ))}
            </ul>
          </div>
        </section>

        <section id="plateformes" className="section">
          <SectionHead eyebrow="06 · PLATEFORMES" title="Windows et Android.">
            <p className="body">
              Windows {RELEASE.windows.version} · Android {RELEASE.android.version}
            </p>
          </SectionHead>
          <div className="compare-wrap">
            <table className="compare">
              <thead>
                <tr>
                  <th scope="col">
                    <span className="sr-only">Fonction</span>
                  </th>
                  <th scope="col">
                    <Icon name="desktop_windows" />
                    Windows
                  </th>
                  <th scope="col">
                    <Icon name="android" />
                    Android
                  </th>
                </tr>
              </thead>
              <tbody>
                {PLATFORMS.map((row) => (
                  <tr key={row.feature}>
                    <th scope="row">{row.feature}</th>
                    <Cell value={row.windows} />
                    <Cell value={row.android} />
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section id="faq" className="section narrow">
          <SectionHead eyebrow="07 · FAQ" title="Questions fréquentes" />
          <div className="faq">
            {FAQ.map(([question, answer]) => (
              <details key={question}>
                <summary>
                  <span>{question}</span>
                  <Icon name="add" />
                </summary>
                <p>{answer}</p>
              </details>
            ))}
          </div>
        </section>

        <section className="section narrow">
          <SectionHead eyebrow="08 · JOURNAL DES VERSIONS" title="Versions" small />
          <div className="changelog">
            {CHANGELOG.map((release) => (
              <div key={release.name} className="release">
                <div className="release-meta">
                  <span className="mono">{release.name}</span>
                  <span
                    className={
                      release.planned ? 'soon-text' : release.current ? 'current' : undefined
                    }
                  >
                    {release.date}
                  </span>
                </div>
                <ul>
                  {release.items.map((item) => (
                    <li key={item}>{item}</li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </section>
      </main>
      <Footer home />
    </>
  );
}
