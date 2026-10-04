import { readFileSync } from 'node:fs';
import { join } from 'node:path';

// Load .env.test unless CI already provides the variables.
for (const line of readFileSync(join(__dirname, '../.env.test'), 'utf8').split('\n')) {
  const m = line.match(/^([A-Z_]+)=(.*)$/);
  if (m && process.env[m[1]] === undefined) process.env[m[1]] = m[2];
}
