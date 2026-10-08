import { X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useEffect, useRef, type ReactNode } from 'react';
import { spring } from './motion';

/** Side panel for forms. Slides from the inline-end edge (left in RTL). Esc and backdrop close it. */
export function Drawer({ open, title, onClose, children, footer }: { open: boolean; title: string; onClose: () => void; children: ReactNode; footer?: ReactNode }) {
  const panel = useRef<HTMLDivElement>(null);
  const rtl = typeof document !== 'undefined' && document.documentElement.dir === 'rtl';

  useEffect(() => {
    if (!open) return;
    const prev = document.activeElement as HTMLElement | null;
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose();
    window.addEventListener('keydown', onKey);
    setTimeout(() => panel.current?.querySelector<HTMLElement>('input,select,textarea,button')?.focus(), 50);
    return () => {
      window.removeEventListener('keydown', onKey);
      prev?.focus?.();
    };
  }, [open, onClose]);

  return (
    <AnimatePresence>
      {open ? (
        <div className="fixed inset-0 z-40">
          <motion.div className="absolute inset-0 bg-ink/40 backdrop-blur-[2px] dark:bg-bg/70" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} onClick={onClose} aria-hidden />
          <motion.div
            ref={panel}
            role="dialog"
            aria-modal="true"
            aria-label={title}
            className="absolute inset-y-0 end-0 flex w-full max-w-lg flex-col overflow-hidden bg-surface shadow-card sm:inset-y-3 sm:end-3 sm:rounded-lg sm:border sm:border-border"
            initial={{ x: rtl ? '-100%' : '100%' }}
            animate={{ x: 0 }}
            exit={{ x: rtl ? '-100%' : '100%' }}
            transition={spring}
          >
            <header className="flex items-center justify-between gap-4 px-6 pt-6 pb-4">
              <h2 className="text-title">{title}</h2>
              <button type="button" onClick={onClose} aria-label="close" className="grid size-11 place-items-center rounded-pill border border-border text-text-muted transition-colors hover:bg-surface-muted hover:text-text">
                <X className="size-5" aria-hidden />
              </button>
            </header>
            <div className="flex-1 overflow-y-auto px-6 pt-2 pb-6">{children}</div>
            {footer ? <footer className="flex flex-wrap gap-3 border-t border-border bg-surface-muted/50 px-6 py-4">{footer}</footer> : null}
          </motion.div>
        </div>
      ) : null}
    </AnimatePresence>
  );
}
