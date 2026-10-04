import { useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { Button, Card, Input } from '../ui';

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
    <div className="grid min-h-full place-items-center p-5">
      <Card className="w-full max-w-md">
        <div className="mb-8 flex items-start justify-between">
          <div>
            <h1 className="text-title">{t('login.title')}</h1>
            <p className="mt-1 text-text-muted">{t('login.subtitle')}</p>
          </div>
          <Button variant="ghost" size="sm" onClick={toggle}>
            {t('lang.switch')}
          </Button>
        </div>
        <form onSubmit={submit} className="flex flex-col gap-5" noValidate>
          <Input label={t('login.email')} type="email" autoComplete="username" dir="ltr" value={email} onChange={(e) => setEmail(e.target.value)} required />
          <Input
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
      </Card>
    </div>
  );
}
