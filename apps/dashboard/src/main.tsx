import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './app/App';
import './index.css';

// Errors to Sentry when the build sets VITE_SENTRY_DSN (loaded only then, so it costs nothing otherwise).
if (import.meta.env.VITE_SENTRY_DSN) {
  void import('@sentry/react').then((Sentry) =>
    Sentry.init({ dsn: import.meta.env.VITE_SENTRY_DSN, environment: import.meta.env.MODE, sendDefaultPii: false, tracesSampleRate: 0 }),
  );
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
