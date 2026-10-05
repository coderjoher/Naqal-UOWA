// T9-05: map tiles come from one configurable setting, and the dashboard CSP allows exactly that host.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const root = new URL('../../', import.meta.url).pathname;
const read = (p) => readFileSync(join(root, p), 'utf8');

function sources(dir, acc = []) {
  for (const name of readdirSync(dir)) {
    if (['node_modules', 'build', 'dist', '.dart_tool'].includes(name)) continue;
    const p = join(dir, name);
    if (statSync(p).isDirectory()) sources(p, acc);
    else if (/\.(ts|tsx|dart|conf)$/.test(name)) acc.push(p);
  }
  return acc;
}

test('[T9-05] no tile host is hard-coded outside the map settings', () => {
  const allowed = ['apps/dashboard/src/ui/MapView.tsx', 'packages/naql_app/lib/src/config.dart'];
  for (const f of [...sources(join(root, 'apps')), ...sources(join(root, 'packages'))]) {
    if (allowed.some((a) => f.endsWith(a)) || /\/e2e\//.test(f)) continue;
    assert.doesNotMatch(readFileSync(f, 'utf8'), /cartocdn|tile\.openstreetmap|\{z\}\/\{x\}\/\{y\}/, `tile URL hard-coded in ${f}`);
  }
  assert.match(read('apps/dashboard/src/ui/MapView.tsx'), /import\.meta\.env\.VITE_MAP_TILES/);
  assert.match(read('packages/naql_app/lib/src/config.dart'), /String\.fromEnvironment\('MAP_TILES'/);
  assert.match(read('apps/student_app/lib/screens/track_screen.dart'), /urlTemplate: mapTilesUrl/);
  assert.match(read('apps/student_app/lib/screens/track_screen.dart'), /SimpleAttributionWidget/);
});

test('[T9-05] the dashboard CSP is filled with the tile host at build time', () => {
  const nginx = read('apps/dashboard/nginx.conf');
  assert.match(nginx, /img-src [^;]*__MAP_ORIGINS__/);
  assert.match(nginx, /connect-src [^;]*__MAP_ORIGINS__/);
  const docker = read('apps/dashboard/Dockerfile');
  assert.match(docker, /ARG VITE_MAP_TILES=/);
  assert.match(docker, /s#__MAP_ORIGINS__#/);
  assert.match(docker, /! grep -q __MAP_ORIGINS__/);
});
