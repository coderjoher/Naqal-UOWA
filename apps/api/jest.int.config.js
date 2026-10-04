/** Integration + e2e tests: real PostgreSQL and Redis (see .env.test). */
module.exports = {
  rootDir: '.',
  testMatch: ['<rootDir>/test/**/*.int-spec.ts', '<rootDir>/test/**/*.e2e-spec.ts'],
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.spec.json' }] },
  testEnvironment: 'node',
  setupFiles: ['<rootDir>/test/setup-env.ts'],
  globalSetup: '<rootDir>/test/global-setup.ts',
  testTimeout: 30000,
};
