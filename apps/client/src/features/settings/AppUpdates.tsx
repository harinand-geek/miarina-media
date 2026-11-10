import { invoke } from '@tauri-apps/api/core';
import { useEffect, useState } from 'react';
import { useUpdates } from './useUpdates';
import { version } from '../../../package.json';
import { Button } from '../../components/Button';
export function UpdateMonitor() {
 useEffect(()=>{
  const check=()=>{if(document.visibilityState==='visible')void useUpdates.getState().check(true);};
  const timer=setTimeout(check,15000);
  const interval=setInterval(check,6*60*60*1000);
  return()=>{clearTimeout(timer);clearInterval(interval);};
 },[]);
 return null;
}
export function AppUpdates() {
 const {phase,release,error,checked,check,download,install}=useUpdates();
 const [downloaded,setDownloaded]=useState(0);
 useEffect(()=>{
  if(phase!=='downloading')return;
  let alive=true;
  const timer=setInterval(()=>{void invoke<number>('app_update_progress').then(n=>{if(alive)setDownloaded(n);}).catch(()=>{});},1000);
  return()=>{alive=false;clearInterval(timer);};
 },[phase]);
 const busy=['checking','downloading','installing'].includes(phase);
 return <section className="m-4 rounded-lg border border-divider p-4" aria-label="Mises à jour">
  <h2 className="font-bold">Mises à jour de Miarina</h2>
  <p className="my-2 text-sm text-muted">Version installée : {version}. Recherche automatique au démarrage et toutes les six heures.</p>
  {release && <p className="my-2 text-sm whitespace-pre-line">Version {release.version} · {(release.size/1048576).toFixed(1)} Mio{'\n'}{release.notes}</p>}
  <p role="status" className="my-2 text-sm">{phase==='checking'?'Recherche…':phase==='downloading'?'Téléchargement et vérification en cours…':phase==='ready'?'Mise à jour vérifiée, prête à installer.':phase==='installing'?'Ouverture de l’installation…':checked&&!release?'Vous utilisez la dernière version.':''}</p>
  {phase==='downloading' && release && <progress className="w-full" aria-label="Téléchargement de la mise à jour" value={downloaded} max={release.size} />}
  {error && <p role="alert" className="my-2 text-sm text-muted">{error}</p>}
  <div className="flex flex-wrap gap-2">
   <Button disabled={busy||phase==='ready'} onClick={()=>void check()}>Rechercher une mise à jour</Button>
   {phase==='available'&&<Button onClick={()=>void download()}>Télécharger dans Miarina</Button>}
   {phase==='ready'&&<Button onClick={()=>void install()}>Installer la mise à jour</Button>}
  </div>
  <p className="mt-3 text-xs text-muted">Terminez ou mettez en pause les téléchargements avant d’installer. Windows ferme l’application et ouvre l’installateur. Android demande votre confirmation. Vos réglages et votre bibliothèque sont conservés.</p>
 </section>;
}
