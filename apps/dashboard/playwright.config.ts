import { defineConfig, devices } from '@playwright/test';

const PORT = 5179;
/**
 * Two projects:
 *  - `mocked`: browser tests with the API mocked at the network layer (fast, no services).
 *  - `full`:   real API + PostgreSQL + Redis + fake OSRM (set E2E_FULL=1; CI provides the services).
 */
const FULL = process.env.E2E_FULL === '1';
const E2E_DB = process.env.E2E_DATABASE_URL ?? 'postgresql://naql:naql@localhost:5432/naql_e2e';
const apiEnv = {
  DATABASE_URL: E2E_DB,
  REDIS_URL: process.env.E2E_REDIS_URL ?? 'redis://localhost:6379/2',
  OSRM_URL: 'http://127.0.0.1:5998',
  JWT_SECRET: 'e2e-secret-e2e-secret-e2e-secret-0123',
  PORT: '3100',
  QUEUE_PREFIX: 'naql-e2e',
  OTP_DEV_ECHO: 'true',
  STORAGE_DIR: '/tmp/naql-e2e-storage',
};

export default defineConfig({
  testDir: 'e2e',
  forbidOnly: !!process.env.CI,
  retries: 0,
  workers: 1,
  reporter: process.env.CI ? 'github' : 'list',
  use: { baseURL: `http://localhost:${PORT}`, trace: 'retain-on-failure', locale: 'ar-IQ' },
  projects: [
    { name: 'mocked', testIgnore: /full\//, use: { ...devices['Desktop Chrome'] } },
    ...(FULL
      ? [
          {
            name: 'full',
            testMatch: /full\/.*\.spec\.ts/,
            use: { ...devices['Desktop Chrome'], launchOptions: { args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] } },
          },
        ]
      : []),
  ],
  webServer: [
    {
      command: `pnpm vite --port ${PORT} --strictPort`,
      port: PORT,
      reuseExistingServer: !process.env.CI,
      env: { VITE_API_PROXY: FULL ? 'http://localhost:3100' : 'http://localhost:3000' },
    },
    ...(FULL
      ? [
          { command: 'npx ts-node test/fake-osrm.ts 5998', cwd: '../api', port: 5998, reuseExistingServer: false },
          {
            command: 'npx prisma migrate deploy && npx ts-node prisma/seed-e2e.ts && node dist/main.js',
            cwd: '../api',
            url: 'http://localhost:3100/health',
            reuseExistingServer: false,
            timeout: 120_000,
            env: apiEnv,
          },
        ]
      : []),
  ],
});
