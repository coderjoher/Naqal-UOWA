// Design rule: colours come only from tokens; no gradients. Fails on hex / rgb() / gradient in src.
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const bad = [];
const walk = (d) => {
  for (const n of readdirSync(d)) {
    const p = join(d, n);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(tsx?|css)$/.test(n) && !/\.test\.tsx?$/.test(n)) {
      readFileSync(p, 'utf8').split('\n').forEach((line, i) => {
        if (/#[0-9a-fA-F]{3,8}\b|rgba?\(|gradient/i.test(line)) bad.push(`${p}:${i + 1}: ${line.trim()}`);
      });
    }
  }
};
walk(new URL('../src', import.meta.url).pathname);
if (bad.length) {
  console.error('Raw colours or gradients found (use design tokens):\n' + bad.join('\n'));
  process.exit(1);
}
console.log('No raw colours or gradients.');
