import { beforeEach, describe, expect, it, vi } from 'vitest';
const mocks=vi.hoisted(()=>({invoke:vi.fn()}));
vi.mock('@tauri-apps/api/core',()=>({invoke:mocks.invoke}));
vi.mock('../../services/platform',()=>({inTauri:()=>true}));
import { useUpdates } from './useUpdates';
const release={version:'0.1.8',notes:'Test',size:100};
beforeEach(()=>{mocks.invoke.mockReset();useUpdates.setState({phase:'idle',release:null,error:'',checked:false});});
describe('application updates',()=>{
 it('checks and downloads without installing automatically',async()=>{
  mocks.invoke.mockResolvedValue(release);
  await useUpdates.getState().check();
  expect(useUpdates.getState().phase).toBe('available');
  await useUpdates.getState().download();
  expect(useUpdates.getState().phase).toBe('ready');
  expect(mocks.invoke.mock.calls.map(c=>c[0])).toEqual(['app_update_check','app_update_download']);
 });
 it('keeps installation disabled after a failed verification',async()=>{
  mocks.invoke.mockResolvedValueOnce(release).mockRejectedValueOnce({message:'Invalid signature'});
  await useUpdates.getState().check();await useUpdates.getState().download();
  expect(useUpdates.getState().phase).toBe('available');
  expect(useUpdates.getState().error).toBe('Invalid signature');
  await useUpdates.getState().install();expect(mocks.invoke).toHaveBeenCalledTimes(2);
 });
 it('allows retry after Android install permission denial',async()=>{
  useUpdates.setState({phase:'ready',release});mocks.invoke.mockRejectedValue({message:'Allow installation'});
  await useUpdates.getState().install();expect(useUpdates.getState().phase).toBe('ready');
  expect(useUpdates.getState().error).toBe('Allow installation');
 });
});
