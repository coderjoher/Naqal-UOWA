import { clsx } from 'clsx';
import type { HTMLAttributes, ReactNode } from 'react';

export interface CardProps extends Omit<HTMLAttributes<HTMLElement>, 'title'> {
  title?: ReactNode;
  actions?: ReactNode;
  /** Nested cards are flat (no shadow), per the one-shadow rule. */
  nested?: boolean;
}

export function Card({ title, actions, nested, className, children, ...rest }: CardProps) {
  return (
    <section className={clsx('rounded-lg bg-surface p-6', nested ? 'border border-border' : 'shadow-card', className)} {...rest}>
      {title || actions ? (
        <header className="mb-4 flex items-center justify-between gap-4">
          {title ? <h2 className="text-headline">{title}</h2> : <span />}
          {actions}
        </header>
      ) : null}
      {children}
    </section>
  );
}
