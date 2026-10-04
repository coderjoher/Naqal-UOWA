/* Resets the e2e database and creates one configured university + office account. */
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  await prisma.$executeRawUnsafe(
    'TRUNCATE otp_codes, document_accesses, driver_documents, driver_profiles, roster_entries, travel_times, gathering_points, distance_tiers, waves, driver_requirement_sets, audit_events, users, universities CASCADE',
  );
  const hash = await bcrypt.hash('password123', 4);
  const uni = await prisma.university.create({
    data: {
      name: 'Warith Al-Anbiyaa University',
      nameAr: 'جامعة وارث الأنبياء',
      slug: 'warith',
      campusLat: 32.5847,
      campusLng: 44.0617,
      coverage: [
        [32.3, 43.7],
        [32.3, 44.4],
        [32.9, 44.4],
        [32.9, 43.7],
      ],
    },
  });
  await prisma.user.create({ data: { universityId: uni.id, role: 'office', name: 'مكتب النقل', email: 'office@uowa.edu.iq', passwordHash: hash } });
  await prisma.user.create({ data: { role: 'super_admin', name: 'Platform Admin', email: 'admin@naql.app', passwordHash: hash } });
}

main().finally(() => prisma.$disconnect());
