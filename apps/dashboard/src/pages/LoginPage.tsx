import { Bus, CircleCheck, Languages } from 'lucide-react';
import { motion } from 'motion/react';
import { useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
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
    <div className="grid min-h-full lg:grid-cols-2">
      <section className="hidden flex-col justify-between bg-primary p-12 text-on-primary lg:flex">
        <div className="flex items-center gap-3">
          <span className="grid size-12 place-items-center rounded-md bg-on-primary text-primary" aria-hidden>
            <Bus className="size-6" />
          </span>
          <span className="text-headline">{t('appName')}</span>
        </div>
        <motion.div variants={listVariants} initial="hidden" animate="show" className="flex max-w-md flex-col gap-6">
          <motion.h2 variants={itemVariants} className="text-display text-balance">
            {t('login.tagline')}
          </motion.h2>
          {(['login.point1', 'login.point2', 'login.point3'] as const).map((k) => (
            <motion.p key={k} variants={itemVariants} className="flex items-center gap-3 text-body">
              <CircleCheck className="size-5 shrink-0" aria-hidden />
              {t(k)}
            </motion.p>
          ))}
        </motion.div>
        <p className="text-caption opacity-80">Warith Al-Anbiyaa University · Karbala</p>
      </section>

      <section className="grid place-items-center p-6">
        <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={spring} className="w-full max-w-md rounded-lg bg-surface p-8 shadow-card">
          <div className="mb-8 flex items-start justify-between gap-4">
            <div>
              <h1 className="text-title">{t('login.title')}</h1>
              <p className="mt-1 text-text-muted">{t('login.subtitle')}</p>
            </div>
            <Button variant="ghost" size="sm" icon={Languages} onClick={toggle}>
              {t('lang.switch')}
            </Button>
          </div>
          <form onSubmit={submit} className="flex flex-col gap-5" noValidate>
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
            <Button type="submit" loading={busy} className="mt-2 w-full">
              {t('login.submit')}
            </Button>
          </form>
        </motion.div>
      </section>
    </div>
  );
}
