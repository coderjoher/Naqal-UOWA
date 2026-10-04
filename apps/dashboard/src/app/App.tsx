import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MotionConfig } from 'motion/react';
import { useState } from 'react';
import { BrowserRouter, Route, Routes } from 'react-router';
import { AuthProvider } from '../lib/auth';
import { I18nProvider } from '../lib/i18n';
import { LoginPage } from '../pages/LoginPage';
import { DriversPage } from '../pages/DriversPage';
import { OverviewPage } from '../pages/OverviewPage';
import { StudentsPage } from '../pages/StudentsPage';
import { SubscriptionsPage } from '../pages/SubscriptionsPage';
import { PointsPage } from '../pages/settings/PointsPage';
import { RequirementsPage } from '../pages/settings/RequirementsPage';
import { TiersPage } from '../pages/settings/TiersPage';
import { WavesPage } from '../pages/settings/WavesPage';
import { UniversitiesPage } from '../pages/UniversitiesPage';
import { UsersPage } from '../pages/UsersPage';
import { ToastProvider } from '../ui';
import { RedirectOnce, RequireAuth, RequireRole } from './guards';
import { Shell } from './Shell';

const office = (el: React.ReactNode) => <RequireRole roles={['office']}>{el}</RequireRole>;

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <RequireAuth>
            <Shell />
          </RequireAuth>
        }
      >
        <Route index element={<OverviewPage />} />
        <Route
          path="universities"
          element={
            <RequireRole roles={['super_admin']}>
              <UniversitiesPage />
            </RequireRole>
          }
        />
        <Route path="subscriptions" element={office(<SubscriptionsPage />)} />
        <Route path="drivers" element={office(<DriversPage />)} />
        <Route path="students" element={office(<StudentsPage />)} />
        <Route path="users" element={office(<UsersPage />)} />
        <Route path="settings/tiers" element={office(<TiersPage />)} />
        <Route path="settings/points" element={office(<PointsPage />)} />
        <Route path="settings/waves" element={office(<WavesPage />)} />
        <Route path="settings/requirements" element={office(<RequirementsPage />)} />
      </Route>
      <Route path="*" element={<RedirectOnce to="/" />} />
    </Routes>
  );
}

export function App() {
  const [client] = useState(() => new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 30_000 } } }));
  return (
    <QueryClientProvider client={client}>
      <MotionConfig reducedMotion="user">
        <I18nProvider>
          <ToastProvider>
            <AuthProvider>
              <BrowserRouter>
                <AppRoutes />
              </BrowserRouter>
            </AuthProvider>
          </ToastProvider>
        </I18nProvider>
      </MotionConfig>
    </QueryClientProvider>
  );
}
