import { Footer, TopBar } from '../components/Common';

export function Licences() {
  return (
    <>
      <TopBar home={false} />
      <main className="doc">
        <span className="eyebrow">LICENCES</span>
        <h1>Licences</h1>
        <p className="doc-lead">
          Miarina Media est distribué gratuitement par MIARINA. Cette page indique la licence de
          l’application et celles des composants tiers qu’elle inclut.
        </p>

        <h2>Licence de l’application</h2>
        <p>
          Miarina Media pour Windows et pour Android est sous licence GNU GPL 3.0
          (GPL-3.0-only). Comme le demande cette licence, le code correspondant à chaque version
          publiée est disponible dans le{' '}
          <a href="https://github.com/harinand-geek/miarina-media">dépôt Miarina Media</a>, à
          l’étiquette de la version.
        </p>

        <h2>Application Windows</h2>
        <p>
          Elle est construite avec Flutter (licence BSD) et flutter_rust_bridge (MIT). Son
          interface utilise les icônes Phosphor (MIT), son lecteur media_kit (MIT) et libmpv, et
          l’enregistrement de l’écran le crate wasapi (MIT) pour le son. Les torrents reposent sur
          des composants sous GPL-3.0-or-later et sur librqbit ; leurs auteurs et leurs licences
          sont indiqués dans l’installateur. L’extension pour Chrome et Edge et son pont
          (miarina-browser-bridge) sont livrés avec l’application, sous la même licence.
        </p>
        <ul>
          <li>
            <strong>libmpv</strong>, révision mpv <code>bcde6b93cc</code>, build 20261111 de
            mpv-winbuild-cmake — GNU GPL 2.0 ou ultérieure, utilisée sous GPL 3.0. Cette build
            contient FFmpeg et d’autres bibliothèques, sous leurs propres licences. Binaires :{' '}
            <a href="https://github.com/shinchiro/mpv-winbuild-cmake/releases/tag/20261111">
              mpv-winbuild-cmake 20261111
            </a>{' '}
            ; sources : <a href="https://github.com/mpv-player/mpv">mpv</a> (révision{' '}
            <code>bcde6b93cc</code>) et les scripts de construction de l’étiquette 20261111, avec la
            version de chaque bibliothèque.
          </li>
          <li>
            <strong>Bibliothèques d’exécution Visual C++</strong> (Microsoft) — redistribuées sans
            modification, selon les termes de la licence Visual Studio.
          </li>
        </ul>

        <h2>Outils inclus dans l’installateur (Windows)</h2>
        <p>
          Ils sont livrés dans le dossier <span className="mono">tools</span> de l’application,
          avec leurs textes de licence. Chaque fichier est pris dans la publication officielle et
          vérifié avec une empreinte SHA-256 fixée dans l’application. S’ils manquent,
          l’application propose de les télécharger, avec la même vérification.
        </p>
        <ul>
          <li>
            <strong>yt-dlp</strong> 2026.08.19 — Unlicense (domaine public). L’exécutable contient
            un environnement Python et des bibliothèques sous leurs propres licences. Source :{' '}
            <a href="https://github.com/yt-dlp/yt-dlp">github.com/yt-dlp/yt-dlp</a>.
          </li>
          <li>
            <strong>FFmpeg</strong> n8.1.2, build « LGPL shared » de BtbN — GNU LGPL 3.0 ou
            ultérieure. Utilisé comme programme séparé. La compression AV1 passe par SVT-AV1
            (licence BSD), inclus dans cette build. Binaires et sources correspondantes :{' '}
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

        <h2>Application Android</h2>
        <p>
          Elle est construite avec Flutter (licence BSD) et flutter_rust_bridge (MIT). Son lecteur
          utilise AndroidX Media3 1.11.1 (Apache 2.0), dont son module HLS pour les clips en ligne, et son interface les icônes Phosphor (MIT).
          L’APK intègre youtubedl-android 0.18.1 (Python, FFmpeg, QuickJS) et yt-dlp 2026.08.19,
          sous leurs propres licences. L’inventaire des sources correspondant exactement aux
          bibliothèques natives de youtubedl-android reste incomplet.
        </p>

        <h2>Polices et icônes (application et site)</h2>
        <ul>
          <li>
            <strong>Manrope</strong> — SIL Open Font License 1.1.
          </li>
          <li>
            <strong>JetBrains Mono</strong> — SIL Open Font License 1.1.
          </li>
          <li>
            <strong>Phosphor Icons</strong> — licence MIT.
          </li>
          <li>
            <strong>Simple Icons</strong> — CC0 1.0 (domaine public) : logos des sites proposés
            au départ du navigateur. Les marques restent celles de leurs titulaires et désignent
            seulement un lien vers leur site.
          </li>
          <li>
            <strong>Material Symbols Rounded</strong> (Google) — Apache License 2.0. Ce site en
            utilise un sous-ensemble.
          </li>
        </ul>

        <h2>Principales bibliothèques</h2>
        <p>
          Rust (tokio, reqwest, rustls), rPGP (vérification des mises à jour de yt-dlp), SQLite
          (domaine public), Riverpod et go_router ; sous Android, AndroidX et Media3. Elles sont
          sous licences MIT, Apache 2.0, ISC ou BSD. Ce site est construit avec React et Vite
          (licence MIT).
        </p>

        <h2>Contenus des captures</h2>
        <p>
          Les captures de la bibliothèque et du lecteur montrent une bibliothèque de
          démonstration : les titres, les artistes et les pochettes ont été inventés pour
          l’occasion. Les autres captures montrent des œuvres libres, téléchargées avec
          l’application depuis Wikimedia Commons et la chaîne de la Blender Foundation :{' '}
          <em>Big Buck Bunny</em> et <em>Sintel</em> (Blender Foundation, CC BY 3.0) ; des
          enregistrements du domaine public ou sous CC0 de Mendelssohn (
          <em>Le Songe d’une nuit d’été</em>, European Archive), Albinoni, Bach (Musopen) et Dvořák
          ; des portraits du domaine public en pochettes ; et des pages de Wikimedia Commons.
        </p>
      </main>
      <Footer other={{ href: '/confidentialite.html', label: 'Confidentialité' }} />
    </>
  );
}
