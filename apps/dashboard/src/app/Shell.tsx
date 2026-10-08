import { clsx } from 'clsx';
import { Bus, Languages, LogOut, Monitor, Moon, Sun } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { NavLink, useLocation, useOutlet } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { useCurrentUniversity } from '../lib/queries';
import { useTheme } from '../lib/theme';
import { pageVariants, spring } from '../ui/motion';
import { NAV } from './nav';

export function Shell() {
  const { session, hasRole, logout } = useAuth();
  const { t, toggle, rtl, lang } = useI18n();
  const location = useLocation();
  const outlet = useOutlet();
  const isOffice = session?.user.role === 'office';
  const uni = useCurrentUniversity(isOffice);
  const uniName = uni.data ? (lang === 'ar' && uni.data.nameAr) || uni.data.name : null;
  const initials = (session?.user.name ?? '?').trim().slice(0, 1);
  const theme = useTheme();
  const ThemeIcon = theme.choice === 'dark' ? Moon : theme.choice === 'light' ? Sun : Monitor;

  return (
    <div className="flex min-h-full">
      <aside className="sticky top-0 flex h-screen w-72 shrink-0 flex-col gap-6 border-e border-border bg-surface px-4 py-6">
        <div className="flex items-center gap-3 px-2">
          <motion.span
            className="grid size-11 place-items-center rounded-md bg-accent text-on-accent"
            initial={{ rotate: -8, scale: 0.8, opacity: 0 }}
            animate={{ rotate: 0, scale: 1, opacity: 1 }}
            transition={spring}
            aria-hidden
          >
            <Bus className="size-6" />
          </motion.span>
          <div className="min-w-0">
            <p className="truncate text-headline">{t('appShort')}</p>
            <p className="truncate text-caption text-text-muted">{uniName ?? t(`role.${session?.user.role ?? 'office'}`)}</p>
          </div>
        </div>

        <nav aria-label="main" className="flex flex-1 flex-col gap-5 overflow-y-auto">
          {NAV.map((group) => {
            const items = group.items.filter((n) => hasRole(...n.roles));
            if (items.length === 0) return null;
            return (
              <div key={group.label} className="flex flex-col gap-1">
                <p className="px-3 pb-1 text-caption font-medium uppercase tracking-wide text-text-muted">{t(group.label)}</p>
                {items.map((n) => (
                  <NavLink key={n.to} to={n.to} end={n.to === '/'} className="relative block rounded-md">
                    {({ isActive }) => (
                      <>
                        {isActive ? (
                          <motion.span layoutId="nav-active" className="absolute inset-0 rounded-md bg-primary-soft" transition={spring}>
                            <span className="absolute inset-y-2 start-0 w-1 rounded-pill bg-accent" aria-hidden />
                          </motion.span>
                        ) : null}
                        <span
                          className={clsx(
                            'relative flex h-11 items-center gap-3 rounded-md px-3 text-label transition-colors duration-200',
                            isActive ? 'text-primary' : 'text-text-muted hover:bg-surface-muted hover:text-text',
                          )}
                        >
                          <n.icon className="size-5" aria-hidden />
                          {t(n.label)}
                        </span>
                      </>
                    )}
                  </NavLink>
                ))}
              </div>
            );
          })}
        </nav>

        <div className="flex items-center gap-3 rounded-md bg-surface-muted p-3">
          <span className="grid size-10 shrink-0 place-items-center rounded-pill bg-primary-soft text-headline text-primary" aria-hidden>
            {initials}
          </span>
          <div className="min-w-0 flex-1">
            <p className="truncate text-label">{session?.user.name}</p>
            <p className="truncate text-caption text-text-muted">{session ? t(`role.${session.user.role}`) : null}</p>
          </div>
          <motion.button
            type="button"
            onClick={logout}
            aria-label={t('nav.logout')}
            title={t('nav.logout')}
            whileHover={{ scale: 1.08 }}
            whileTap={{ scale: 0.9 }}
            className="grid size-9 place-items-center rounded-pill text-text-muted hover:bg-surface hover:text-danger"
          >
            <LogOut className="size-4 rtl:-scale-x-100" aria-hidden />
          </motion.button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-10 flex h-16 items-center justify-end gap-3 border-b border-border bg-bg/90 px-8 backdrop-blur-sm">
          <motion.button
            type="button"
            onClick={theme.cycle}
            whileHover={{ y: -1 }}
            whileTap={{ scale: 0.95 }}
            aria-label={t(`theme.${theme.choice}`)}
            title={t(`theme.${theme.choice}`)}
            className="grid size-10 place-items-center rounded-pill border border-border bg-surface text-text hover:bg-surface-muted"
          >
            <ThemeIcon className="size-4" aria-hidden />
          </motion.button>
          <motion.button
            type="button"
            onClick={toggle}
            whileHover={{ y: -1 }}
            whileTap={{ scale: 0.95 }}
            className="flex h-10 items-center gap-2 rounded-pill border border-border bg-surface px-4 text-label text-text hover:bg-surface-muted"
          >
            <Languages className="size-4" aria-hidden />
            {t('lang.switch')}
          </motion.button>
        </header>
        <main className="flex-1 px-8 py-8">
          <AnimatePresence mode="wait" initial={false} custom={rtl}>
            <motion.div key={location.pathname} custom={rtl} variants={pageVariants} initial="initial" animate="enter" exit="exit" className="mx-auto w-full max-w-6xl">
              {outlet}
            </motion.div>
          </AnimatePresence>
        </main>
      </div>
    </div>
  );
}
