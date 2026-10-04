// T0-01: CI covers every app and cannot go green while a suite is red.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const ci = readFileSync(new URL('../../.github/workflows/ci.yml', import.meta.url), 'utf8');

test('[T0-01] CI has a job for every app and package', () => {
  for (const job of ['tokens:', 'api:', 'dashboard:', 'flutter:', 'compose:']) {
    assert.match(ci, new RegExp(`^  ${job}`, 'm'), `missing job ${job}`);
  }
  for (const dir of ['packages/naql_ui', 'packages/naql_core', 'packages/naql_app', 'apps/student_app', 'apps/driver_app']) {
    assert.ok(ci.includes(`working-directory: ${dir}`), `flutter tests not run for ${dir}`);
  }
  for (const cmd of ['pnpm test:cov', 'pnpm test:int', 'pnpm test:e2e', 'pnpm test\n']) {
    assert.ok(ci.includes(cmd), `missing command ${cmd.trim()}`);
  }
});

test('[T0-01] CI runs on pull requests and failures are never swallowed', () => {
  assert.match(ci, /^\s+pull_request:/m);
  assert.doesNotMatch(ci, /continue-on-error:\s*true/);
  assert.doesNotMatch(ci, /\|\|\s*true/);
  assert.doesNotMatch(ci, /--passWithNoTests/);
  assert.doesNotMatch(ci, /set \+e/);
});

test('[T0-01] a failing test produces a non-zero exit code', async () => {
  // The runners CI uses (node --test, jest, vitest, flutter test) all exit non-zero on failure;
  // verify the principle end to end with node's runner on a deliberately red test.
  const { spawnSync } = await import('node:child_process');
  const { mkdtempSync, writeFileSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const { join } = await import('node:path');
  const file = join(mkdtempSync(join(tmpdir(), 'naql-ci-')), 'red.test.mjs');
  writeFileSync(file, "import { test } from 'node:test';\ntest('red', () => { throw new Error('deliberate failure'); });\n");
  // Drop NODE_TEST_CONTEXT so the child behaves like a top-level CI run, not a subtest.
  const { NODE_TEST_CONTEXT: _, ...env } = process.env;
  const r = spawnSync(process.execPath, ['--test', file], { encoding: 'utf8', env });
  assert.notEqual(r.status, 0);
  assert.match(r.stdout, /deliberate failure/);
  assert.match(r.stdout, /# fail 1/);
});
