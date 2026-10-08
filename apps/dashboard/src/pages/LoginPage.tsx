import { Bus, CircleCheck, Languages, Monitor, Moon, Sun } from 'lucide-react';
import { motion } from 'motion/react';
import { useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { useTheme } from '../lib/theme';
import { Button, Input } from '../ui';
import { itemVariants, listVariants, spring } from '../ui/motion';

export function LoginPage() {
  const { session, login } = useAuth();
  const { t, toggle } = useI18n();
  const navigate = useNavigate();
  const from = (useLocation().state as { from?: string } | null)?.from ?? '/';
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const theme = useTheme();
  const ThemeIcon = theme.choice === 'dark' ? Moon : theme.choice === 'light' ? Sun : Monitor;
  const round = 'grid size-12 place-items-center rounded-pill border border-border bg-surface text-text transition-colors hover:bg-surface-muted';

  if (session) return <Navigate to={from} replace />;

  async function submit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(email.trim(), password);
      navigate(from, { replace: true });
    } catch {
      setError(t('login.error'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="grid min-h-full lg:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
      {/* Navy hero (the dashboard rail's colour) with the faded brand word, as in the app artwork. */}
      <section className="relative hidden flex-col justify-between overflow-hidden bg-ink p-12 text-on-ink lg:flex dark:border-e dark:border-border dark:bg-surface dark:text-text">
        <span className="pointer-events-none absolute -bottom-16 -end-8 select-none text-[260px] leading-none font-bold opacity-[0.06]" aria-hidden>
          {t('login.watermark')}
        </span>
        <div className="flex items-center gap-3">
          <span className="grid size-[52px] place-items-center rounded-md bg-accent text-on-accent" aria-hidden>
            <Bus className="size-[26px]" />
          </span>
          <span className="text-headline">{t('appName')}</span>
        </div>
        <motion.div variants={listVariants} initial="hidden" animate="show" className="relative flex max-w-lg flex-col gap-6">
          <motion.span variants={itemVariants} className="h-1.5 w-16 rounded-pill bg-accent" aria-hidden />
          <motion.h2 variants={itemVariants} className="text-[48px] leading-[58px] font-bold text-balance">
            {t('login.tagline')}
          </motion.h2>
          <motion.ul variants={listVariants} className="flex flex-wrap gap-2">
            {(['login.point1', 'login.point2', 'login.point3'] as const).map((k) => (
              <motion.li key={k} variants={itemVariants} className="flex h-11 items-center gap-2 rounded-pill bg-on-ink/10 ps-3 pe-4 text-label dark:bg-surface-muted">
                <CircleCheck className="size-5 shrink-0 text-accent" aria-hidden />
                {t(k)}
              </motion.li>
            ))}
          </motion.ul>
        </motion.div>
        <p className="relative text-caption opacity-80">Warith Al-Anbiyaa University · Karbala</p>
      </section>

      <section className="flex flex-col px-4 py-5 sm:px-8">
        <div className="flex items-center justify-between gap-3">
          <span className="flex items-center gap-3 lg:invisible">
            <span className="grid size-11 place-items-center rounded-md bg-accent text-on-accent" aria-hidden>
              <Bus className="size-[22px]" />
            </span>
            <span className="text-headline">{t('appShort')}</span>
          </span>
          <span className="flex gap-2">
            <motion.button type="button" onClick={theme.cycle} whileTap={{ scale: 0.92 }} aria-label={t(`theme.${theme.choice}`)} title={t(`theme.${theme.choice}`)} className={round}>
              <ThemeIcon className="size-[18px]" aria-hidden />
            </motion.button>
            <motion.button type="button" onClick={toggle} whileTap={{ scale: 0.92 }} className="flex h-12 items-center gap-2 rounded-pill border border-border bg-surface px-5 text-label text-text transition-colors hover:bg-surface-muted">
              <Languages className="size-[18px]" aria-hidden />
              {t('lang.switch')}
            </motion.button>
          </span>
        </div>
        <div className="grid flex-1 place-items-center py-10">
          <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={spring} className="w-full max-w-md">
            <p className="text-label font-normal text-text-muted">{t('login.subtitle')}</p>
            <h1 className="mb-8 text-[30px] leading-[40px] font-semibold">{t('login.title')}</h1>
            <form onSubmit={submit} className="flex flex-col gap-5 rounded-lg border border-border bg-surface p-6 shadow-card sm:p-8 dark:shadow-none" noValidate>
              <Input id="login-email" label={t('login.email')} type="email" autoComplete="username" dir="ltr" value={email} onChange={(e) => setEmail(e.target.value)} required />
              <Input
                id="login-password"
                label={t('login.password')}
                type="password"
                autoComplete="current-password"
                dir="ltr"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                error={error ?? undefined}
                required
              />
              <Button type="submit" loading={busy} className="mt-2 h-14 w-full text-body">
                {t('login.submit')}
              </Button>
            </form>
          </motion.div>
        </div>
      </section>
    </div>
  );
}
