import { Button } from '../../components/Button';
import { EmptyState } from '../../components/Feedback';

/**
 * Browser tab (design M5 navigation). The Android browser is a native
 * WebView (designs M1–M4) still in development: say so instead of showing
 * a control that does nothing.
 */
export function MobileBrowser({ onPasteLink }: { onPasteLink: () => void }) {
  return (
    <div className="flex flex-1 flex-col px-4 pb-5 pt-2">
      <h1 className="m-0 flex h-12 items-center text-[22px] font-bold tracking-[-0.02em]">
        Browser
      </h1>
      <div className="grid flex-1 place-items-center">
        <EmptyState
          icon="travel_explore"
          title="Coming to Android"
          variant="plain"
          action={
            <Button variant="primary" pill size="lg" icon="link" onClick={onPasteLink}>
              Paste a link
            </Button>
          }
        >
          The built-in browser is in development for Android. Meanwhile, paste a link on Home.
        </EmptyState>
      </div>
    </div>
  );
}
