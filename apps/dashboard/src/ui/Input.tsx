import type React from 'react';
import { clsx } from 'clsx';
import { forwardRef, useId, type InputHTMLAttributes, type ReactNode, type SelectHTMLAttributes } from 'react';

interface FieldProps {
  label: string;
  error?: string;
  hint?: string;
  className?: string;
  suffix?: ReactNode;
}

const control = (error?: string) =>
  clsx(
    'h-12 w-full rounded-md border bg-surface px-4 text-body text-text placeholder:text-text-muted transition-[border-color,box-shadow] duration-200',
    'focus:border-primary focus:outline-none focus:shadow-[0_0_0_4px_var(--color-primary-soft)]',
    error ? 'border-danger' : 'border-border hover:border-text-muted',
  );

function FieldShell({ id, label, error, hint, className, children }: FieldProps & { id: string; children: ReactNode }) {
  const msg = error ?? hint;
  return (
    <div className={clsx('flex min-w-0 flex-col gap-2', className)}>
      <label htmlFor={id} className="text-label text-text">
        {label}
      </label>
      {children}
      {msg ? (
        <p id={`${id}-msg`} className={clsx('text-caption', error ? 'text-danger' : 'text-text-muted')} role={error ? 'alert' : undefined}>
          {msg}
        </p>
      ) : null}
    </div>
  );
}

export interface InputProps extends InputHTMLAttributes<HTMLInputElement>, FieldProps {}

/** Label always visible above the field (never placeholder-only). */
export const Input = forwardRef<HTMLInputElement, InputProps>(function Input({ label, error, hint, className, id, suffix, ...rest }, ref) {
  const autoId = useId();
  const inputId = id ?? autoId;
  return (
    <FieldShell id={inputId} label={label} error={error} hint={hint} className={className}>
      <div className="relative">
        <input
          ref={ref}
          id={inputId}
          aria-invalid={error ? true : undefined}
          aria-describedby={error || hint ? `${inputId}-msg` : undefined}
          className={clsx(control(error), suffix ? 'pe-14' : undefined)}
          {...rest}
        />
        {suffix ? <span className="pointer-events-none absolute inset-y-0 end-4 grid place-items-center text-caption text-text-muted">{suffix}</span> : null}
      </div>
    </FieldShell>
  );
});

export interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement>, FieldProps {}

export const Select = forwardRef<HTMLSelectElement, SelectProps>(function Select({ label, error, hint, className, id, children, ...rest }, ref) {
  const autoId = useId();
  const selectId = id ?? autoId;
  return (
    <FieldShell id={selectId} label={label} error={error} hint={hint} className={className}>
      <select ref={ref} id={selectId} aria-invalid={error ? true : undefined} className={control(error)} {...rest}>
        {children}
      </select>
    </FieldShell>
  );
});

export interface TextareaProps extends React.TextareaHTMLAttributes<HTMLTextAreaElement>, FieldProps {}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea({ label, error, hint, className, id, ...rest }, ref) {
  const autoId = useId();
  const tid = id ?? autoId;
  return (
    <FieldShell id={tid} label={label} error={error} hint={hint} className={className}>
      <textarea ref={ref} id={tid} rows={3} aria-invalid={error ? true : undefined} className={clsx(control(error), 'h-auto py-3')} {...rest} />
    </FieldShell>
  );
});
