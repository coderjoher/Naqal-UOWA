import { clsx } from 'clsx';
import { forwardRef, useId, type InputHTMLAttributes } from 'react';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  error?: string;
  hint?: string;
}

/** Label always visible above the field (never placeholder-only). */
export const Input = forwardRef<HTMLInputElement, InputProps>(function Input({ label, error, hint, className, id, ...rest }, ref) {
  const autoId = useId();
  const inputId = id ?? autoId;
  const msgId = `${inputId}-msg`;
  const msg = error ?? hint;
  return (
    <div className={clsx('flex flex-col gap-2', className)}>
      <label htmlFor={inputId} className="text-label text-text">
        {label}
      </label>
      <input
        ref={ref}
        id={inputId}
        aria-invalid={error ? true : undefined}
        aria-describedby={msg ? msgId : undefined}
        className={clsx(
          'h-12 rounded-md border bg-surface px-4 text-body text-text placeholder:text-text-muted transition-colors duration-200',
          'focus:border-primary focus:outline-none',
          error ? 'border-danger' : 'border-border',
        )}
        {...rest}
      />
      {msg ? (
        <p id={msgId} className={clsx('text-caption', error ? 'text-danger' : 'text-text-muted')} role={error ? 'alert' : undefined}>
          {msg}
        </p>
      ) : null}
    </div>
  );
});
