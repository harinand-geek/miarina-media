import { create } from 'zustand';
import { invoke } from '@tauri-apps/api/core';
import { inTauri } from '../../services/platform';
import { useUi } from '../../stores/ui';
interface Release { version: string; notes: string; size: number }
type Phase = 'idle' | 'checking' | 'available' | 'downloading' | 'ready' | 'installing';
interface State { phase: Phase; release: Release | null; error: string; checked: boolean; check: (notify?: boolean) => Promise<void>; download: () => Promise<void>; install: () => Promise<void> }
const message = (e: unknown) => typeof e === 'object' && e && 'message' in e ? String(e.message) : String(e);
export const useUpdates = create<State>((set,get) => ({
 phase:'idle',release:null,error:'',checked:false,
 check: async (notify=false) => {
  if(!inTauri() || ['checking','downloading','ready','installing'].includes(get().phase)) return;
  set({phase:'checking',error:''});
  try {
   const release=await invoke<Release|null>('app_update_check');
   set({release,phase:release?'available':'idle',checked:true});
   if(release && notify) useUi.getState().pushToast({tone:'success',message:`Miarina ${release.version} est disponible`,action:{label:'Voir',run:()=>useUi.getState().go('settings')}});
  } catch(e) {set({phase:get().release?'available':'idle',error:message(e)});}
 },
 download:async()=>{
  if(get().phase!=='available')return;
  set({phase:'downloading',error:''});
  try {const release=await invoke<Release>('app_update_download');set({release,phase:'ready'});}
  catch(e){set({phase:'available',error:message(e)});}
 },
 install:async()=>{
  if(get().phase!=='ready')return;
  set({phase:'installing',error:''});
  try {await invoke('app_update_install');set({phase:'ready'});}
  catch(e){set({phase:'ready',error:message(e)});}
 }
}));
