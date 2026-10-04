import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentMethod } from '@prisma/client';
import { PaymentsService } from '../payments/payments.service';
import { renderReceipt } from '../payments/receipt-pdf';
import { PrismaService } from '../prisma/prisma.service';
import { calendarMonth, covers, daysLeft, monthOf } from './period-policy';
import { subscriptionPrice } from './pricing';

export const EXPIRING_DAYS = 3;

@Injectable()
export class SubscriptionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly payments: PaymentsService,
  ) {}

  /** TO-06: record the cash payment, activate the subscription and issue a receipt — one transaction. */
  async create(universityId: string, officeUserId: string, input: { studentId: string; month?: string; method?: PaymentMethod }) {
    const db = this.prisma.db;
    const student = await db.user.findFirst({
      where: { OR: [{ id: isUuid(input.studentId) ? input.studentId : undefined }, { studentId: input.studentId }], role: 'student' },
      include: { defaultPoint: { include: { tier: true } } },
    });
    if (!student) throw new NotFoundException('Student not found. They must sign in to the app once first.');
    if (student.status !== 'active') throw new BadRequestException('This student account is suspended');
    const point = student.defaultPoint;
    if (!point || !point.active) throw new BadRequestException('The student has not chosen a gathering point in the app yet');

    const month = input.month ?? monthOf(new Date());
    let period;
    try {
      period = calendarMonth(month);
    } catch {
      throw new BadRequestException('Month must look like 2026-10');
    }
    const price = subscriptionPrice(point.tier);

    return db.$transaction(async (tx) => {
      const existing = await tx.subscription.findFirst({ where: { universityId, studentId: student.id, month, status: 'active' } });
      if (existing) throw new ConflictException('The student already has an active subscription for this month');
      const payment = await this.payments.record(tx, {
        universityId,
        type: 'subscription',
        method: input.method ?? 'cash_office',
        amount: price,
        studentId: student.id,
        collectedById: officeUserId,
        reference: `sub:${student.id}:${month}`,
      });
      const subscription = await tx.subscription.create({
        data: {
          universityId,
          studentId: student.id,
          tierId: point.tierId,
          pointId: point.id,
          month,
          periodStart: period.start,
          periodEnd: period.end,
          price,
          paymentId: payment.id,
        },
      });
      return { subscription, payment: { id: payment.id, receiptNo: payment.receiptNo, amount: payment.amount, createdAt: payment.createdAt } };
    });
  }

  /** What the office sees before taking the money: who, which point and tier, how much. */
  async preview(studentRef: string, month?: string) {
    const db = this.prisma.db;
    const student = await db.user.findFirst({
      where: { OR: [{ id: isUuid(studentRef) ? studentRef : undefined }, { studentId: studentRef.trim() }], role: 'student' },
      include: { defaultPoint: { include: { tier: true } } },
    });
    if (!student) throw new NotFoundException('Student not found. They must sign in to the app once first.');
    const m = month ?? monthOf(new Date());
    const already = await db.subscription.findFirst({ where: { studentId: student.id, month: m, status: 'active' } });
    const p = student.defaultPoint;
    return {
      student: { id: student.id, studentId: student.studentId, name: student.name, nameAr: student.nameAr, gender: student.gender, status: student.status },
      point: p ? { id: p.id, name: p.name, nameAr: p.nameAr, active: p.active } : null,
      tier: p ? { id: p.tier.id, name: p.tier.name } : null,
      month: m,
      price: p ? subscriptionPrice(p.tier) : null,
      alreadySubscribed: !!already,
    };
  }

  /** ST-03: what the student app shows. */
  async forStudent(studentUserId: string, now = new Date()) {
    const db = this.prisma.db;
    const subs = await db.subscription.findMany({ where: { studentId: studentUserId, status: 'active' }, orderBy: { periodEnd: 'desc' }, take: 6 });
    const current = subs.find((s) => covers({ start: s.periodStart, end: s.periodEnd }, now));
    const upcoming = subs.find((s) => s.periodStart > now);
    const student = await db.user.findUnique({ where: { id: studentUserId }, include: { defaultPoint: { include: { tier: true } }, university: true } });
    const tier = student?.defaultPoint?.tier;
    const view = (s: (typeof subs)[number]) => ({ id: s.id, month: s.month, start: s.periodStart, end: s.periodEnd, price: s.price, tierId: s.tierId });
    const left = current ? daysLeft({ end: current.periodEnd }, now) : 0;
    return {
      status: current ? (left <= EXPIRING_DAYS && !upcoming ? 'expiring' : 'active') : subs.length ? 'expired' : 'none',
      daysLeft: left,
      current: current ? view(current) : null,
      upcoming: upcoming ? view(upcoming) : null,
      price: tier ? subscriptionPrice(tier) : null,
      tierName: tier?.name ?? null,
      payAt: { officeNote: student?.university?.officeNote ?? null },
    };
  }

  list(month?: string) {
    return this.prisma.db.subscription.findMany({
      where: month ? { month } : {},
      orderBy: { createdAt: 'desc' },
      take: 500,
      include: { student: { select: { id: true, name: true, nameAr: true, studentId: true } }, payment: { select: { receiptNo: true, amount: true, createdAt: true, reversedBy: { select: { id: true } } } } },
    });
  }

  async receipt(paymentId: string): Promise<Buffer> {
    const db = this.prisma.db;
    const p = await db.payment.findUnique({ where: { id: paymentId }, include: { student: true, university: true, reverses: { include: { subscription: true } }, subscription: true } });
    if (!p) throw new NotFoundException();
    const sub = p.subscription ?? p.reverses?.subscription ?? null;
    const [tier, point, collector] = await Promise.all([
      sub ? db.distanceTier.findUnique({ where: { id: sub.tierId } }) : null,
      sub ? db.gatheringPoint.findUnique({ where: { id: sub.pointId } }) : null,
      db.user.findUnique({ where: { id: p.collectedById } }),
    ]);
    return renderReceipt({
      universityName: p.university.nameAr ?? p.university.name,
      receiptNo: p.receiptNo,
      issuedAt: p.createdAt,
      studentName: p.student?.nameAr || p.student?.name || '—',
      studentNumber: p.student?.studentId ?? '—',
      month: sub?.month ?? '—',
      tierName: tier?.name ?? '—',
      pointName: point?.nameAr || point?.name || '—',
      amount: p.amount,
      collectedBy: collector?.name ?? '—',
      reversal: p.amount < 0,
    });
  }
}

const isUuid = (v: string) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
