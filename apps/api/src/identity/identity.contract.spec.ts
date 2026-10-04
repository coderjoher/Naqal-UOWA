import * as bcrypt from 'bcryptjs';
import { exportJWK, generateKeyPair, SignJWT } from 'jose';
import { AddressInfo } from 'node:net';
import { createServer, Server } from 'node:http';
import { HttpApiProvider } from './http-api.provider';
import { IdentityProvider, ProviderUnavailableError } from './identity-provider';
import { OidcProvider } from './oidc.provider';
import { RosterProvider, RosterRow } from './roster.provider';

/** Free localhost port nobody listens on → connection refused. */
const DEAD = 'http://127.0.0.1:9';

function listen(handler: Parameters<typeof createServer>[1]): Promise<{ server: Server; url: string }> {
  const server = createServer(handler);
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve({ server, url: `http://127.0.0.1:${(server.address() as AddressInfo).port}` })));
}

interface Fixture {
  name: string;
  /** Provider wired to a working university system. */
  ok: IdentityProvider;
  /** Same provider type pointed at an unreachable system. */
  down: IdentityProvider;
  valid: { studentId?: string; secret: string };
  unknown: { studentId?: string; secret: string };
}

const servers: Server[] = [];
const fixtures: Fixture[] = [];

beforeAll(async () => {
  // HTTP API: S1 / pw → female student; anything else 404.
  const http = await listen((req, res) => {
    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', () => {
      const { studentId, password } = JSON.parse(raw || '{}');
      if (studentId === 'S1' && password === 'pw') {
        res.setHeader('content-type', 'application/json');
        return res.end(JSON.stringify({ data: { id: 'S1', full_name: 'Zainab Kadhim', full_name_ar: 'زينب كاظم', sex: 'F' } }));
      }
      res.statusCode = 404;
      res.end('{}');
    });
  });
  servers.push(http.server);
  const httpCfg = { type: 'http' as const, fields: { studentId: 'data.id', name: 'data.full_name', nameAr: 'data.full_name_ar', gender: 'data.sex' } };
  fixtures.push({
    name: 'HttpApiProvider',
    ok: new HttpApiProvider({ ...httpCfg, url: `${http.url}/verify` }),
    down: new HttpApiProvider({ ...httpCfg, url: `${DEAD}/verify`, timeoutMs: 1000 }),
    valid: { studentId: 'S1', secret: 'pw' },
    unknown: { studentId: 'S404', secret: 'pw' },
  });

  // OIDC: a JWKS endpoint + tokens signed with its key (and one with a foreign key).
  const { publicKey, privateKey } = await generateKeyPair('RS256');
  const other = await generateKeyPair('RS256');
  const jwk = { ...(await exportJWK(publicKey)), kid: 'k1', alg: 'RS256', use: 'sig' };
  const jwks = await listen((_req, res) => {
    res.setHeader('content-type', 'application/json');
    res.end(JSON.stringify({ keys: [jwk] }));
  });
  servers.push(jwks.server);
  const oidcCfg = { type: 'oidc' as const, issuer: 'https://sso.uowa.edu.iq', audience: 'naql' };
  const token = (key: Parameters<SignJWT['sign']>[0], claims: object) =>
    new SignJWT({ student_id: 'S1', name: 'Zainab Kadhim', gender: 'female', ...claims })
      .setProtectedHeader({ alg: 'RS256', kid: 'k1' })
      .setIssuer(oidcCfg.issuer)
      .setAudience(oidcCfg.audience)
      .setIssuedAt()
      .setExpirationTime('5m')
      .sign(key);
  fixtures.push({
    name: 'OidcProvider',
    ok: new OidcProvider({ ...oidcCfg, jwksUri: `${jwks.url}/jwks` }),
    down: new OidcProvider({ ...oidcCfg, jwksUri: `${DEAD}/jwks` }),
    valid: { secret: await token(privateKey, {}) },
    unknown: { secret: await token(other.privateKey, {}) },
  });

  // Manual roster: S1 has a valid activation code 482913.
  const row: RosterRow = {
    id: 'r1',
    studentId: 'S1',
    name: 'Zainab Kadhim',
    nameAr: 'زينب كاظم',
    gender: 'female',
    activationCodeHash: await bcrypt.hash('482913', 4),
    activationExpiresAt: new Date(Date.now() + 3600_000),
    activationAttempts: 0,
  };
  fixtures.push({
    name: 'RosterProvider',
    ok: new RosterProvider({ find: async (id) => (id === 'S1' ? { ...row } : null), recordFailedAttempt: async () => {} }),
    down: new RosterProvider({
      find: async () => {
        throw new Error('database unavailable');
      },
      recordFailedAttempt: async () => {},
    }),
    valid: { studentId: 'S1', secret: '482913' },
    unknown: { studentId: 'S404', secret: '482913' },
  });
});

afterAll(() => servers.forEach((s) => s.close()));

describe.each(['HttpApiProvider', 'OidcProvider', 'RosterProvider'])('identity adapter contract: %s', (name) => {
  const f = () => fixtures.find((x) => x.name === name)!;

  it('[T2-01] valid student → record with id, name and gender', async () => {
    await expect(f().ok.verify(f().valid)).resolves.toEqual(expect.objectContaining({ studentId: 'S1', name: 'Zainab Kadhim', gender: 'female' }));
  });

  it('[T2-01] unknown student or wrong secret → null', async () => {
    await expect(f().ok.verify(f().unknown)).resolves.toBeNull();
  });

  it('[T2-01] university system unreachable → ProviderUnavailableError', async () => {
    await expect(f().down.verify(f().valid)).rejects.toBeInstanceOf(ProviderUnavailableError);
  });
});

describe('adapter specifics', () => {
  it('roster: expired code, too many attempts and wrong code are rejected; wrong code is counted', async () => {
    let attempts = 0;
    const base: RosterRow = { id: 'r', studentId: 'S2', name: 'Ali', nameAr: null, gender: 'male', activationCodeHash: await bcrypt.hash('111111', 4), activationExpiresAt: new Date(Date.now() + 1000), activationAttempts: 0 };
    const store = (row: RosterRow) => ({ find: async () => row, recordFailedAttempt: async () => void attempts++ });
    expect(await new RosterProvider(store(base)).verify({ studentId: 'S2', secret: '222222' })).toBeNull();
    expect(attempts).toBe(1);
    expect(await new RosterProvider(store({ ...base, activationExpiresAt: new Date(Date.now() - 1) })).verify({ studentId: 'S2', secret: '111111' })).toBeNull();
    expect(await new RosterProvider(store({ ...base, activationAttempts: 5 })).verify({ studentId: 'S2', secret: '111111' })).toBeNull();
    expect(await new RosterProvider(store(base)).verify({ studentId: 'S2', secret: ' 111111 ' })).toMatchObject({ gender: 'male' });
  });

  it('oidc: a token for another student id is rejected', async () => {
    const f = fixtures.find((x) => x.name === 'OidcProvider')!;
    await expect(f.ok.verify({ ...f.valid, studentId: 'S9' })).resolves.toBeNull();
  });
});
