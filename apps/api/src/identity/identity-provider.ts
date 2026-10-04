export type Gender = 'male' | 'female';

/** What the university system tells us about a student (ST-01, ST-02). */
export interface StudentRecord {
  studentId: string;
  name: string;
  nameAr?: string;
  gender: Gender;
}

/**
 * Verifies a student against the university. `secret` is the student's password (HTTP API),
 * an ID token (OIDC SSO) or an office-issued activation code (manual roster).
 * Returns null when the student is unknown or the secret is wrong.
 * Throws ProviderUnavailableError when the university system cannot be reached.
 */
export interface IdentityProvider {
  readonly kind: 'manual' | 'http' | 'oidc';
  verify(input: { studentId?: string; secret: string }): Promise<StudentRecord | null>;
}

export class ProviderUnavailableError extends Error {
  constructor(cause?: unknown) {
    super('University identity service is unavailable');
    this.name = 'ProviderUnavailableError';
    this.cause = cause;
  }
}

/** Maps a raw gender value from a university system to ours (configurable per university). */
export function mapGender(raw: unknown, map: Record<string, Gender> = {}): Gender | null {
  if (typeof raw !== 'string') return null;
  const v = raw.trim();
  const defaults: Record<string, Gender> = { male: 'male', female: 'female', m: 'male', f: 'female', ذكر: 'male', أنثى: 'female', انثى: 'female' };
  return map[v] ?? defaults[v.toLowerCase()] ?? null;
}

/** Reads a dotted path such as `data.student.gender` from a JSON object. */
export function pick(obj: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>((o, k) => (o && typeof o === 'object' ? (o as Record<string, unknown>)[k] : undefined), obj);
}
