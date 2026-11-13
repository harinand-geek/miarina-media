import { useState } from 'react';
import { Icon } from '../components/Common';
import { Downloads } from '../components/Downloads';
import { LandingShell } from '../components/LandingShell';
import { DownloadDemo } from '../components/DownloadDemo';
import { ReleaseLog } from '../components/ReleaseLog';
import { FEATURES, FORMATS, FAQ } from './homeContent';
import { PLATFORMS, RELEASE } from '../release';
function Heading({ label, title }: { label: string; title: string }) {
  return (
    <div className="v-heading">
      <span>{label}</span>
      <h2>{title}</h2>
    </div>
  );
}
function Cell({ value }: { value: boolean | string }) {
  return (
    <td
      className={value === true ? 'yes' : value === false ? 'no' : value === 'soon' ? 'soon' : ''}
    >
      {value === true ? (
        <Icon name="check" label="Disponible" />
      ) : value === false ? (
        <span aria-label="Non disponible">—</span>
      ) : value === 'soon' ? (
        'À venir'
      ) : (
        value
      )}
    </td>
  );
}
export function Home() {
  const [spec, setSpec] = useState(0);
  const [platform, setPlatform] = useState<'all' | 'windows' | 'android'>('all');
  return (
    <LandingShell>
      <header id="top" className="v-hero">
        <div className="v-hero-copy">
          <span className="v-pill">
            Windows {RELEASE.windows.version} · Android {RELEASE.android.version} · préversions
            gratuites
          </span>
          <h1>
            Your media.
            <br />
            <span>Your freedom.</span>
          </h1>
          <p>
            Collez un lien, choisissez le format, gardez le fichier. Miarina Media télécharge vidéos
            et audio, puis les range dans une bibliothèque sur votre appareil. Sur Windows comme sur
            Android, écoutez et regardez-les dans le lecteur intégré : albums, playlists, pistes
            audio, sous-titres et égaliseur. Sur Android, votre musique déjà présente sur le
            téléphone s’y ajoute. Sous Windows, ajoutez aussi des torrents et envoyez vos liens
            depuis Chrome ou Edge.
          </p>
          <Downloads />
        </div>
        <DownloadDemo />
      </header>
      <section id="fonctions" className="v-section v-bordered">
        <div className="v-container">
          <Heading label="Fonctionnalités" title="Vos téléchargements, votre bibliothèque." />
          <div className="v-features">
            {FEATURES.map(([icon, title, text], i) => (
              <article key={title}>
                <Icon name={icon} className={i < 3 ? 'v-feature-icon primary' : 'v-feature-icon'} />
                <div>
                  <h3>{title}</h3>
                  <p>{text}</p>
                </div>
              </article>
            ))}
          </div>
        </div>
      </section>
      <section id="navigateur" className="v-section v-browser">
        <div className="v-container">
          <div className="v-browser-heading">
            <Heading
              label="Navigateur intégré"
              title="Naviguez. Le bouton apparaît quand il y a quelque chose à garder."
            />
            <p>
              Sous Windows comme sous Android, tapez une adresse ou une recherche. Quand un média
              compatible est détecté, un bouton de téléchargement apparaît. Sous Windows, ouvrez
              plusieurs onglets et retrouvez vos pages dans un historique local, que vous pouvez
              effacer. L’APK Android {RELEASE.android.version} inclut l’extracteur et les outils
              nécessaires. Le parcours YouTube a été validé sur émulateur lors d’une version
              précédente ; la version actuelle reste à tester sur téléphone réel.
            </p>
          </div>
          <figure className="v-screenshot">
            <img
              src="/assets/img/windows-browser.jpg?v=018"
              width={1280}
              height={800}
              loading="lazy"
              alt="Navigateur Windows : deux onglets sur Wikimedia Commons, médias détectés dans la barre d’adresse"
            />
          </figure>
          <div className="v-chips">
            {[
              'Détection des médias compatibles',
              'Bouton de téléchargement flottant',
              'Choix du format sans quitter la page',
              'Recherche et favoris',
              'Onglets et historique (Windows)',
            ].map((t) => (
              <span key={t}>
                <Icon name="check" />
                {t}
              </span>
            ))}
            <span className="planned">
              <Icon name="schedule" />
              Onglets et historique sur Android : à venir
            </span>
          </div>
        </div>
      </section>
      <section id="formats" className="v-section">
        <div className="v-container v-split">
          <div>
            <Heading
              label="Formats et qualités"
              title="Vous choisissez la qualité. La taille est indiquée si disponible."
            />
            <p className="v-body">
              Les formats dépendent de la source. Les conversions MP3 et FLAC sont disponibles sous
              Windows. Sur Android, la conversion MP3 à 320 kbps a été vérifiée sur émulateur ; les
              autres qualités restent à valider.
            </p>
          </div>
          <div className="v-spec">
            <div className="v-spec-tabs enhanced-control" aria-label="Catégorie de formats">
              {FORMATS.map((t, i) => (
                <button key={t.title} aria-pressed={spec === i} onClick={() => setSpec(i)}>
                  <Icon name={t.icon} />
                  {t.title}
                </button>
              ))}
            </div>
            {FORMATS.map((t, i) => (
              <div className={spec !== i ? 'v-spec-panel inactive' : 'v-spec-panel'} key={t.title}>
                <h3 className="fallback-label">{t.title}</h3>
                {t.rows.map(([label, detail, soon]) => (
                  <div className="v-spec-row" key={label}>
                    <strong>{label}</strong>
                    <span className={soon ? 'soon' : ''}>{detail}</span>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </div>
      </section>
      <section id="bibliotheque" className="v-section v-library">
        <div className="v-container v-split">
          <figure className="v-screenshot">
            <img
              src="/assets/img/windows-library.jpg?v=018"
              width={1280}
              height={800}
              loading="lazy"
              alt="Bibliothèque musicale Windows : albums d’œuvres libres avec leurs pochettes"
            />
          </figure>
          <div>
            <Heading
              label="Bibliothèque et lecteur"
              title="Tout ce que vous gardez, au même endroit."
            />
            <p className="v-body">
              Les téléchargements vidéo et audio arrivent dans la bibliothèque, avec vos propres
              fichiers si vous les ajoutez. La musique se range par albums, artistes et dossiers,
              avec pochettes, playlists et favoris. Sous Windows, le lecteur intégré, fondé sur
              libVLC, lit aussi des formats que Windows ne lit pas seul (MKV, HEVC, AVI…), avec
              pistes audio, sous-titres, vitesse et égaliseur ; la lecture reprend où vous l’aviez
              laissée. Tout se lit hors ligne.
            </p>
            <p className="v-body small">
              L’image dans l’image n’est plus proposée sous Windows avec ce lecteur. Sur Android
              {RELEASE.android.version}, la musique continue écran éteint (écran verrouillé, casque
              Bluetooth), avec égaliseur, minuteur et vitesse ; les vidéos passent en plein écran
              paysage avec pistes, sous-titres et image dans l’image. Vérifié sur émulateur, essais
              sur téléphone réel en cours.
            </p>
          </div>
        </div>
      </section>
      <section id="android" className="v-section">
        <div className="v-container v-split v-android">
          <div>
            <Heading label="Sur Android" title="Un vrai lecteur de musique dans la poche." />
            <p className="v-body">
              Avec Android {RELEASE.android.version}, vos téléchargements et, si vous l’autorisez,
              la musique déjà présente sur le téléphone se rangent par albums, artistes et dossiers.
              Playlists, favoris, titres récents et plus écoutés ; la musique continue écran éteint,
              avec les commandes de l’écran verrouillé et du casque. Égaliseur du téléphone, vitesse
              et minuteur dans la feuille Son.
            </p>
            <p className="v-body small">
              Captures de l’interface Android avec des titres de démonstration. Vérifié sur
              émulateur ; essais sur téléphone réel en cours.
            </p>
          </div>
          <div className="v-phones">
            <figure className="v-screenshot">
              <img
                src="/assets/img/android-player.jpg?v=019"
                width={780}
                height={1688}
                loading="lazy"
                alt="Android : écran En lecture, avec le titre, la progression et les commandes"
              />
            </figure>
            <figure className="v-screenshot">
              <img
                src="/assets/img/android-sound.jpg?v=019"
                width={780}
                height={1688}
                loading="lazy"
                alt="Android : feuille Son avec l’égaliseur à six bandes réglé sur Basses, la vitesse et le minuteur"
              />
            </figure>
          </div>
        </div>
      </section>
      <section id="confidentialite" className="v-section">
        <div className="v-container">
          <Heading
            label="Confidentialité"
            title="Sans publicité. Sans compte. Vos fichiers chez vous."
          />
          <div className="v-privacy">
            {[
              ['0', 'publicité', 'Ni dans l’application, ni dans l’installateur.'],
              ['0', 'compte', 'Rien à créer pour utiliser l’application.'],
              [
                '0',
                'télémétrie dans l’app',
                'L’application n’envoie ni statistiques d’usage ni rapports de plantage.',
              ],
              [
                'disk',
                'Vos fichiers restent chez vous',
                'Historique et bibliothèque restent sur votre appareil. Les torrents actifs échangent des données avec leurs pairs.',
              ],
            ].map(([n, title, text]) => (
              <article key={title}>
                {n === 'disk' ? <Icon name="hard_drive" /> : <b>{n}</b>}
                <h3>{title}</h3>
                <p>{text}</p>
              </article>
            ))}
          </div>
          <a href="/confidentialite.html">Détails de confidentialité</a>
        </div>
      </section>
      <section id="plateformes" className="v-section v-bordered">
        <div className="v-container">
          <Heading label="Plateformes" title="Windows et Android." />
          <p className="v-body">
            Fonctionnalités des préversions proposées : Windows {RELEASE.windows.version} · Android{' '}
            {RELEASE.android.version}. Les fonctions « À venir » ne sont pas incluses.
          </p>
          <div className="v-segment enhanced-control" aria-label="Filtrer les fonctionnalités">
            {(['all', 'windows', 'android'] as const).map((p, i) => (
              <button key={p} aria-pressed={platform === p} onClick={() => setPlatform(p)}>
                {['Tout', 'Windows', 'Android'][i]}
              </button>
            ))}
          </div>
          <div className="v-table-wrap">
            <table className="v-table">
              <thead>
                <tr>
                  <th scope="col">Fonctionnalité</th>
                  <th scope="col">
                    <Icon name="desktop_windows" label="Windows" />
                    <span>Windows</span>
                  </th>
                  <th scope="col">
                    <Icon name="android" label="Android" />
                    <span>Android</span>
                  </th>
                </tr>
              </thead>
              <tbody>
                {PLATFORMS.filter((r) => platform === 'all' || r[platform] !== false).map((r) => (
                  <tr key={r.feature}>
                    <th scope="row">{r.feature}</th>
                    <Cell value={r.windows} />
                    <Cell value={r.android} />
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </section>
      <section id="faq" className="v-section">
        <div className="v-container v-split v-faq-layout">
          <Heading label="FAQ" title="Questions fréquentes" />
          <div className="v-faq">
            {FAQ.map(([q, a], i) => (
              <details key={q} name="faq" open={i === 0}>
                <summary>
                  {q}
                  <Icon name="add" />
                </summary>
                <p>{a}</p>
              </details>
            ))}
          </div>
        </div>
      </section>
      <section id="versions" className="v-section">
        <div className="v-container">
          <Heading label="Journal des versions" title="Versions" />
          <ReleaseLog />
        </div>
      </section>
      <footer className="v-footer">
        <p>
          Téléchargez uniquement les contenus dont vous détenez les droits ou dont la licence
          l’autorise.
        </p>
        <div>
          <a href="/confidentialite.html">Confidentialité</a>
          <a href="/licences.html">Licences</a>
        </div>
        <span>© 2026 MIARINA</span>
      </footer>
    </LandingShell>
  );
}
