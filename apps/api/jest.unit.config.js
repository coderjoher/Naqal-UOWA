/** Unit tests: no database, no network. */
module.exports = {
  rootDir: '.',
  testMatch: ['<rootDir>/src/**/*.spec.ts'],
  transform: { '^.+\\.ts$': ['ts-jest', { tsconfig: 'tsconfig.spec.json' }] },
  testEnvironment: 'node',
  collectCoverageFrom: ['src/**/*.ts', '!src/main.ts', '!src/**/*.module.ts', '!src/**/*.dto.ts'],
  coverageThreshold: {
    './src/auth/': { lines: 80 },
    './src/tenancy/': { lines: 80 },
  },
};
