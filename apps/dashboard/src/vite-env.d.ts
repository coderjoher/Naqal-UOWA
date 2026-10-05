/// <reference types="vite/client" />
interface ImportMetaEnv {
  readonly VITE_API_URL?: string;
  /** Sentry project DSN for the dashboard (optional). */
  readonly VITE_SENTRY_DSN?: string;
  readonly VITE_MAP_TILES?: string;
  readonly VITE_MAP_ATTRIBUTION?: string;
}
