import { Fragment, useEffect, useState } from 'react';
import { RELEASE, downloadUrl } from '../release';
import { Icon } from './Common';

type Platform = 'windows' | 'android';

/**
 * Download buttons. The pre-rendered page puts Windows first; once loaded,
 * an Android visitor gets the APK first (same markup, no layout jump
 * besides the order). Without JavaScript both buttons still work.
 */
export function Downloads() {
  const [first, setFirst] = useState<Platform>('windows');
  useEffect(() => {
    if (/Android/i.test(navigator.userAgent)) setFirst('android');
  }, []);
  const order: Platform[] = first === 'android' ? ['android', 'windows'] : ['windows', 'android'];

  return (
    <div id="telecharger" className="downloads">
      <div className="download-buttons">
        {order.map((platform, i) => (
          <DownloadButton key={platform} platform={platform} primary={i === 0} />
        ))}
      </div>
      <p className="note">
        Préversion Android : YouTube et conversion MP3 à 320 kbps testés sur émulateur. Tests sur
        téléphone réel encore à effectuer.
      </p>
      <details className="checksums">
        <summary>Sans compte · sans publicité · vérifier les fichiers (SHA-256)</summary>
        <dl>
          {[RELEASE.windows, RELEASE.android].map((file) => (
            <Fragment key={file.name}>
              <dt>{file.name}</dt>
              <dd>{file.sha256}</dd>
            </Fragment>
          ))}
        </dl>
      </details>
    </div>
  );
}

function DownloadButton({ platform, primary }: { platform: Platform; primary: boolean }) {
  const windows = platform === 'windows';
  const file = windows ? RELEASE.windows : RELEASE.android;
  return (
    <a
      className={`btn-download ${primary ? 'primary' : 'secondary'}`}
      data-platform={platform}
      href={downloadUrl(file)}
      download
    >
      <Icon name={windows ? 'desktop_windows' : 'android'} />
      <span className="btn-text">
        <span className="btn-label">
          {windows ? 'Télécharger pour Windows' : primary ? 'Télécharger pour Android' : 'Android'}
        </span>
        <span className="btn-meta">
          v{file.version} · {windows ? 'Windows 10 / 11 · 64 bits' : 'Android 7.0+ · APK'} ·{' '}
          {file.size}
        </span>
      </span>
    </a>
  );
}
