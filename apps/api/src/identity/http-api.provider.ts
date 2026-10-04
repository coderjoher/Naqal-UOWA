import { Gender, IdentityProvider, mapGender, pick, ProviderUnavailableError, StudentRecord } from './identity-provider';

export interface HttpApiConfig {
  type: 'http';
  /** POST endpoint receiving { studentId, password }. */
  url: string;
  apiKeyHeader?: string;
  apiKey?: string;
  /** Dotted paths into the response body. */
  fields?: { studentId?: string; name?: string; nameAr?: string; gender?: string };
  genderMap?: Record<string, Gender>;
  timeoutMs?: number;
}

/** Student verification through the university's own REST API (Q2 option A). */
export class HttpApiProvider implements IdentityProvider {
  readonly kind = 'http' as const;
  constructor(private readonly cfg: HttpApiConfig) {}

  async verify({ studentId, secret }: { studentId?: string; secret: string }): Promise<StudentRecord | null> {
    if (!studentId) return null;
    let res: Response;
    try {
      res = await fetch(this.cfg.url, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...(this.cfg.apiKeyHeader && this.cfg.apiKey ? { [this.cfg.apiKeyHeader]: this.cfg.apiKey } : {}) },
        body: JSON.stringify({ studentId, password: secret }),
        signal: AbortSignal.timeout(this.cfg.timeoutMs ?? 8000),
      });
    } catch (e) {
      throw new ProviderUnavailableError(e);
    }
    if (res.status === 401 || res.status === 403 || res.status === 404) return null;
    if (!res.ok) throw new ProviderUnavailableError(`HTTP ${res.status}`);
    const body = (await res.json()) as unknown;
    const f = this.cfg.fields ?? {};
    const gender = mapGender(pick(body, f.gender ?? 'gender'), this.cfg.genderMap);
    const name = pick(body, f.name ?? 'name');
    if (!gender || typeof name !== 'string') throw new ProviderUnavailableError('Unexpected response from university system');
    const nameAr = pick(body, f.nameAr ?? 'nameAr');
    return { studentId: String(pick(body, f.studentId ?? 'studentId') ?? studentId), name, nameAr: typeof nameAr === 'string' ? nameAr : undefined, gender };
  }
}
