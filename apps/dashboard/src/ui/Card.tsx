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
        <header className="mb-5 flex flex-wrap items-start justify-between gap-4">
          <div className="min-w-0">
            {title ? <h2 className="text-headline">{title}</h2> : null}
            {description ? <p className="mt-1 text-caption text-text-muted">{description}</p> : null}
          </div>
          {actions}
        </header>
      ) : null}
      {children}
    </>
  );
  const classes = clsx('rounded-lg bg-surface p-6', nested ? 'border border-border' : 'shadow-card', className);
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
