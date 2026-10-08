import { clsx } from 'clsx';
import { Bus, Languages, LogOut, Menu, Monitor, Moon, Sun } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useEffect, useId, useLayoutEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { NavLink, useLocation, useOutlet } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { useCurrentUniversity } from '../lib/queries';
import { useTheme } from '../lib/theme';
import { Drawer, PageChromeContext } from '../ui';
import { ease, pageVariants, spring } from '../ui/motion';
import { visibleNav, type NavGroup, type NavItem } from './nav';
import { GlobalSearch } from './Search';

const isActive = (pathname: string, to: string) => (to === '/' ? pathname === '/' : pathname === to || pathname.startsWith(`${to}/`));

/* Rail colours: deep navy in light mode; in dark mode (where `ink` turns light) the raised surface. */
const RAIL_ITEM = 'text-on-ink/75 hover:bg-on-ink/10 hover:text-on-ink dark:text-text-muted dark:hover:bg-surface-muted dark:hover:text-text';
const RAIL_ACTIVE = 'bg-accent/15 text-accent dark:bg-accent/15 dark:text-accent';
const RAIL_FOCUS = 'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-accent';

function RailButtonBody({ icon, label }: { icon: ReactNode; label: string }) {
  return (
    <>
      {icon}
      <span className="line-clamp-2 max-w-full px-1 text-center text-[11px] leading-[14px] font-semibold">{label}</span>
    </>
  );
}

function RailLink({ item }: { item: NavItem }) {
  const { t } = useI18n();
  return (
    <NavLink
      to={item.to}
      end={item.to === '/'}
      aria-label={t(item.label)}
      title={t(item.label)}
      className={({ isActive: on }) =>
        clsx('relative flex w-[72px] flex-col items-center gap-1 rounded-md py-2.5 transition-colors duration-200', RAIL_FOCUS, on ? RAIL_ACTIVE : RAIL_ITEM)
      }
    >
      <RailButtonBody icon={<item.icon className="size-[22px]" aria-hidden />} label={t(item.short)} />
    </NavLink>
  );
}

/** Rail button that opens a popover beside the rail (disclosure pattern: links stay links). */
function Flyout({
  label,
  icon,
  active,
  open,
  onOpenChange,
  bottom,
  children,
}: {
  label: string;
  icon: ReactNode;
  active: boolean;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  bottom?: boolean;
  children: ReactNode;
}) {
  const panelId = useId();
  const btn = useRef<HTMLButtonElement>(null);
  const panel = useRef<HTMLDivElement>(null);
  const [pos, setPos] = useState<{ top?: number; bottom?: number }>({});

  useLayoutEffect(() => {
    if (!open || !btn.current) return;
    const r = btn.current.getBoundingClientRect();
    const h = panel.current?.offsetHeight ?? 0;
    const vh = window.innerHeight;
    if (bottom || r.top + h > vh - 12) setPos({ bottom: Math.max(12, vh - r.bottom) });
    else setPos({ top: Math.max(12, r.top) });
  }, [open, bottom]);

  useEffect(() => {
    if (!open) return;
    panel.current?.querySelector<HTMLElement>('a,button')?.focus({ preventScroll: true });
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onOpenChange(false);
        btn.current?.focus();
      }
    };
    const onDown = (e: PointerEvent) => {
      const el = e.target as Node;
      if (!panel.current?.contains(el) && !btn.current?.contains(el)) onOpenChange(false);
    };
    window.addEventListener('keydown', onKey);
    document.addEventListener('pointerdown', onDown);
    return () => {
      window.removeEventListener('keydown', onKey);
      document.removeEventListener('pointerdown', onDown);
    };
  }, [open, onOpenChange]);

  return (
    <div
      onBlur={(e) => {
        const next = e.relatedTarget as Node | null;
        if (open && next && !e.currentTarget.contains(next)) onOpenChange(false);
      }}
    >
      <button
        ref={btn}
        type="button"
        aria-expanded={open}
        aria-controls={panelId}
        onClick={() => onOpenChange(!open)}
        className={clsx('relative flex w-[72px] flex-col items-center gap-1 rounded-md py-2.5 transition-colors duration-200', RAIL_FOCUS, active || open ? RAIL_ACTIVE : RAIL_ITEM)}
      >
        <RailButtonBody icon={icon} label={label} />
      </button>
      <AnimatePresence>
        {open ? (
          <motion.div
            ref={panel}
            id={panelId}
            role="group"
            aria-label={label}
            initial={{ opacity: 0, scale: 0.97 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.97 }}
            transition={ease}
            style={pos}
            className="fixed start-[104px] z-40 w-64 rounded-lg border border-border bg-surface p-2 text-text shadow-card"
          >
            <p className="px-3 pt-2 pb-2 text-caption font-semibold text-text-muted">{label}</p>
            {children}
          </motion.div>
        ) : null}
      </AnimatePresence>
    </div>
  );
}

