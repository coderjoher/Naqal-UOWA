#!/usr/bin/env node
// Phase gate checker. Run: node scripts/check-phases.mjs
//
// Rules enforced:
//  1. Every phase file has a Status line and Scope, Tests and Exit gate sections.
//  2. Every phase has at least one test; test IDs are unique and prefixed with the phase (T<n>-xx).
//  3. Every test has a known layer and covers at least one requirement from the catalogue.
//  4. Every requirement in a phase's Scope is covered by at least one test of that phase.
//  5. Every requirement in docs/requirements.md is scoped to exactly one phase.
//  6. Every exit gate has at least one checklist item.
//  7. A phase with "Status: done" must have every exit-gate item checked, and every test ID
//     must appear in a test file under apps/, packages/ or scripts/ (e.g. it('[T4-01] ...')), so
//     the test really exists in code and runs in CI. The summary shows how many test IDs of
//     each phase already exist in code.

import { readFileSync, readdirSync, statSync, existsSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const REQ_FILE = join(root, 'docs/requirements.md');
const PHASE_DIR = join(root, 'docs/phases');
const CODE_DIRS = ['apps', 'packages', 'scripts'].map((d) => join(root, d));
const SELF = new URL(import.meta.url).pathname;
const LAYERS = new Set([
  'unit', 'integration', 'e2e', 'contract', 'widget', 'golden', 'flutter-int',
  'dashboard', 'playwright', 'load', 'security', 'ci',
]);
const STATUSES = new Set(['planned', 'in-progress', 'done']);
const ID_RE = /\b[A-Z]{2}-\d{2}\b/g;

const errors = [];
const fail = (file, msg) => errors.push(`${file}: ${msg}`);

// Requirement catalogue
const catalogue = new Map();
for (const line of readFileSync(REQ_FILE, 'utf8').split('\n')) {
  const m = line.match(/^\|\s*([A-Z]{2}-\d{2})\s*\|\s*(.+?)\s*\|\s*([MSC])\s*\|\s*$/);
  if (m) {
    if (catalogue.has(m[1])) fail('docs/requirements.md', `duplicate requirement ${m[1]}`);
    catalogue.set(m[1], { text: m[2], pri: m[3] });
  }
}
if (catalogue.size === 0) fail('docs/requirements.md', 'no requirements found');

function sections(md) {
  const out = {};
  let current = null;
  for (const line of md.split('\n')) {
    const h = line.match(/^##\s+(.+?)\s*$/);
    if (h) { current = h[1].toLowerCase(); out[current] = []; continue; }
    if (current) out[current].push(line);
  }
  return out;
}

function listCodeFiles(dir, acc = []) {
  if (!existsSync(dir)) return acc;
  for (const name of readdirSync(dir)) {
    if (['node_modules', 'build', 'dist', '.dart_tool', '.git'].includes(name)) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) listCodeFiles(p, acc);
    else if (/\.(ts|tsx|js|mjs|dart)$/.test(name) && p !== SELF) acc.push(p);
  }
  return acc;
}
let codeText = null;
const code = () => (codeText ??= CODE_DIRS.flatMap((d) => listCodeFiles(d))
  .map((f) => readFileSync(f, 'utf8')).join('\n'));

// Phases
const scopedIn = new Map();
const testIds = new Set();
const phaseFiles = readdirSync(PHASE_DIR).filter((f) => /^P\d+-.+\.md$/.test(f)).sort(
  (a, b) => parseInt(a.slice(1)) - parseInt(b.slice(1)),
);
if (phaseFiles.length === 0) fail('docs/phases', 'no phase files found');

const summary = [];
for (const file of phaseFiles) {
  const rel = relative(root, join(PHASE_DIR, file));
  const phaseNo = parseInt(file.slice(1));
  const md = readFileSync(join(PHASE_DIR, file), 'utf8');
  const status = md.match(/^Status:\s*(\S+)/m)?.[1];
  if (!STATUSES.has(status)) fail(rel, `Status must be one of ${[...STATUSES].join(', ')}`);

  const s = sections(md);
  for (const name of ['scope', 'tests', 'exit gate']) {
    if (!s[name]) fail(rel, `missing "## ${name}" section`);
  }

  const scope = new Set();
  for (const line of s.scope ?? []) {
    const m = line.match(/^-\s+([A-Z]{2}-\d{2})\b/);
    if (!m) continue;
    const id = m[1];
    if (!catalogue.has(id)) fail(rel, `scope references unknown requirement ${id}`);
    if (scopedIn.has(id)) fail(rel, `${id} already scoped in ${scopedIn.get(id)}`);
    scopedIn.set(id, rel);
    scope.add(id);
  }
  if (scope.size === 0) fail(rel, 'scope lists no requirements');

  const covered = new Set();
  const tests = [];
  for (const line of s.tests ?? []) {
    const cells = line.split('|').map((c) => c.trim());
    if (cells.length < 6 || !/^T\d+-\d{2}$/.test(cells[1])) continue;
    const [, id, layer, covers, what] = cells;
    tests.push(id);
    if (!id.startsWith(`T${phaseNo}-`)) fail(rel, `test ${id} must be prefixed T${phaseNo}-`);
    if (testIds.has(id)) fail(rel, `duplicate test id ${id}`);
    testIds.add(id);
    if (!LAYERS.has(layer)) fail(rel, `test ${id} has unknown layer "${layer}"`);
    if (!what) fail(rel, `test ${id} has no pass criterion`);
    const ids = covers.match(ID_RE) ?? [];
    if (ids.length === 0) fail(rel, `test ${id} covers no requirement`);
    for (const r of ids) {
      if (!catalogue.has(r)) fail(rel, `test ${id} covers unknown requirement ${r}`);
      covered.add(r);
    }
  }
  if (tests.length === 0) fail(rel, 'phase has no tests');
  for (const id of scope) {
    if (!covered.has(id)) fail(rel, `scope item ${id} is not covered by any test in this phase`);
  }

  const gate = (s['exit gate'] ?? []).filter((l) => /^-\s+\[[ x]\]/.test(l));
  if (gate.length === 0) fail(rel, 'exit gate has no checklist items');

  const inCode = status === 'planned' ? [] : tests.filter((id) => code().includes(`[${id}]`));
  if (status === 'done') {
    const open = gate.filter((l) => /^-\s+\[ \]/.test(l));
    if (open.length) fail(rel, `status is done but ${open.length} exit-gate item(s) unchecked`);
    for (const id of tests) {
      if (!inCode.includes(id)) fail(rel, `status is done but test [${id}] not found in apps/, packages/ or scripts/`);
    }
  }
  const checked = gate.filter((l) => /^-\s+\[x\]/.test(l)).length;
  summary.push({
    phase: file.replace(/\.md$/, ''),
    status,
    requirements: scope.size,
    tests: tests.length,
    'tests in code': status === 'planned' ? '—' : `${inCode.length}/${tests.length}`,
    'exit gate': `${checked}/${gate.length}`,
  });
}

for (const id of catalogue.keys()) {
  if (!scopedIn.has(id)) fail('docs/requirements.md', `${id} is not scoped to any phase`);
}

console.table(summary);
if (errors.length) {
  console.error(`\n✗ ${errors.length} problem(s):\n` + errors.map((e) => `  - ${e}`).join('\n'));
  process.exit(1);
}
console.log(`\n✓ ${catalogue.size} requirements, ${testIds.size} tests, ${phaseFiles.length} phases — all gates consistent.`);
