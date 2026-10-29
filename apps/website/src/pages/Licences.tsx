import { Footer, TopBar } from '../components/Common';

export function Licences() {
  return (
    <>
      <TopBar home={false} />
      <main className="doc">
        <span className="eyebrow">LICENCES</span>
        <h1>Composants tiers</h1>
        <p className="doc-lead">
          Miarina Media est distribué gratuitement par MIARINA. Il s’appuie sur les composants
          suivants, sous leurs propres licences.
        </p>

        <h2>Application Android 0.1.5</h2>
        <p>
          Le code MIARINA de l’application Android est sous GPL-3.0-only. Les sources de
          l’application et les instructions de compilation sont dans le{' '}
          <a href="https://github.com/harinand-geek/miarina-media">dépôt Miarina Media</a>. L’APK
          intègre youtubedl-android 0.18.1, Python, yt-dlp et FFmpeg. Les composants tiers
          conservent leurs propres licences. L’inventaire des sources correspondant exactement aux
          bibliothèques natives reste incomplet ; le dépôt de l’application ne constitue pas à lui
          seul un ensemble complet de ces sources.
        </p>
        <p>
          <a href="/downloads/MiarinaMedia-0.1.5-source.tar.gz">
            Archive du code de l’application 0.1.5
          </a>{' '}
          — révision <code>4a05015</code>, sans les sources natives tierces manquantes.
        </p>
        <h2>Outils inclus dans l’installateur (Windows)</h2>
        <p>
          Depuis la version 0.1.1, ils sont livrés avec l’installateur, dans le dossier{' '}
          <span className="mono">tools</span> de l’application, avec leurs textes de licence. Chaque
          fichier est pris dans la publication officielle et vérifié avec une empreinte SHA-256
          fixée dans l’application. S’ils manquent, l’application propose de les télécharger, avec
          la même vérification.
        </p>
        <ul>
          <li>
            <strong>yt-dlp</strong> 2026.08.19 — Unlicense (domaine public). L’exécutable contient
            un environnement Python et des bibliothèques sous leurs propres licences. Source :{' '}
            <a href="https://github.com/yt-dlp/yt-dlp">github.com/yt-dlp/yt-dlp</a>.
          </li>
          <li>
            <strong>FFmpeg</strong> n8.1.2, build « LGPL shared » de BtbN — GNU LGPL 3.0 ou
            ultérieure. Utilisé comme programme séparé. Binaires et sources correspondantes :{' '}
            <a href="https://github.com/BtbN/FFmpeg-Builds">github.com/BtbN/FFmpeg-Builds</a> ;
            projet : <a href="https://ffmpeg.org">ffmpeg.org</a>. Les textes de la LGPL 3.0 et de la
            GPL 3.0 sont fournis dans le dossier <span className="mono">tools</span>.
          </li>
          <li>
            <strong>QuickJS-NG</strong> 0.17.0 — licence MIT. Moteur JavaScript utilisé par yt-dlp
            pour certains sites (YouTube). Source :{' '}
            <a href="https://github.com/quickjs-ng/quickjs">github.com/quickjs-ng/quickjs</a>.
          </li>
        </ul>

        <h2>Polices et icônes (application et site)</h2>
        <ul>
          <li>
            <strong>Manrope</strong> — SIL Open Font License 1.1.
          </li>
          <li>
            <strong>JetBrains Mono</strong> — SIL Open Font License 1.1.
          </li>
          <li>
            <strong>Material Symbols Rounded</strong> (Google) — Apache License 2.0. Ce site en
            utilise un sous-ensemble.
          </li>
        </ul>

        <h2>Principales bibliothèques</h2>
        <p>
          Tauri, Rust (tokio, reqwest, rustls), rPGP (vérification des mises à jour de yt-dlp),
          SQLite (domaine public), React, Zustand, TanStack Virtual, Tailwind CSS ; sous Android,
          AndroidX et Media3 (lecteur), sous licences MIT, Apache 2.0, ISC ou BSD. Ce site est
          construit avec React et Vite (licence MIT).
        </p>

        <h2>Contenus des captures</h2>
        <p>
          Les captures d’écran de ce site montrent des œuvres sous licence libre :{' '}
          <em>Big Buck Bunny</em>, <em>Sintel</em> (Blender Foundation, CC BY 3.0) et une page de
          Wikimedia Commons.
        </p>
      </main>
      <Footer other={{ href: '/confidentialite.html', label: 'Confidentialité' }} />
    </>
  );
}
