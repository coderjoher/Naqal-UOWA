import { Slot } from '@radix-ui/react-slot';
import { clsx } from 'clsx';
import { forwardRef, type ButtonHTMLAttributes } from 'react';

type Variant = 'primary' | 'secondary' | 'ink' | 'ghost' | 'danger';
type Size = 'md' | 'sm';

const VARIANTS: Record<Variant, string> = {
  primary: 'bg-primary text-on-primary hover:bg-primary-pressed',
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
  /** Render the child element (e.g. a link) with button styling. */
  asChild?: boolean;
}

/** One `primary` per screen; everything else is secondary/ghost (design-system.md). */
export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'primary', size = 'md', loading, asChild, disabled, className, children, type, ...rest },
  ref,
) {
  const Comp = asChild ? Slot : 'button';
  return (
    <Comp
      ref={ref}
      type={asChild ? undefined : (type ?? 'button')}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      data-variant={variant}
      className={clsx(
        'inline-flex select-none items-center justify-center gap-2 rounded-pill font-medium transition-colors duration-200',
        'disabled:cursor-not-allowed disabled:opacity-50 active:scale-[0.98]',
        VARIANTS[variant],
        SIZES[size],
        className,
      )}
      {...rest}
    >
      {loading ? <span className="size-4 animate-spin rounded-pill border-2 border-current border-e-transparent" aria-hidden /> : null}
      {children}
    </Comp>
  );
});
