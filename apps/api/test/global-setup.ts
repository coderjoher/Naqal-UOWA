import { execSync } from 'node:child_process';
import { join } from 'node:path';

export default function globalSetup() {
  require('./setup-env');
  execSync('npx prisma migrate deploy', { cwd: join(__dirname, '..'), stdio: 'inherit', env: process.env });
}
