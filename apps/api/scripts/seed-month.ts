/*
 * Writes a finished month of service (subscriptions, GPS-tracked runs, cash fares) for one
 * university, so the settlement can be tried without driving a month of buses.
 *
 *   npx ts-node scripts/seed-month.ts <university-slug> <YYYY-MM>
 */
import { PrismaClient } from '@prisma/client';
import { seedMonth } from '../prisma/month-fixture';

async function main() {
  const [slug, month] = process.argv.slice(2);
  if (!slug || !/^\d{4}-(0[1-9]|1[0-2])$/.test(month ?? '')) throw new Error('Usage: seed-month.ts <university-slug> <YYYY-MM>');
  const prisma = new PrismaClient();
  try {
    const uni = await prisma.university.findUniqueOrThrow({ where: { slug } });
    const fx = await seedMonth(prisma, uni.id, month);
    console.log(JSON.stringify({ month, runs: fx.runs, drivers: fx.drivers.length }));
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
