import { Button } from '../../components/Button';
import { Icon } from '../../components/Icon';

/** Design system §6 "No downloadable media found". "Report link" is hidden in the MVP (Q3). */
export function NoMediaFound({ onRetry, reason }: { onRetry: () => void; reason?: string }) {
  return (
    <div role="alert" className="flex max-w-[480px] flex-col gap-2.5 rounded-lg bg-surface p-6">
      <Icon name="link_off" size={28} className="text-danger" />
      <span className="text-[15px] font-bold">No downloadable media found</span>
      <span className="text-[13px] leading-normal text-muted">
        This page may be private, require sign-in, or be a live stream. Miarina Media only lists
        formats the source actually provides.
      </span>
      {reason && (
        <span className="text-[12.5px] text-muted">
          Reason: <span className="text-fg">{reason}</span>
        </span>
      )}
      <div className="mt-1.5 flex gap-2">
        <Button size="sm" className="h-[34px] text-[13px]" onClick={onRetry}>
          Try again
        </Button>
      </div>
    </div>
  );
}
