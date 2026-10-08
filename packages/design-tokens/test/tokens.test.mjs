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
  for (const palette of ['color', 'color-dark']) {
    assert.deepEqual(Object.keys(tokens[palette]), Object.keys(tokens.color), `${palette} has the same names as color`);
    for (const [name, hex] of Object.entries(tokens[palette])) {
      assert.match(css, new RegExp(`--color-${name}: ${hex};`));
      assert.match(dart, new RegExp(`0xFF${hex.slice(1).toUpperCase()}`));
    }
  }
});

const luminance = (hex) => {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((x) => (x <= 0.03928 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const contrast = (a, b) => {
  const [x, y] = [luminance(a), luminance(b)].sort((p, q) => q - p);
  return (x + 0.05) / (y + 0.05);
};

test('[T0-02] text and status colours meet WCAG AA (4.5:1) in light and dark', () => {
  const tokens = JSON.parse(readFileSync(new URL('../tokens.json', import.meta.url), 'utf8'));
  const pairs = [
    ['text', 'bg'], ['text', 'surface'], ['text-muted', 'bg'], ['text-muted', 'surface'], ['text-muted', 'surface-muted'],
    ['on-primary', 'primary'], ['on-accent', 'accent'], ['on-ink', 'ink'], ['primary', 'surface'], ['primary', 'primary-soft'],
    ['success', 'success-soft'], ['warning', 'warning-soft'], ['danger', 'danger-soft'], ['female-only', 'female-only-soft'],
  ];
  for (const palette of ['color', 'color-dark']) {
    for (const [fg, bg] of pairs) {
      const r = contrast(tokens[palette][fg], tokens[palette][bg]);
      assert.ok(r >= 4.5, `${palette}: ${fg} on ${bg} is ${r.toFixed(2)}:1`);
    }
  }
});

test('[T0-02] no gradients anywhere in the token set', () => {
  const raw = readFileSync(new URL('../tokens.json', import.meta.url), 'utf8');
  assert.doesNotMatch(raw, /gradient/i);
});
