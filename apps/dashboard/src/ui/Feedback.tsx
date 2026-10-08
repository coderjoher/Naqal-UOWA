import { clsx } from 'clsx';
import { CircleAlert, CircleCheck, type LucideIcon, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';
import { spring } from './motion';

/** Flat block whose opacity pulses (no shimmer effect). */
export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden className={clsx('animate-pulse rounded-sm bg-border', className)} />;
}

export function SkeletonRows({ rows = 4 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-3" role="status" aria-label="loading">
      {Array.from({ length: rows }, (_, i) => (
        <Skeleton key={i} className={clsx('h-10', i % 2 ? 'w-11/12' : 'w-full')} />
      ))}
    </div>
  );
}

export function EmptyState({ icon: Icon, title, message, action }: { icon: LucideIcon; title: string; message?: string; action?: ReactNode }) {
  return (
    <motion.div initial={{ opacity: 0, scale: 0.98 }} animate={{ opacity: 1, scale: 1 }} className="flex flex-col items-center gap-3 px-6 py-12 text-center">
      <span className="grid size-16 place-items-center rounded-lg bg-primary-soft text-primary">
        <Icon className="size-7" aria-hidden />
      </span>
      <h3 className="text-headline">{title}</h3>
      {message ? <p className="max-w-md text-text-muted">{message}</p> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </motion.div>
  );
}

/** Counts up to `value` when it appears or changes. */
export function AnimatedNumber({ value, format = (n) => n.toLocaleString('en-US') }: { value: number; format?: (n: number) => string }) {
  const [shown, setShown] = useState(value);
  const from = useRef(0);
  useEffect(() => {
    const start = performance.now();
    const a = from.current;
    const reduce = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (reduce) {
      setShown(value);
      from.current = value;
      return;
    }
    let raf = 0;
    const tick = (t: number) => {
      const p = Math.min(1, (t - start) / 600);
      const eased = 1 - (1 - p) ** 3;
      setShown(Math.round(a + (value - a) * eased));
      if (p < 1) raf = requestAnimationFrame(tick);
      else from.current = value;
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [value]);
  return <span className="tabular">{format(shown)}</span>;
}

/* ---------------- Toasts ---------------- */

interface Toast {
  id: number;
  tone: 'success' | 'danger';
  message: string;
}

const ToastCtx = createContext<(tone: Toast['tone'], message: string) => void>(() => {});

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const nextId = useRef(1);
  const dismiss = useCallback((id: number) => setToasts((ts) => ts.filter((t) => t.id !== id)), []);
  const push = useCallback(
    (tone: Toast['tone'], message: string) => {
      const id = nextId.current++;
      setToasts((ts) => [...ts.slice(-2), { id, tone, message }]);
      setTimeout(() => dismiss(id), 3500);
    },
    [dismiss],
  );
  return (
    <ToastCtx.Provider value={push}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 bottom-24 z-50 md:bottom-6 flex flex-col items-center gap-2 px-4" aria-live="polite">
        <AnimatePresence initial={false}>
          {toasts.map((t) => (
            <motion.div
              key={t.id}
              layout
              initial={{ opacity: 0, y: 16, scale: 0.96 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={{ opacity: 0, y: 8, scale: 0.96 }}
              transition={spring}
              role={t.tone === 'danger' ? 'alert' : 'status'}
              className="pointer-events-auto flex items-center gap-3 rounded-pill bg-ink px-5 py-3 text-label text-on-ink shadow-card"
            >
              {t.tone === 'success' ? <CircleCheck className="size-5 text-success-soft" aria-hidden /> : <CircleAlert className="size-5 text-danger-soft" aria-hidden />}
              <span>{t.message}</span>
              <button type="button" onClick={() => dismiss(t.id)} className="ms-2 opacity-70 hover:opacity-100" aria-label="close">
                <X className="size-4" aria-hidden />
              </button>
            </motion.div>
          ))}
        </AnimatePresence>
      </div>
    </ToastCtx.Provider>
  );
}

export const useToast = () => useContext(ToastCtx);
