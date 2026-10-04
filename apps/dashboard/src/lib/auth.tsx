import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { api, loadSession, saveSession, type Role, type Session } from './api';

interface Auth {
  session: Session | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
  hasRole: (...roles: Role[]) => boolean;
}

const Ctx = createContext<Auth | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(loadSession);

  useEffect(() => {
    const onLogout = () => setSession(null);
    window.addEventListener('naql:logout', onLogout);
    return () => window.removeEventListener('naql:logout', onLogout);
  }, []);

  const login = useCallback(async (email: string, password: string) => {
    const s = await api<Session>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) });
    if (s.user.role !== 'office' && s.user.role !== 'super_admin') throw new Error('not a dashboard role');
    saveSession(s);
    setSession(s);
  }, []);

  const logout = useCallback(() => {
    saveSession(null);
    setSession(null);
  }, []);

  const hasRole = useCallback((...roles: Role[]) => !!session && roles.includes(session.user.role), [session]);

  return <Ctx.Provider value={{ session, login, logout, hasRole }}>{children}</Ctx.Provider>;
}

export function useAuth() {
  const v = useContext(Ctx);
  if (!v) throw new Error('useAuth outside AuthProvider');
  return v;
}
