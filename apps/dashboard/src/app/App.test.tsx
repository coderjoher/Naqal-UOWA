import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { saveSession, type Role } from '../lib/api';
import { AuthProvider } from '../lib/auth';
import { I18nProvider, messages } from '../lib/i18n';
import { AppRoutes } from './App';

function renderAt(path: string) {
  return render(
    <QueryClientProvider client={new QueryClient({ defaultOptions: { queries: { retry: false } } })}>
      <I18nProvider>
        <AuthProvider>
          <MemoryRouter initialEntries={[path]}>
            <AppRoutes />
          </MemoryRouter>
        </AuthProvider>
      </I18nProvider>
    </QueryClientProvider>,
  );
}

const asRole = (role: Role) => saveSession({ accessToken: 't', user: { id: 'u', name: 'تجربة', role, universityId: role === 'super_admin' ? null : 'uni' } });

describe('app routing', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('defaults to Arabic RTL', () => {
    renderAt('/login');
    expect(document.documentElement.dir).toBe('rtl');
    expect(screen.getByRole('heading', { name: 'تسجيل الدخول' })).toBeInTheDocument();
  });

  it('redirects unauthenticated users to login', () => {
    renderAt('/users');
    expect(screen.getByRole('button', { name: 'دخول' })).toBeInTheDocument();
  });

  it('office users do not see the universities menu and cannot open it', () => {
    asRole('office');
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('[]', { status: 200 })));
    renderAt('/universities');
    expect(screen.queryByRole('link', { name: 'الجامعات' })).not.toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'المستخدمون' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 1 })).toHaveTextContent('أهلاً');
  });

  it('shows a login error for wrong credentials', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 401 })));
    renderAt('/login');
    await userEvent.type(screen.getByLabelText('البريد الإلكتروني'), 'x@y.iq');
    await userEvent.type(screen.getByLabelText('كلمة المرور'), 'wrongpass');
    await userEvent.click(screen.getByRole('button', { name: 'دخول' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('غير صحيحة');
  });

  it('every Arabic message has an English translation and vice versa', () => {
    expect(Object.keys(messages.en).sort()).toEqual(Object.keys(messages.ar).sort());
    for (const v of Object.values(messages.en)) expect(v.trim()).not.toBe('');
  });
});
