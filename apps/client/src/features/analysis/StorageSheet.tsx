import { RadioDot } from '../../components/Controls';
import { Icon } from '../../components/Icon';
import { BottomSheet } from '../../components/Overlay';
import { ANDROID_STORES } from '../../dev/fixtures';
import { useSettings } from '../../stores/settings';

/** Android "Save to" picker (Phase 4: backed by MediaStore / SAF). */
export function StorageSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const current = useSettings((s) => s.androidStore);
  const setStore = useSettings((s) => s.setAndroidStore);
  return (
    <BottomSheet open={open} onClose={onClose} label="Save to" elevated>
      <h2 className="m-0 py-2 text-[17px] font-bold">Save to</h2>
      <div role="radiogroup" aria-label="Storage" className="flex flex-col gap-2">
        {ANDROID_STORES.map((s) => {
          const on = s.id === current;
          return (
            <button
              key={s.id}
              type="button"
              role="radio"
              aria-checked={on}
              onClick={() => {
                setStore(s.id);
                onClose();
              }}
              className={`flex flex-col gap-2.5 rounded-[14px] border p-3.5 text-left ${on ? 'border-accent bg-selected' : 'border-line-strong bg-surface'}`}
            >
              <span className="flex w-full items-center gap-3">
                <Icon name={s.icon} size={24} className="text-accent-strong" />
                <span className="flex flex-1 flex-col">
                  <span className="text-[15px] font-bold">{s.label}</span>
                  <span className="font-mono text-[11.5px] text-muted">{s.path}</span>
                </span>
                <RadioDot checked={on} size={20} />
              </span>
              <span className="h-1.5 w-full overflow-hidden rounded-[3px] bg-bg" aria-hidden="true">
                <span className="block h-full bg-paused" style={{ width: `${s.used}%` }} />
              </span>
              <span className="text-[12.5px] text-muted">{s.free}</span>
            </button>
          );
        })}
      </div>
    </BottomSheet>
  );
}
