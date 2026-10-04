import { useEffect, useRef, type ReactNode } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router';
import type { Role } from '../lib/api';
import { useAuth } from '../lib/auth';

export function RequireAuth({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const location = useLocation();
  if (!session) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  return <>{children}</>;
}

/**
 * Redirects exactly once. Pages stay mounted for a moment while their exit animation runs; a
 * plain <Navigate> would fire again on every navigation in that window and pull the user back.
 */
export function RedirectOnce({ to }: { to: string }) {
  const navigate = useNavigate();
  const done = useRef(false);
  useEffect(() => {
    if (done.current) return;
    done.current = true;
    navigate(to, { replace: true });
  }, [navigate, to]);
  return null;
}

/** Users without the role are sent home rather than shown a broken page. */
export function RequireRole({ roles, children }: { roles: Role[]; children: ReactNode }) {
  const { hasRole } = useAuth();
  if (!hasRole(...roles)) return <RedirectOnce to="/" />;
  return <>{children}</>;
}
