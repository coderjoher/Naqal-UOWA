import { Slot } from '@radix-ui/react-slot';
import { clsx } from 'clsx';
import { LoaderCircle, type LucideIcon } from 'lucide-react';
import { motion } from 'motion/react';
import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { spring } from './motion';

type Variant = 'primary' | 'secondary' | 'ink' | 'ghost' | 'danger';
type Size = 'md' | 'sm';

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-primary text-on-primary hover:bg-primary-pressed shadow-card',
  secondary: 'bg-surface text-text border border-border hover:bg-surface-muted',
  ink: 'bg-ink text-on-primary hover:opacity-90',
  ghost: 'bg-transparent text-primary hover:bg-primary-soft',
  danger: 'bg-danger text-on-primary hover:opacity-90',
};
const SIZES: Record<Size, string> = { md: 'h-12 px-6 text-label', sm: 'h-10 px-4 text-label' };

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  icon?: LucideIcon;
  /** Render the child element (e.g. a link) with button styling. */
  asChild?: boolean;
}

const MotionButton = motion.create('button');

/** One `primary` per screen; everything else is secondary/ghost (design-system.md). */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', loading, asChild, disabled, className, children, type, icon: Icon, ...rest },
  ref,
) {
  const classes = clsx(
    'relative inline-flex select-none items-center justify-center gap-2 rounded-pill font-medium transition-colors duration-200',
    'disabled:cursor-not-allowed disabled:opacity-50',
    VARIANTS[variant],
    SIZES[size],
    className,
  );
  const content = (
    <>
      {loading ? <LoaderCircle className="size-4 animate-spin" aria-hidden /> : Icon ? <Icon className="size-4" aria-hidden /> : null}
      {children}
    </>
  );
  if (asChild) {
    return (
      <Slot ref={ref} data-variant={variant} className={classes} {...rest}>
        {children}
      </Slot>
    );
  }
  const inactive = disabled || loading;
  return (
    <MotionButton
      ref={ref}
      type={type ?? 'button'}
      disabled={inactive}
      aria-busy={loading || undefined}
      data-variant={variant}
      className={classes}
      whileHover={inactive ? undefined : { y: -1 }}
      whileTap={inactive ? undefined : { scale: 0.97, y: 0 }}
      transition={spring}
      {...(rest as object)}
    >
      {content}
    </MotionButton>
  );
});

export interface IconButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  icon: LucideIcon;
  label: string;
  tone?: 'default' | 'danger';
}

/** Round icon-only button; the label is announced and shown as a tooltip. */
export function IconButton({ icon: Icon, label, tone = 'default', className, ...rest }: IconButtonProps) {
  return (
    <MotionButton
      type="button"
      aria-label={label}
      title={label}
      className={clsx(
        'inline-grid size-10 place-items-center rounded-pill border border-border bg-surface transition-colors duration-200',
        tone === 'danger' ? 'text-danger hover:bg-danger-soft' : 'text-text-muted hover:bg-surface-muted hover:text-text',
        'disabled:opacity-50',
        className,
      )}
      whileHover={{ scale: 1.06 }}
      whileTap={{ scale: 0.92 }}
      transition={spring}
      {...(rest as object)}
    >
      <Icon className="size-4" aria-hidden />
    </MotionButton>
  );
}
