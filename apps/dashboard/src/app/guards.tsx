import type { ReactNode } from 'react';
import { Navigate, useLocation } from 'react-router';
import type { Role } from '../lib/api';
import { useAuth } from '../lib/auth';

export function RequireAuth({ children }: { children: ReactNode }) {
  const { session } = useAuth();
  const location = useLocation();
  if (!session) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  return <>{children}</>;
}

/** Users without the role are sent home rather than shown a broken page. */
export function RequireRole({ roles, children }: { roles: Role[]; children: ReactNode }) {
  const { hasRole } = useAuth();
  if (!hasRole(...roles)) return <Navigate to="/" replace />;
  return <>{children}</>;
}
