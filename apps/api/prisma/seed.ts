/* Development seed. Passwords are for local use only. */
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();
const DEV_PASSWORD = 'password123';

async function main() {
  const hash = await bcrypt.hash(DEV_PASSWORD, 10);
  const warith = await prisma.university.upsert({
    where: { slug: 'warith' },
    update: {},
    create: { name: 'Warith Al-Anbiyaa University', nameAr: 'جامعة وارث الأنبياء', slug: 'warith', campusLat: 32.5847, campusLng: 44.0617, commissionPct: 10, waitlistMinutes: 30 },
  });
  const users = [
    { email: 'admin@naql.app', name: 'Platform Admin', role: 'super_admin' as const, universityId: null },
    { email: 'office@uowa.edu.iq', name: 'مكتب النقل', role: 'office' as const, universityId: warith.id },
    { email: 'student@uowa.edu.iq', name: 'طالب تجريبي', role: 'student' as const, universityId: warith.id, gender: 'male' as const },
    { email: 'driver@uowa.edu.iq', name: 'سائق تجريبي', role: 'driver' as const, universityId: warith.id, gender: 'male' as const },
  ];
  for (const u of users) {
    await prisma.user.upsert({ where: { email: u.email }, update: {}, create: { ...u, passwordHash: hash } });
  }
  console.log(`Seeded. Log in with any of ${users.map((u) => u.email).join(', ')} / ${DEV_PASSWORD}`);
}

main().finally(() => prisma.$disconnect());
