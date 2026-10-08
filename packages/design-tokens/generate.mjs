// Generates platform token files from tokens.json (the single source of truth).
//   node generate.mjs          write outputs
//   node generate.mjs --check  exit 1 if committed outputs differ from what would be generated
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '../..');
export const OUTPUTS = {
  css: join(here, 'build/tokens.theme.css'),
  dart: join(repo, 'packages/naql_ui/lib/src/foundation/tokens.g.dart'),
};

const HEADER = 'GENERATED from packages/design-tokens/tokens.json — do not edit by hand.';
const camel = (s) => s.replace(/-([a-z])/g, (_, c) => c.toUpperCase());

/**
 * Tailwind v4 theme. `--color-*: initial` removes Tailwind's default palette, so only token
 * colours exist in the dashboard (no stray `bg-blue-500`, no gradients).
 */
export function renderCss(t) {
  const L = [`/* ${HEADER} */`, '@theme {', '  --color-*: initial;', '  --color-transparent: transparent;', '  --color-current: currentColor;'];
  for (const [k, v] of Object.entries(t.color)) L.push(`  --color-${k}: ${v};`);
  L.push('  --radius-*: initial;');
  for (const [k, v] of Object.entries(t.radius)) L.push(`  --radius-${k}: ${v}px;`);
  L.push(`  --spacing: ${t.space['1']}px;`);
  L.push(`  --font-sans: '${t.font.family}', system-ui, sans-serif;`);
  L.push('  --text-*: initial;');
  for (const [k, v] of Object.entries(t.font)) {
    if (k === 'family') continue;
    L.push(`  --text-${k}: ${v.size}px;`, `  --text-${k}--line-height: ${v.line}px;`, `  --text-${k}--font-weight: ${v.weight};`);
  }
  const s = t.shadow.card;
  const hex = s.color.replace('#', '');
  const rgb = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(', ');
  L.push('  --shadow-*: initial;', `  --shadow-card: ${s.x}px ${s.y}px ${s.blur}px rgba(${rgb}, ${s.opacity});`);
  L.push('}', '');
  // Dark palette: follows the device unless the page pins a theme with <html data-theme="light|dark">.
  const dark = Object.entries(t['color-dark']).map(([k, v]) => `    --color-${k}: ${v};`);
  L.push('@media (prefers-color-scheme: dark) {', '  :root:not([data-theme="light"]) {', '    color-scheme: dark;', ...dark, '  }', '}');
  L.push(':root[data-theme="dark"] {', '  color-scheme: dark;', ...dark.map((l) => l.slice(2)), '}', '');
  L.push(':root {');
  for (const [k, v] of Object.entries(t.motion)) L.push(`  --motion-${k}: ${v}ms;`);
  for (const [k, v] of Object.entries(t.touch)) L.push(`  --touch-${k}: ${v}px;`);
  L.push('}', '');
  return L.join('\n');
}

export function renderDart(t) {
  const argb = (hex) => `Color(0xFF${hex.replace('#', '').toUpperCase()})`;
  const L = [`// ${HEADER}`, '// ignore_for_file: constant_identifier_names', '', "import 'dart:ui';", ''];
  const keys = Object.keys(t.color);
  L.push('/// One full set of colours. [light] and [dark] follow the device setting.');
  L.push('final class NaqlPalette {');
  L.push(`  const NaqlPalette({${keys.map((k) => `required this.${camel(k)}`).join(', ')}});`);
  for (const k of keys) L.push(`  final Color ${camel(k)};`);
  for (const mode of ['light', 'dark']) {
    const src = mode === 'light' ? t.color : t['color-dark'];
    L.push(`  static const ${mode} = NaqlPalette(${keys.map((k) => `${camel(k)}: ${argb(src[k])}`).join(', ')});`);
  }
  L.push('}', '');
  L.push('/// The active palette. NaqlTheme switches [current] with the platform brightness.');
  L.push('abstract final class NaqlColors {');
  L.push('  static NaqlPalette current = NaqlPalette.light;');
  for (const k of keys) L.push(`  static Color get ${camel(k)} => current.${camel(k)};`);
  L.push('}', '', 'abstract final class NaqlSpace {');
  for (const [k, v] of Object.entries(t.space)) L.push(`  static const double s${k} = ${v};`);
  L.push('}', '', 'abstract final class NaqlRadius {');
  for (const [k, v] of Object.entries(t.radius)) L.push(`  static const double ${k} = ${v};`);
  L.push('}', '', 'abstract final class NaqlFontSpec {');
  L.push(`  static const family = '${t.font.family}';`);
  for (const [k, v] of Object.entries(t.font)) {
    if (k === 'family') continue;
    L.push(`  static const ${k} = (size: ${v.size}.0, line: ${v.line}.0, weight: ${v.weight});`);
  }
  const s = t.shadow.card;
  L.push('}', '', 'abstract final class NaqlShadowSpec {');
  L.push(`  static const card = (x: ${s.x}.0, y: ${s.y}.0, blur: ${s.blur}.0, color: ${argb(s.color)}, opacity: ${s.opacity});`);
  L.push('}', '', 'abstract final class NaqlMotion {');
  for (const [k, v] of Object.entries(t.motion)) L.push(`  static const ${k} = Duration(milliseconds: ${v});`);
  L.push('}', '', 'abstract final class NaqlTouch {');
  for (const [k, v] of Object.entries(t.touch)) L.push(`  static const double ${k} = ${v};`);
  L.push('}', '');
  return L.join('\n');
}

export function render() {
  const t = JSON.parse(readFileSync(join(here, 'tokens.json'), 'utf8'));
  return { css: renderCss(t), dart: renderDart(t) };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const out = render();
  if (process.argv.includes('--check')) {
    const stale = Object.keys(OUTPUTS).filter((k) => {
      try { return readFileSync(OUTPUTS[k], 'utf8') !== out[k]; } catch { return true; }
    });
    if (stale.length) {
      console.error(`Token outputs out of date: ${stale.join(', ')}. Run: pnpm tokens`);
      process.exit(1);
    }
    console.log('Token outputs up to date.');
  } else {
    for (const k of Object.keys(OUTPUTS)) {
      mkdirSync(dirname(OUTPUTS[k]), { recursive: true });
      writeFileSync(OUTPUTS[k], out[k]);
    }
    console.log('Generated', Object.values(OUTPUTS).join(', '));
  }
}
