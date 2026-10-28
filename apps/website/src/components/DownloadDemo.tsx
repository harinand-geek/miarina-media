import { useEffect, useState } from 'react';
import { Icon, Logo } from './Common';
type Step = 'idle' | 'analyzing' | 'formats' | 'downloading' | 'done';
const VIDEO = [
  ['1080p', 'MP4 · H.264', '372 Mo', 'mp4'],
  ['720p', 'MP4 · H.264', '186 Mo', 'mp4'],
  ['1080p', 'WebM · VP9', '298 Mo', 'webm'],
];
const AUDIO = [
  ['320 kbps', 'MP3', '28 Mo', 'mp3'],
  ['128 kbps', 'MP3', '11 Mo', 'mp3'],
  ['FLAC', 'Sans perte', '112 Mo', 'flac'],
];
export function DownloadDemo() {
  const [step, setStep] = useState<Step>('idle');
  const [audio, setAudio] = useState(false);
  const [sel, setSel] = useState(0);
  const [pct, setPct] = useState(0);
  const [ready, setReady] = useState(false);
  useEffect(() => setReady(true), []);
  useEffect(() => {
    if (step === 'analyzing') {
      const timer = setTimeout(() => setStep('formats'), 900);
      return () => clearTimeout(timer);
    }
    if (step === 'downloading') {
      if (matchMedia('(prefers-reduced-motion: reduce)').matches) {
        setPct(100);
        setStep('done');
        return;
      }
      const timer = setInterval(() => setPct((p) => Math.min(100, p + 2.5)), 80);
      return () => clearInterval(timer);
    }
  }, [step]);
  useEffect(() => {
    if (step === 'downloading' && pct === 100) setStep('done');
  }, [pct, step]);
  const chosen = (audio ? AUDIO : VIDEO)[sel]!;
  const folder = audio ? 'Musique\\Miarina' : 'Vidéos\\Miarina';
  const name = `Tears of Steel.${chosen[3]}`;
  const labels = {
    idle: '1 · lien',
    analyzing: '1 · analyse',
    formats: '2 · format',
    downloading: '3 · fichier',
    done: '3 · terminé',
  };
  return (
    <div className="v-demo">
      <div className="v-demo-head">
        <span>Essayez · démo simulée</span>
        <span aria-live="polite">{labels[step]}</span>
      </div>
      <div className="v-demo-body">
        <div className="v-link-row">
          <div className="v-link">
            <Icon name="link" />
            <span>
              commons.wikimedia.org<span>/wiki/File:Tears_of_Steel_1080p.webm</span>
            </span>
          </div>
          <button
            className="v-button"
            disabled={!ready || step !== 'idle'}
            onClick={() => setStep('analyzing')}
          >
            Analyser
          </button>
        </div>
        {step === 'idle' && (
          <div className="v-demo-empty">
            <strong>Le lien est collé.</strong>
            <p>Cliquez sur Analyser pour découvrir le parcours de téléchargement.</p>
            <noscript>Activez JavaScript pour essayer cette simulation.</noscript>
          </div>
        )}
        {step === 'analyzing' && (
          <div className="v-skeleton" role="status">
            <div />
            <div />
            <div />
            <span>Analyse de la page…</span>
          </div>
        )}
        {!['idle', 'analyzing'].includes(step) && (
          <div className="v-media">
            <div className="v-demo-thumb">
              <Logo size={34} />
            </div>
            <div>
              <strong>Tears of Steel</strong>
              <p>Blender Foundation · CC BY 3.0 · 12:14</p>
            </div>
          </div>
        )}
        {step === 'formats' && (
          <>
            <div className="v-segment" aria-label="Type de fichier">
              {['Vidéo', 'Audio seul'].map((t, i) => (
                <button
                  key={t}
                  aria-pressed={audio === (i === 1)}
                  onClick={() => {
                    setAudio(i === 1);
                    setSel(0);
                  }}
                >
                  {t}
                </button>
              ))}
            </div>
            <fieldset className="v-format-options">
              <legend className="sr-only">Format d’exemple</legend>
              {(audio ? AUDIO : VIDEO).map((f, i) => (
                <label className={sel === i ? 'selected' : ''} key={i}>
                  <input
                    type="radio"
                    name="demo-format"
                    checked={sel === i}
                    onChange={() => setSel(i)}
                  />
                  <strong>{f[0]}</strong>
                  <span>{f[1]}</span>
                  {i === 0 && <small>Recommandé</small>}
                  <b>{f[2]}</b>
                </label>
              ))}
            </fieldset>
            <div className="v-demo-actions">
              <span>→ {folder}</span>
              <button
                className="v-button primary"
                onClick={() => {
                  setPct(0);
                  setStep('downloading');
                }}
              >
                <Icon name="download" />
                Simuler · {chosen[2]}
              </button>
            </div>
          </>
        )}
        {step === 'downloading' && (
          <div className="v-progress">
            <div>
              <strong>{name}</strong>
              <span>{Math.round(pct)} %</span>
            </div>
            <progress aria-label="Progression simulée" max={100} value={pct} />
            <p>{chosen[2]} · progression simulée, aucun fichier transféré</p>
          </div>
        )}
        {step === 'done' && (
          <div className="v-done" role="status">
            <strong>
              <Icon name="check" />
              Simulation terminée
            </strong>
            <p>
              {folder}\{name}
            </p>
            <button
              className="v-button"
              onClick={() => {
                setStep('idle');
                setPct(0);
                setSel(0);
                setAudio(false);
              }}
            >
              Recommencer
            </button>
          </div>
        )}
        <p className="v-demo-note">
          Exemple Windows · formats et tailles fictifs. Aucun téléchargement réel.
        </p>
      </div>
    </div>
  );
}
