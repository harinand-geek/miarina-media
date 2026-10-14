import { EmptyState } from '../../components/Feedback';
import { Button } from '../../components/Button';
import { useUi } from '../../stores/ui';

/**
 * The browser opens in its own window (design D1). This screen only shows
 * where that window cannot exist: the UI preview in a plain web browser.
 */
export default function BrowserScreen() {
  const go = useUi((s) => s.go);
  return (
    <div className="grid flex-1 place-items-center p-10">
      <EmptyState
        icon="travel_explore"
        title="The browser opens in its own window"
        action={
          <Button variant="primary" icon="link" onClick={() => go('home')}>
            Paste a link instead
          </Button>
        }
      >
        This preview runs in a web browser, so it cannot open the built-in browser window. Use the
        desktop app to browse pages and download the media they contain.
      </EmptyState>
    </div>
  );
}
