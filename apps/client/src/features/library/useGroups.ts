import { useEffect, useState } from 'react';
import { backend } from '../../services/backend';
import type { GroupBy, MediaGroup } from '../../services/types';

/** Albums, artists or folders, reloaded when the library changes (`null` while loading). */
export function useGroups(by: GroupBy) {
  const [state, setState] = useState<{ by: GroupBy; groups: MediaGroup[] | Error } | null>(null);
  useEffect(() => {
    let alive = true;
    const load = () =>
      backend
        .libraryGroups(by)
        .then((groups) => alive && setState({ by, groups }))
        .catch((e: unknown) => alive && setState({ by, groups: e instanceof Error ? e : new Error(String(e)) }));
    void load();
    const stop = backend.onLibraryChanged(() => void load());
    return () => {
      alive = false;
      stop();
    };
  }, [by]);
  return state?.by === by ? state.groups : null;
}
