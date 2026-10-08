import { clsx } from 'clsx';
import { motion } from 'motion/react';
import { createContext, useContext, type ReactNode } from 'react';
import { listVariants } from './motion';

/** What the app shell adds to every page header: today's date and the global tools (search, theme, language). */
export interface PageChrome {
  dateLine?: string;
  tools?: ReactNode;
}
export const PageChromeContext = createContext<PageChrome>({});

/**
 * Page top bar: date line, big title, the shell's global tools and the page's own actions
 * (the first action is the page's primary pill). Wraps onto several rows on narrow screens.
 */
export function PageHeader({ title, description, actions }: { title: string; description?: string; actions?: ReactNode }) {
  const { dateLine, tools } = useContext(PageChromeContext);
  return (
    <header className="flex flex-wrap items-center gap-x-3 gap-y-4">
      <div className="min-w-0 flex-[1_1_320px]">
        {dateLine ? <p className="text-label font-normal text-text-muted">{dateLine}</p> : null}
        <h1 className="text-[26px] leading-[34px] font-semibold text-balance md:text-[30px] md:leading-[40px]">{title}</h1>
        {description ? <p className="mt-1 max-w-2xl text-label font-normal text-text-muted">{description}</p> : null}
      </div>
      {tools ? <div className="flex min-w-0 flex-[1_1_320px] items-center gap-2 sm:flex-[0_1_auto]">{tools}</div> : null}
      {actions ? <div className="flex flex-wrap items-center gap-3">{actions}</div> : null}
    </header>
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
