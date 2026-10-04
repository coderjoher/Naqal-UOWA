import type { PaymentMethod } from '@prisma/client';

/**
 * PA-04: how money is collected. Cash at the office completes immediately; an electronic
 * provider (ZainCash, Qi) confirms the charge and returns its reference. PaymentsService only
 * talks to this interface, so adding a provider needs no schema change.
 */
export interface PaymentProvider {
  readonly method: PaymentMethod;
  /** Confirms that `amount` IQD was received; returns the provider's reference (null for cash). */
  collect(amount: number, reference: string): Promise<{ externalRef: string | null }>;
}

export class OfficeCashProvider implements PaymentProvider {
  readonly method = 'cash_office' as const;
  async collect() {
    return { externalRef: null };
  }
}

/** DR-07: a pay-per-ride fare handed to the driver in cash. */
export class DriverCashProvider implements PaymentProvider {
  readonly method = 'cash_driver' as const;
  async collect() {
    return { externalRef: null };
  }
}

export const PAYMENT_PROVIDERS = Symbol('PAYMENT_PROVIDERS');