/** A full-width page link inside a flyout or the mobile menu. */
function MenuLink({ item, onPick }: { item: NavItem; onPick?: () => void }) {
  const { t } = useI18n();
  return (
    <NavLink
      to={item.to}
      end={item.to === '/'}
      onClick={onPick}
      className={({ isActive: on }) =>
        clsx('flex min-h-12 items-center gap-3 rounded-md px-3 text-label transition-colors duration-200', on ? 'bg-primary-soft text-primary' : 'text-text hover:bg-surface-muted')
      }
    >
      <span className="grid size-9 shrink-0 place-items-center rounded-pill bg-surface-muted text-text-muted" aria-hidden>
        <item.icon className="size-4" />
      </span>
      {t(item.label)}
    </NavLink>
  );
}

function useAccount() {
  const { session } = useAuth();
  const { t, lang } = useI18n();
  const isOffice = session?.user.role === 'office';
  const uni = useCurrentUniversity(isOffice);
  const uniName = uni.data ? (lang === 'ar' && uni.data.nameAr) || uni.data.name : null;
  return {
    name: session?.user.name ?? '',
    initial: (session?.user.name ?? '?').trim().slice(0, 1),
    sub: uniName ?? t(`role.${session?.user.role ?? 'office'}`),
  };
}

function AccountCard() {
  const { logout } = useAuth();
  const { t } = useI18n();
  const acc = useAccount();
  return (
    <div className="flex items-center gap-3 rounded-md bg-surface-muted p-3">
      <span className="grid size-10 shrink-0 place-items-center rounded-pill bg-primary-soft text-headline text-primary" aria-hidden>
        {acc.initial}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-label">{acc.name}</p>
        <p className="truncate text-caption text-text-muted">{acc.sub}</p>
      </div>
      <button
        type="button"
        onClick={logout}
        aria-label={t('nav.logout')}
        title={t('nav.logout')}
        className="grid size-10 shrink-0 place-items-center rounded-pill border border-border bg-surface text-text-muted transition-colors hover:text-danger"
      >
        <LogOut className="size-4 rtl:-scale-x-100" aria-hidden />
      </button>
    </div>
  );
}

/** Desktop and tablet: the 96 px navy icon rail. */
function Rail({ groups }: { groups: NavGroup[] }) {
  const { t } = useI18n();
  const { pathname } = useLocation();
  const acc = useAccount();
  const [openKey, setOpenKey] = useState<string | null>(null);
  useEffect(() => setOpenKey(null), [pathname]);

  const render = (g: NavGroup) => {
    if (g.display === 'rail' || g.items.length === 1) return g.items.map((n) => <RailLink key={n.to} item={n} />);
    return (
      <Flyout
        key={g.label}
        label={t(g.label)}
        icon={g.icon ? <g.icon className="size-[22px]" aria-hidden /> : null}
        bottom={g.bottom}
        active={g.items.some((n) => isActive(pathname, n.to))}
        open={openKey === g.label}
        onOpenChange={(o) => setOpenKey(o ? g.label : null)}
      >
        <div className="flex flex-col gap-0.5">
          {g.items.map((n) => (
            <MenuLink key={n.to} item={n} onPick={() => setOpenKey(null)} />
          ))}
        </div>
      </Flyout>
    );
  };

  return (
    <aside className="sticky top-0 z-30 hidden h-screen w-24 shrink-0 flex-col items-center bg-ink py-5 text-on-ink md:flex dark:border-e dark:border-border dark:bg-surface dark:text-text">
      <motion.span
        className="mb-4 grid size-[52px] shrink-0 place-items-center rounded-md bg-accent text-on-accent"
        initial={{ rotate: -8, scale: 0.8, opacity: 0 }}
        animate={{ rotate: 0, scale: 1, opacity: 1 }}
        transition={spring}
        title={t('appName')}
      >
        <Bus className="size-[26px]" strokeWidth={2.2} aria-hidden />
        <span className="sr-only">{t('appName')}</span>
      </motion.span>
      <nav aria-label="main" className="flex min-h-0 w-full flex-1 flex-col items-center">
        <div className="flex min-h-0 w-full flex-1 flex-col items-center gap-1 overflow-y-auto py-1 [scrollbar-width:none]">{groups.filter((g) => !g.bottom).map(render)}</div>
        <div className="flex w-full flex-col items-center gap-1 pt-2">
          {groups.filter((g) => g.bottom).map(render)}
          <Flyout label={t('nav.account')} icon={
              <span className="grid size-[26px] place-items-center rounded-pill bg-on-ink/15 text-[12px] leading-none font-bold dark:bg-surface-muted" aria-hidden>
                {acc.initial}
              </span>
            } bottom active={false} open={openKey === 'account'} onOpenChange={(o) => setOpenKey(o ? 'account' : null)}>
            <AccountCard />
          </Flyout>
        </div>
      </nav>
    </aside>
  );
}

