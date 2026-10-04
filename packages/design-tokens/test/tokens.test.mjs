import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { render, OUTPUTS } from '../generate.mjs';

test('[T0-02] committed CSS and Dart token files match generator output (no drift)', () => {
  const out = render();
  assert.equal(readFileSync(OUTPUTS.css, 'utf8'), out.css, 'tokens.theme.css is stale — run pnpm tokens');
  assert.equal(readFileSync(OUTPUTS.dart, 'utf8'), out.dart, 'tokens.g.dart is stale — run pnpm tokens');
});

test('[T0-02] every colour token appears in both platforms', () => {
  const tokens = JSON.parse(readFileSync(new URL('../tokens.json', import.meta.url), 'utf8'));
  const { css, dart } = render();
  for (const [name, hex] of Object.entries(tokens.color)) {
    assert.match(css, new RegExp(`--color-${name}: ${hex};`));
    assert.match(dart, new RegExp(`0xFF${hex.slice(1).toUpperCase()}`));
  }
});

test('[T0-02] no gradients anywhere in the token set', () => {
  const raw = readFileSync(new URL('../tokens.json', import.meta.url), 'utf8');
  assert.doesNotMatch(raw, /gradient/i);
});
