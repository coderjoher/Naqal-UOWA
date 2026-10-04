import * as bcrypt from 'bcryptjs';
import { IdentityProvider, ProviderUnavailableError, StudentRecord } from './identity-provider';

export const MAX_ACTIVATION_ATTEMPTS = 5;

export interface RosterRow {
  id: string;
  studentId: string;
  name: string;
  nameAr: string | null;
  gender: 'male' | 'female';
  activationCodeHash: string | null;
  activationExpiresAt: Date | null;
  activationAttempts: number;
}

export interface RosterStore {
  find(studentId: string): Promise<RosterRow | null>;
  recordFailedAttempt(id: string): Promise<void>;
}

/**
 * Manual identity (PRD fallback; pilot default): the office imports the roster and hands the
 * student a one-time activation code at the office. The secret is that code.
 */
export class RosterProvider implements IdentityProvider {
  readonly kind = 'manual' as const;
  constructor(
    private readonly store: RosterStore,
    private readonly now: () => Date = () => new Date(),
  ) {}

  async verify({ studentId, secret }: { studentId?: string; secret: string }): Promise<StudentRecord | null> {
    if (!studentId) return null;
    let row: RosterRow | null;
    try {
      row = await this.store.find(studentId.trim());
    } catch (e) {
      throw new ProviderUnavailableError(e);
    }
    if (!row || !row.activationCodeHash || !row.activationExpiresAt) return null;
    if (row.activationExpiresAt < this.now() || row.activationAttempts >= MAX_ACTIVATION_ATTEMPTS) return null;
    if (!(await bcrypt.compare(secret.trim(), row.activationCodeHash))) {
      await this.store.recordFailedAttempt(row.id);
      return null;
    }
    return { studentId: row.studentId, name: row.name, nameAr: row.nameAr ?? undefined, gender: row.gender };
  }
}
