import { createRemoteJWKSet, errors, jwtVerify, type JWTVerifyGetKey } from 'jose';
import { Gender, IdentityProvider, mapGender, ProviderUnavailableError, StudentRecord } from './identity-provider';

export interface OidcConfig {
  type: 'oidc';
  issuer: string;
  audience: string;
  jwksUri: string;
  /** Claim names carrying the student fields. */
  claims?: { studentId?: string; name?: string; nameAr?: string; gender?: string };
  genderMap?: Record<string, Gender>;
}

/** University SSO (Q2 option B): the app obtains an ID token, the API verifies it here. */
export class OidcProvider implements IdentityProvider {
  readonly kind = 'oidc' as const;
  private readonly jwks: JWTVerifyGetKey;

  constructor(private readonly cfg: OidcConfig) {
    this.jwks = createRemoteJWKSet(new URL(cfg.jwksUri), { timeoutDuration: 5000, cooldownDuration: 0 });
  }

  async verify({ studentId, secret }: { studentId?: string; secret: string }): Promise<StudentRecord | null> {
    let payload: Record<string, unknown>;
    try {
      ({ payload } = await jwtVerify(secret, this.jwks, { issuer: this.cfg.issuer, audience: this.cfg.audience }));
    } catch (e) {
      // jose errors mean the token is bad (signature, issuer, expiry…) → not verified.
      // Anything else (connection refused, DNS, timeout fetching the key set) → university unreachable.
      if (e instanceof errors.JWKSTimeout || !(e instanceof errors.JOSEError)) throw new ProviderUnavailableError(e);
      return null;
    }
    const c = this.cfg.claims ?? {};
    const id = payload[c.studentId ?? 'student_id'];
    const name = payload[c.name ?? 'name'];
    const gender = mapGender(payload[c.gender ?? 'gender'], this.cfg.genderMap);
    if (typeof id !== 'string' || typeof name !== 'string' || !gender) return null;
    if (studentId && studentId !== id) return null;
    const nameAr = payload[c.nameAr ?? 'name_ar'];
    return { studentId: id, name, nameAr: typeof nameAr === 'string' ? nameAr : undefined, gender };
  }
}