/** Phones: a bottom bar with the four main pages and "More" (every page, account, sign out). */
function BottomBar({ groups }: { groups: NavGroup[] }) {
  const { t } = useI18n();
  const { pathname } = useLocation();
  const [open, setOpen] = useState(false);
  useEffect(() => setOpen(false), [pathname]);
  const direct = groups.flatMap((g) => (g.display === 'rail' || g.items.length === 1 ? g.items : [])).slice(0, 4);
  const moreActive = !direct.some((n) => isActive(pathname, n.to));
  const item = 'flex min-w-0 flex-1 flex-col items-center gap-1 rounded-md py-2 text-[11px] leading-[14px] font-semibold transition-colors';
  const tone = (on: boolean) => (on ? 'text-accent' : 'text-on-ink/75 dark:text-text-muted');
  return (
    <>
      <nav aria-label="main" className="fixed inset-x-0 bottom-0 z-30 border-t border-on-ink/10 bg-ink px-2 pt-1.5 pb-[max(8px,env(safe-area-inset-bottom))] md:hidden dark:border-border dark:bg-surface">
        <div className="mx-auto flex max-w-lg items-stretch gap-1">
          {direct.map((n) => (
            <NavLink key={n.to} to={n.to} end={n.to === '/'} aria-label={t(n.label)} className={({ isActive: on }) => clsx(item, RAIL_FOCUS, tone(on))}>
              {({ isActive: on }) => (
                <>
                  <span className={clsx('grid h-8 w-14 place-items-center rounded-pill transition-colors', on && 'bg-accent/15')}>
                    <n.icon className="size-5" aria-hidden />
                  </span>
                  <span className="max-w-full truncate">{t(n.short)}</span>
                </>
              )}
            </NavLink>
          ))}
          <button type="button" aria-expanded={open} onClick={() => setOpen(true)} className={clsx(item, RAIL_FOCUS, tone(moreActive))}>
            <span className={clsx('grid h-8 w-14 place-items-center rounded-pill', moreActive && 'bg-accent/15')}>
              <Menu className="size-5" aria-hidden />
            </span>
            <span>{t('nav.more')}</span>
          </button>
        </div>
      </nav>
      <Drawer open={open} title={t('nav.menu')} onClose={() => setOpen(false)}>
        <div className="flex flex-col gap-5">
          <AccountCard />
          {groups.map((g) => (
            <section key={g.label} className="flex flex-col gap-0.5">
              <h3 className="px-3 pb-1 text-caption font-semibold text-text-muted">{t(g.label)}</h3>
              {g.items.map((n) => (
                <MenuLink key={n.to} item={n} onPick={() => setOpen(false)} />
              ))}
            </section>
          ))}
        </div>
      </Drawer>
    </>
  );
}

/** Theme and language: round buttons in every page header. */
function RoundToggles() {
  const { t, toggle } = useI18n();
  const theme = useTheme();
  const ThemeIcon = theme.choice === 'dark' ? Moon : theme.choice === 'light' ? Sun : Monitor;
  const round = 'grid size-12 shrink-0 place-items-center rounded-pill border border-border bg-surface text-text transition-colors duration-200 hover:bg-surface-muted';
  return (
    <>
      <motion.button type="button" onClick={theme.cycle} whileTap={{ scale: 0.92 }} aria-label={t(`theme.${theme.choice}`)} title={t(`theme.${theme.choice}`)} className={round}>
        <ThemeIcon className="size-[18px]" aria-hidden />
      </motion.button>
      <motion.button type="button" onClick={toggle} whileTap={{ scale: 0.92 }} aria-label={t('lang.switch')} title={t('lang.switch')} className={round}>
        <Languages className="size-[18px]" aria-hidden />
      </motion.button>
    </>
  );
}

export function Shell() {
  const { hasRole } = useAuth();
  const { t, rtl, lang } = useI18n();
  const location = useLocation();
  const outlet = useOutlet();
  const groups = useMemo(() => visibleNav(hasRole), [hasRole]);
  const dateLine = useMemo(
    () => new Intl.DateTimeFormat(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Asia/Baghdad' }).format(new Date()),
    [lang],
  );
  const chrome = useMemo(
    () => ({
      dateLine,
      tools: (
        <>
          <GlobalSearch />
          <RoundToggles />
        </>
      ),
    }),
    [dateLine],
  );

  return (
    <div className="flex min-h-full">
      <a href="#content" className="sr-only z-50 rounded-pill bg-primary px-5 py-3 text-on-primary focus:not-sr-only focus:fixed focus:start-4 focus:top-4">
        {t('nav.skip')}
      </a>
      <Rail groups={groups} />
      <div className="flex min-w-0 flex-1 flex-col overflow-x-clip">
        <main id="content" tabIndex={-1} className="w-full flex-1 px-4 pt-5 pb-28 focus:outline-none md:px-8 md:pt-6 md:pb-10">
          <PageChromeContext.Provider value={chrome}>
            <AnimatePresence mode="wait" initial={false} custom={rtl}>
              <motion.div key={location.pathname} custom={rtl} variants={pageVariants} initial="initial" animate="enter" exit="exit" className="mx-auto w-full max-w-[1400px]">
                {outlet}
              </motion.div>
            </AnimatePresence>
          </PageChromeContext.Provider>
        </main>
      </div>
      <BottomBar groups={groups} />
    </div>
  );
}
