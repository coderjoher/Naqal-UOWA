import { clsx } from 'clsx';
import { motion } from 'motion/react';
import type { HTMLAttributes, ReactNode } from 'react';
import { itemVariants } from './motion';

export interface CardProps extends Omit<HTMLAttributes<HTMLElement>, 'title'> {
  title?: ReactNode;
  description?: ReactNode;
  actions?: ReactNode;
  /** Nested cards are flat (no shadow), per the one-shadow rule. */
  nested?: boolean;
  /** Participate in a parent list's stagger animation. */
  animated?: boolean;
}

export function Card({ title, description, actions, nested, animated, className, children, ...rest }: CardProps) {
  const body = (
    <>
      {title || actions ? (
        <header className="mb-5 flex flex-wrap items-center justify-between gap-3">
          <div className="min-w-0">
            {title ? <h2 className="text-headline">{title}</h2> : null}
            {description ? <p className="mt-1 text-label font-normal text-text-muted">{description}</p> : null}
          </div>
          {actions}
        </header>
      ) : null}
      {children}
    </>
  );
  // 24 px radius, hairline border; top-level cards add the single soft card shadow (none in dark).
  const classes = clsx('min-w-0 rounded-lg border border-border bg-surface p-5 md:p-6', nested ? undefined : 'shadow-card dark:shadow-none', className);
  if (animated) {
    return (
      <motion.section variants={itemVariants} className={classes} {...(rest as object)}>
        {body}
      </motion.section>
    );
  }
  return (
    <section className={classes} {...rest}>
      {body}
    </section>
  );
}
