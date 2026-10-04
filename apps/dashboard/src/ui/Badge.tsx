import { clsx } from 'clsx';
import type { ReactNode } from 'react';

export type Tone = 'neutral' | 'primary' | 'success' | 'warning' | 'danger' | 'female-only';

const TONES: Record<Tone, string> = {
  neutral: 'bg-surface-muted text-text-muted',
  primary: 'bg-primary-soft text-primary',
  success: 'bg-success-soft text-success',
  warning: 'bg-warning-soft text-warning',
  danger: 'bg-danger-soft text-danger',
  'female-only': 'bg-female-only-soft text-female-only',
};

/** Status = colour + dot + word. The label is required so colour is never the only signal. */
export function Badge({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return (
    <span data-tone={tone} className={clsx('inline-flex h-7 items-center gap-2 rounded-pill px-3 text-caption font-medium', TONES[tone])}>
      <span className="size-2 rounded-pill bg-current" aria-hidden />
      {children}
    </span>
  );
}
