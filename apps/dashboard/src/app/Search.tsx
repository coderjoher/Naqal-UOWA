import { clsx } from 'clsx';
import { Bus, GraduationCap, Search, type LucideIcon } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useEffect, useId, useMemo, useRef, useState } from 'react';
import { useNavigate } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n, type MessageKey } from '../lib/i18n';
import { useDrivers, useStudents } from '../lib/queries';
import { ease } from '../ui/motion';
import { visibleNav } from './nav';

/** Folds Arabic letter variants and diacritics so «احمد» finds «أحمد». */
export function fold(s: string) {
  return s
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[ً-ٰٟـ]/g, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .trim();
}

interface Result {
  id: string;
  section: MessageKey;
  title: string;
  sub?: string;
  icon: LucideIcon;
  to: string;
}

const LIMIT = 5;

/**
 * Global quick search (combobox). Pages always; for the office also students and drivers, filtered
 * in the browser from the same list endpoints their pages use (fetched only once someone types).
 */
export function GlobalSearch() {
  const { t, lang } = useI18n();
  const { hasRole } = useAuth();
  const navigate = useNavigate();
  const office = hasRole('office');
  const [q, setQ] = useState('');
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(0);
  const input = useRef<HTMLInputElement>(null);
  const listId = useId();
  const needle = fold(q);
  const people = office && needle.length >= 2;
  const students = useStudents(people);
  const drivers = useDrivers(people);

  // "/" or Ctrl/⌘+K focuses the search from anywhere (except while typing in a field).
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const el = e.target as HTMLElement | null;
      const typing = el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA' || el.tagName === 'SELECT' || el.isContentEditable);
      if ((e.key === 'k' && (e.ctrlKey || e.metaKey)) || (e.key === '/' && !typing)) {
        e.preventDefault();
        input.current?.focus();
      }
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, []);

  const results = useMemo<Result[]>(() => {
    if (!needle) return [];
    const out: Result[] = [];
    for (const g of visibleNav(hasRole))
      for (const n of g.items)
        if (fold(t(n.label)).includes(needle) || fold(t(n.short)).includes(needle) || n.to.includes(needle))
          out.push({ id: `page:${n.to}`, section: 'search.pages', title: t(n.label), sub: g.label === 'nav.group.main' ? undefined : t(g.label), icon: n.icon, to: n.to });
    if (people) {
      const st = (students.data ?? []).filter((s) => fold(s.name).includes(needle) || fold(s.nameAr ?? '').includes(needle) || s.studentId.toLowerCase().includes(needle)).slice(0, LIMIT);
      for (const s of st)
        out.push({ id: `student:${s.id}`, section: 'search.students', title: (lang === 'ar' && s.nameAr) || s.name, sub: s.studentId, icon: GraduationCap, to: `/students?q=${encodeURIComponent(s.studentId)}` });
      const dr = (drivers.data ?? []).filter((d) => fold(d.name).includes(needle) || (d.phone ?? '').includes(needle) || fold(d.plate ?? '').includes(needle)).slice(0, LIMIT);
      for (const d of dr) out.push({ id: `driver:${d.id}`, section: 'search.drivers', title: d.name || '—', sub: [d.plate, d.phone].filter(Boolean).join(' · '), icon: Bus, to: `/drivers?open=${d.id}` });
    }
    return out;
  }, [needle, hasRole, t, lang, people, students.data, drivers.data]);

  useEffect(() => setActive(0), [needle]);

  function go(r: Result | undefined) {
    if (!r) return;
    setOpen(false);
    setQ('');
    input.current?.blur();
    navigate(r.to);
  }

  const loading = people && (students.isFetching || drivers.isFetching) && results.length === 0;
  const show = open && needle.length > 0;
  const optionId = (i: number) => `${listId}-opt-${i}`;

  return (
    <div className="relative min-w-0 flex-1 sm:w-[300px] sm:flex-none lg:w-[360px]">
      <label className="flex h-12 items-center gap-2.5 rounded-pill border border-border bg-surface px-4 transition-[border-color,box-shadow] duration-200 focus-within:border-primary focus-within:shadow-[0_0_0_4px_var(--color-primary-soft)] hover:border-text-muted">
        <Search className="size-[18px] shrink-0 text-text-muted" aria-hidden />
        <span className="sr-only">{t('search.label')}</span>
        <input
          ref={input}
          type="search"
          role="combobox"
          aria-expanded={show}
          aria-controls={listId}
          aria-autocomplete="list"
          aria-activedescendant={show && results[active] ? optionId(active) : undefined}
          autoComplete="off"
          placeholder={t(office ? 'search.placeholder' : 'search.placeholderPages')}
          value={q}
          onChange={(e) => {
            setQ(e.target.value);
            setOpen(true);
          }}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 120)}
          onKeyDown={(e) => {
            if (e.key === 'ArrowDown') {
              e.preventDefault();
              setOpen(true);
              setActive((i) => Math.min(results.length - 1, i + 1));
            } else if (e.key === 'ArrowUp') {
              e.preventDefault();
              setActive((i) => Math.max(0, i - 1));
            } else if (e.key === 'Enter') {
              e.preventDefault();
              go(results[active]);
            } else if (e.key === 'Escape') {
              if (q) setQ('');
              else input.current?.blur();
              setOpen(false);
            }
          }}
          className="h-full min-w-0 flex-1 bg-transparent text-label font-normal text-text placeholder:text-text-muted focus:outline-none [&::-webkit-search-cancel-button]:hidden"
        />
        <kbd className="hidden rounded-sm border border-border px-1.5 text-caption text-text-muted lg:inline" aria-hidden>
          /
        </kbd>
      </label>
      <AnimatePresence>
        {show ? (
          <motion.div
            initial={{ opacity: 0, y: -4 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            transition={ease}
            className="absolute inset-x-0 top-[calc(100%+8px)] z-30 min-w-[280px] overflow-hidden rounded-lg border border-border bg-surface p-2 shadow-card"
          >
            <ul id={listId} role="listbox" aria-label={t('search.label')} className="flex max-h-[60vh] flex-col overflow-y-auto">
              {results.map((r, i) => (
                <li key={r.id} role="presentation">
                  {i === 0 || results[i - 1].section !== r.section ? <p className="px-3 pt-2 pb-1 text-caption font-semibold text-text-muted">{t(r.section)}</p> : null}
                  <div
                    id={optionId(i)}
                    role="option"
                    aria-selected={i === active}
                    onMouseDown={(e) => e.preventDefault()}
                    onMouseEnter={() => setActive(i)}
                    onClick={() => go(r)}
                    className={clsx('flex min-h-12 cursor-pointer items-center gap-3 rounded-md px-3 py-2', i === active ? 'bg-primary-soft text-primary' : 'text-text')}
                  >
                    <span className={clsx('grid size-9 shrink-0 place-items-center rounded-pill', i === active ? 'bg-surface' : 'bg-surface-muted')} aria-hidden>
                      <r.icon className="size-4" />
                    </span>
                    <span className="min-w-0 flex-1">
                      <span className="block truncate text-label">{r.title}</span>
                      {r.sub ? (
                        <span className="block truncate text-caption text-text-muted" dir="auto">
                          {r.sub}
                        </span>
                      ) : null}
                    </span>
                  </div>
                </li>
              ))}
            </ul>
            {results.length === 0 ? (
              <p className="px-3 py-4 text-center text-label font-normal text-text-muted" role="status">
                {loading ? t('search.loading') : t('search.none', { q: q.trim() })}
              </p>
            ) : null}
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}
