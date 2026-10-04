import { clsx } from 'clsx';
import { NavLink, Outlet } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { Button } from '../ui';
import { NAV } from './nav';

export function Shell() {
  const { session, hasRole, logout } = useAuth();
  const { t, toggle } = useI18n();
  const items = NAV.filter((n) => hasRole(...n.roles));

  return (
    <div className="flex min-h-full">
      <aside className="flex w-64 shrink-0 flex-col gap-2 border-e border-border bg-surface p-5">
        <div className="mb-6 flex items-center gap-3">
          <span className="grid size-10 place-items-center rounded-md bg-primary text-headline text-on-primary" aria-hidden>
            ن
          </span>
          <span className="text-headline">{t('appName')}</span>
        </div>
        <nav aria-label="main" className="flex flex-col gap-1">
          {items.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              end
              className={({ isActive }) =>
                clsx(
                  'flex h-12 items-center rounded-md px-4 text-label transition-colors duration-200',
                  isActive ? 'bg-primary-soft text-primary' : 'text-text-muted hover:bg-surface-muted hover:text-text',
                )
              }
            >
              {t(n.label)}
            </NavLink>
          ))}
        </nav>
        <div className="mt-auto flex flex-col gap-2 border-t border-border pt-4">
          <p className="text-label">{session?.user.name}</p>
          <p className="text-caption text-text-muted">{session ? t(`role.${session.user.role}`) : null}</p>
          <div className="flex gap-2">
            <Button variant="secondary" size="sm" onClick={toggle}>
              {t('lang.switch')}
            </Button>
            <Button variant="ghost" size="sm" onClick={logout}>
              {t('nav.logout')}
            </Button>
          </div>
        </div>
      </aside>
      <main className="flex-1 p-8">
        <Outlet />
      </main>
    </div>
  );
}
