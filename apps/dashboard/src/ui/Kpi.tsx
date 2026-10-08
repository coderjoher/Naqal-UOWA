import { clsx } from 'clsx';
import type { LucideIcon } from 'lucide-react';
import { motion } from 'motion/react';
import type { ReactNode } from 'react';
import { AnimatedNumber, Skeleton } from './Feedback';
import { itemVariants, spring } from './motion';

/**
 * Big-number tile. `brand` is the solid university-blue lead tile (gold sub-line), `gold` the
 * soft-gold tile used for taxis and money, `plain` a white card. Pages put one `brand` tile first.
 */
export type KpiTone = 'brand' | 'plain' | 'gold';
export type KpiSubTone = 'default' | 'success' | 'warning' | 'danger';

const TILE: Record<KpiTone, string> = {
  // Dark: university blue is a light tint, so the lead tile becomes a deep blue card with a blue rim.
  brand: 'bg-primary text-on-primary dark:bg-primary-soft dark:text-text dark:border dark:border-primary/40',
  plain: 'bg-surface text-text border border-border',
  gold: 'bg-accent-soft text-on-accent dark:text-text dark:border dark:border-accent/30',
};
const LABEL: Record<KpiTone, string> = {
  brand: 'text-on-primary/85 dark:text-text-muted',
  plain: 'text-text-muted',
  gold: 'text-on-accent/80 dark:text-text-muted',
};
const ICON: Record<KpiTone, string> = {
  brand: 'bg-on-primary/15 text-on-primary dark:bg-primary/20 dark:text-primary',
  plain: 'bg-primary-soft text-primary',
  gold: 'bg-accent text-on-accent',
};
const SUB: Record<KpiSubTone, string> = {
  default: 'text-text-muted',
  success: 'text-success',
  warning: 'text-warning',
  danger: 'text-danger',
};

export interface KpiProps {
  label: string;
  value: number;
  format?: (n: number) => string;
  icon?: LucideIcon;
  tone?: KpiTone;
  sub?: ReactNode;
  subTone?: KpiSubTone;
  loading?: boolean;
  /** Kept on the number for tests that read raw values. */
  testId?: string;
  /** Smaller number for long values (money). */
  compact?: boolean;
  className?: string;
}

export function Kpi({ label, value, format, icon: Icon, tone = 'plain', sub, subTone = 'default', loading, testId, compact, className }: KpiProps) {
  // The gold sub-line belongs to the brand tile; elsewhere the sub-line carries a status colour.
  const subClass = tone === 'brand' ? 'text-accent' : tone === 'gold' ? 'text-on-accent/80 dark:text-accent' : SUB[subTone];
  return (
    <motion.div
      variants={itemVariants}
      whileHover={{ y: -2 }}
      transition={spring}
      className={clsx('flex min-w-0 flex-col gap-1.5 rounded-lg p-5', TILE[tone], className)}
    >
      <div className="flex items-start justify-between gap-3">
        <span className={clsx('text-label font-normal', LABEL[tone])}>{label}</span>
        {Icon ? (
          <span className={clsx('grid size-9 shrink-0 place-items-center rounded-pill', ICON[tone])} aria-hidden>
            <Icon className="size-[18px]" />
          </span>
        ) : null}
      </div>
      <div className={clsx('truncate font-bold', compact ? 'text-[20px] leading-[30px] sm:text-[26px] sm:leading-[36px]' : 'text-[30px] leading-[38px] sm:text-[36px] sm:leading-[44px]')} data-testid={testId} data-value={testId ? value : undefined}>
        {loading ? <Skeleton className="my-1.5 h-8 w-16 opacity-60" /> : <AnimatedNumber value={value} format={format} />}
      </div>
      {sub ? <p className={clsx('min-h-4 truncate text-caption font-medium', subClass)}>{sub}</p> : null}
    </motion.div>
  );
}

/** Responsive bento row for KPI tiles. */
export function KpiGrid({ cols = 4, className, children }: { cols?: 2 | 3 | 4; className?: string; children: ReactNode }) {
  const grid = cols === 4 ? 'xl:grid-cols-4' : cols === 3 ? 'md:grid-cols-3' : 'sm:grid-cols-2';
  return (
    <motion.section className={clsx('grid grid-cols-2 gap-3 md:gap-4', grid, className)} variants={{ show: { transition: { staggerChildren: 0.05 } } }} initial="hidden" animate="show">
      {children}
    </motion.section>
  );
}
