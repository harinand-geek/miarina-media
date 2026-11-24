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

        <h2>Application Windows 0.2.7</h2>
        <p>
          Miarina Media 0.2.7 pour Windows, qui remplace la 0.1.12, est sous GPL-3.0-only. Ses
          sources exactes et ses scripts de construction sont à l’étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.7">v0.2.7</a> du dépôt
          public, avec le sous-module Mister Download Manager. Ses composants sont ceux de la bêta
          0.2.4 ci-dessous (Flutter, flutter_rust_bridge, media_kit et libmpv, icônes Phosphor,
          yt-dlp, FFmpeg et QuickJS-NG), plus le crate wasapi (MIT) pour le son de l’enregistrement
          de l’écran. La compression AV1 passe par SVT-AV1 (licence BSD), inclus dans le FFmpeg livré.
        </p>

        <h2>Application Android 0.2.7</h2>
        <p>
          Miarina Media 0.2.7 pour Android, qui remplace la 0.1.11, est sous GPL-3.0-only. Ses
          sources exactes et ses scripts de construction sont à l’étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.7">v0.2.7</a> du dépôt
          public, avec le sous-module{' '}
          <a href="https://github.com/anefzaoui/misterdownloadmanager">Mister Download Manager</a>.
          Ses composants sont ceux de la bêta 0.2.4 ci-dessous : Flutter (licence BSD),
          flutter_rust_bridge (MIT), AndroidX Media3 1.11.1 (Apache 2.0), les icônes Phosphor (MIT),
          youtubedl-android 0.18.1 (Python, FFmpeg, QuickJS) et yt-dlp 2026.08.19, sous leurs
          propres licences, avec la même réserve sur l’inventaire des sources de youtubedl-android.
        </p>

        <h2>Application Windows 0.2.4 (bêta)</h2>
        <p>
          La version 0.2.4 pour Windows est sous GPL-3.0-only, comme les précédentes. Ses sources
          exactes et ses scripts de construction sont à l’étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.4">v0.2.4</a> du dépôt,
          et dans l’
          <a href="/downloads/MiarinaMedia-0.2.4-source.tar.gz">
            archive du code des applications 0.2.4
          </a>{' '}
          (Windows et bêta Android), avec le sous-module Mister Download Manager. Elle est construite avec Flutter (licence
          BSD) et flutter_rust_bridge (MIT) ; son interface utilise les icônes Phosphor (MIT) et son
          lecteur, media_kit (MIT) et libmpv. yt-dlp, FFmpeg et QuickJS-NG sont les mêmes que
          ci-dessous ; libVLC n’en fait pas partie. L’extension pour Chrome et Edge et son pont
          (miarina-browser-bridge) sont livrés avec elle, sous la même licence.
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
        <h2>Application Android 0.2.4 (bêta)</h2>
        <p>
          Miarina Media Bêta pour Android est sous GPL-3.0-only. Ses sources exactes sont à
          l’étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.4">v0.2.4</a> du dépôt
          et dans la même{' '}
          <a href="/downloads/MiarinaMedia-0.2.4-source.tar.gz">archive du code 0.2.4</a>, avec le
          sous-module Mister Download Manager. Elle est construite avec Flutter (licence
          BSD) et flutter_rust_bridge (MIT) ; son lecteur utilise AndroidX Media3 (Apache 2.0) ; son
          interface, les icônes Phosphor (MIT). Comme la 0.1.11, l’APK intègre youtubedl-android
          0.18.1 (Python, FFmpeg, QuickJS) et yt-dlp 2026.08.19 ; les composants tiers conservent
          leurs propres licences. L’inventaire des sources correspondant exactement aux
          bibliothèques natives de youtubedl-android reste incomplet ; le dépôt de l’application ne
          constitue pas à lui seul un ensemble complet de ces sources.
        </p>
        <p>
          Archives précédentes :{' '}
          <a href="/downloads/MiarinaMedia-0.2.3-source.tar.gz">0.2.3</a> (étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.3">v0.2.3</a>),{' '}
          <a href="/downloads/MiarinaMedia-0.2.2-source.tar.gz">0.2.2</a> (étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.2">v0.2.2</a>),{' '}
          <a href="/downloads/MiarinaMedia-0.2.0-source.tar.gz">Windows 0.2.0</a> (étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.2.0">v0.2.0</a>),{' '}
          <a href="/downloads/MiarinaMedia-Beta-0.2.1-source.tar.gz">bêta Android 0.2.1</a>{' '}
          (étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/android-beta-0.2.1">
            android-beta-0.2.1
          </a>
          ).
        </p>
        <p>
          <a href="/downloads/MiarinaMedia-Beta-0.2.0-source.tar.gz">
            Archive du code de la bêta Android 0.2.0
          </a>{' '}
          — lecteur seul, étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/android-beta-0.2.0">
            android-beta-0.2.0
          </a>
          .
        </p>
        <p>
          <a href="/downloads/MiarinaMedia-0.1.12-source.tar.gz">
            Archive du code de l’application Windows 0.1.12
          </a>{' '}
          — sources exactes de cette compilation, aussi à l’étiquette{' '}
          <a href="https://github.com/harinand-geek/miarina-media/tree/v0.1.12">v0.1.12</a> du
          dépôt.
        </p>
        <h2>Applications Windows et Android 0.1.11</h2>
        <p>
          Le code MIARINA des applications Windows et Android est sous GPL-3.0-only. Les sources de
          l’application et les instructions de compilation sont dans le{' '}
          <a href="https://github.com/harinand-geek/miarina-media">dépôt Miarina Media</a>. L’APK
          intègre youtubedl-android 0.18.1, Python, yt-dlp et FFmpeg. Les composants tiers
          conservent leurs propres licences. L’inventaire des sources correspondant exactement aux
          bibliothèques natives reste incomplet ; le dépôt de l’application ne constitue pas à lui
          seul un ensemble complet de ces sources.
        </p>
        <p>
          <a href="/downloads/MiarinaMedia-0.1.11-source.tar.gz">
            Archive du code de l’application 0.1.11
          </a>{' '}
          — Windows et Android 0.1.11, sources exactes de ces compilations, avec le sous-module
          Mister Download Manager.{' '}
          <a href="/downloads/MiarinaMedia-0.1.10-source.tar.gz">
            Archive du code de l’application Windows 0.1.10
          </a>{' '}
          — correction du thème clair, sources exactes de cette compilation.{' '}
          <a href="/downloads/MiarinaMedia-0.1.9-source.tar.gz">
            Archive du code de l’application 0.1.9
          </a>{' '}
          — révision <code>5f36cda</code> (Windows et Android 0.1.9), avec le sous-module Mister
          Download Manager.{' '}
          <a href="/downloads/MiarinaMedia-0.1.8-source.tar.gz">
            Archive du code de l’application 0.1.8
          </a>{' '}
          — révision <code>9f9922c</code> (Windows 0.1.8).{' '}
          <a href="/downloads/MiarinaMedia-0.1.7-source.tar.gz">
            Archive du code de l’application 0.1.7
          </a>{' '}
          — révision <code>0ccc620</code> (Android 0.1.7), avec le sous-module Mister Download
          Manager, sans les sources natives Android tierces manquantes.
        </p>
        <p>
          Les torrents Windows utilisent les composants de{' '}
          <a href="https://github.com/anefzaoui/misterdownloadmanager">Mister Download Manager</a>{' '}
          (GPL-3.0-or-later, révision <code>46bb3bcd</code>) et librqbit. Les attributions sont
          incluses dans l’installateur. L’extension Miarina Media pour Chrome et Edge est fournie en
          mode développeur, avec son code source.
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
          <li>
            <strong>libVLC</strong> 3.0.24 (VideoLAN), depuis la version 0.1.8 — moteur du lecteur
            Windows, chargé à l’exécution. Seuls les fichiers utiles à la lecture locale sont repris
            de la publication officielle (<span className="mono">libvlc.dll</span>,{' '}
            <span className="mono">libvlccore.dll</span> et une partie des modules) ;{' '}
            <span className="mono">vlc.exe</span> et les interfaces de VLC ne sont pas inclus.
            libvlc et libvlccore sont sous GNU LGPL 2.1 ou ultérieure ; les modules et les
            bibliothèques qu’ils contiennent ont leurs propres licences, indiquées dans{' '}
            <span className="mono">COPYING.txt</span> et <span className="mono">AUTHORS.txt</span>,
            livrés dans le même dossier. Publication :{' '}
            <a href="https://download.videolan.org/pub/videolan/vlc/3.0.24/win64/vlc-3.0.24-win64.zip">
              vlc-3.0.24-win64.zip
            </a>{' '}
            ; sources :{' '}
            <a href="https://download.videolan.org/pub/videolan/vlc/3.0.24/vlc-3.0.24.tar.xz">
              vlc-3.0.24.tar.xz
            </a>{' '}
            et <a href="https://www.videolan.org/vlc/download-sources.html">videolan.org</a>.
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
          Les captures d’écran de ce site montrent des œuvres libres, téléchargées avec
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
