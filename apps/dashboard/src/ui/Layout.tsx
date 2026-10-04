import { clsx } from 'clsx';
import { motion } from 'motion/react';
import type { ReactNode } from 'react';
import { listVariants } from './motion';

export function PageHeader({ title, description, actions }: { title: string; description?: string; actions?: ReactNode }) {
  return (
    <div className="flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        <h1 className="text-title">{title}</h1>
        {description ? <p className="mt-1 max-w-2xl text-text-muted">{description}</p> : null}
      </div>
      {actions ? <div className="flex flex-wrap gap-3">{actions}</div> : null}
    </div>
  );
}

/** Vertical stack whose `animated` children appear one after another. */
export function Stagger({ className, children }: { className?: string; children: ReactNode }) {
  return (
    <motion.div className={clsx('flex flex-col gap-6', className)} variants={listVariants} initial="hidden" animate="show">
      {children}
    </motion.div>
  );
}

const DAY_BITS = [0, 1, 2, 3, 4, 5, 6];

/** Toggle group for a weekday bit mask (bit 0 = Sunday). */
export function WeekdayPicker({ value, onChange, labels, legend }: { value: number; onChange: (v: number) => void; labels: string[]; legend: string }) {
  return (
    <fieldset className="flex flex-col gap-2">
      <legend className="mb-2 text-label">{legend}</legend>
      <div className="flex flex-wrap gap-2">
        {DAY_BITS.map((bit) => {
          const on = (value & (1 << bit)) !== 0;
          return (
            <motion.button
              key={bit}
              type="button"
              aria-pressed={on}
              onClick={() => onChange(value ^ (1 << bit))}
              whileTap={{ scale: 0.92 }}
              className={clsx(
                'h-10 min-w-12 rounded-pill border px-3 text-label transition-colors duration-200',
                on ? 'border-primary bg-primary text-on-primary' : 'border-border bg-surface text-text hover:bg-surface-muted',
              )}
            >
              {labels[bit]}
            </motion.button>
          );
        })}
      </div>
    </fieldset>
  );
}
