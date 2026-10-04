import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { PaymentMethod, PaymentType } from '@prisma/client';
import { PrismaService, Tx } from '../prisma/prisma.service';
import { PAYMENT_PROVIDERS, PaymentProvider } from './payment-provider';


export interface RecordInput {
  universityId: string;
  type: PaymentType;
  method: PaymentMethod;
  amount: number;
  studentId?: string | null;
  collectedById: string;
  reference: string;
  note?: string;
}

/** All money goes through here: provider confirmation, gap-free receipt number, immutable row. */
@Injectable()
export class PaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(PAYMENT_PROVIDERS) private readonly providers: PaymentProvider[],
  ) {}

  provider(method: PaymentMethod): PaymentProvider {
    const p = this.providers.find((x) => x.method === method);
    if (!p) throw new BadRequestException(`Payment method ${method} is not enabled`);
    return p;
  }

  /** Next receipt number for the university; atomic, rolls back with the surrounding transaction. */
  static async nextReceiptNo(tx: Tx, universityId: string): Promise<number> {
    const rows = await tx.$queryRaw<{ last: number }[]>`
      INSERT INTO receipt_counters (university_id, last) VALUES (${universityId}::uuid, 1)
      ON CONFLICT (university_id) DO UPDATE SET last = receipt_counters.last + 1
      RETURNING last`;
    return rows[0].last;
  }

  /** Records a payment inside `tx` (callers add their own rows in the same transaction). */
  async record(tx: Tx, input: RecordInput) {
    if (!Number.isInteger(input.amount) || input.amount <= 0) throw new BadRequestException('Amount must be a positive whole number of dinars');
    const { externalRef } = await this.provider(input.method).collect(input.amount, input.reference);
    const receiptNo = await PaymentsService.nextReceiptNo(tx, input.universityId);
    return tx.payment.create({
      data: {
        universityId: input.universityId,
        type: input.type,
        method: input.method,
        amount: input.amount,
        receiptNo,
        studentId: input.studentId ?? null,
        collectedById: input.collectedById,
        externalRef,
        note: input.note,
      },
    });
  }

  /** NF-14: corrections are a new negative row pointing at the original; the original stays untouched. */
  async reverse(universityId: string, paymentId: string, byUserId: string, reason: string) {
    if (!reason?.trim()) throw new BadRequestException('Give a reason for the reversal');
    return this.prisma.db.$transaction(async (tx) => {
      const original = await tx.payment.findFirst({ where: { id: paymentId, universityId }, include: { reversedBy: true } });
      if (!original) throw new NotFoundException();
      if (original.amount < 0) throw new BadRequestException('A reversal cannot be reversed');
      if (original.reversedBy) throw new ConflictException('This payment is already reversed');
      const receiptNo = await PaymentsService.nextReceiptNo(tx, universityId);
      const reversal = await tx.payment.create({
        data: {
          universityId,
          type: original.type,
          method: original.method,
          amount: -original.amount,
          receiptNo,
          studentId: original.studentId,
          collectedById: byUserId,
          reversesPaymentId: original.id,
          note: reason.trim(),
        },
      });
      await tx.subscription.updateMany({ where: { paymentId: original.id, universityId }, data: { status: 'cancelled' } });
      return reversal;
    });
  }
}
