import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router';
import { AuthProvider } from '../lib/auth';
import { I18nProvider } from '../lib/i18n';
import { LoginPage } from '../pages/LoginPage';
import { OverviewPage } from '../pages/OverviewPage';
import { UniversitiesPage } from '../pages/UniversitiesPage';
import { UsersPage } from '../pages/UsersPage';
import { RequireAuth, RequireRole } from './guards';
import { Shell } from './Shell';

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
        <Route
          path="users"
          element={
            <RequireRole roles={['office']}>
              <UsersPage />
            </RequireRole>
          }
        />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}

export function App() {
  const [client] = useState(() => new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 30_000 } } }));
  return (
    <QueryClientProvider client={client}>
      <I18nProvider>
        <AuthProvider>
          <BrowserRouter>
            <AppRoutes />
          </BrowserRouter>
        </AuthProvider>
      </I18nProvider>
    </QueryClientProvider>
  );
}
