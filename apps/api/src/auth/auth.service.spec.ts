import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  const jwt = new JwtService({ secret: 'unit-test-secret' });
  let hash: string;
  beforeAll(async () => (hash = await bcrypt.hash('correct-horse', 4)));

  const service = (user: object | null) => new AuthService({ db: { user: { findUnique: jest.fn().mockResolvedValue(user) } } } as any, jwt);

  it('returns a token carrying role and university', async () => {
    const res = await service({ id: 'u', name: 'N', role: 'office', universityId: 'uni', status: 'active', passwordHash: hash }).login('Office@X.iq', 'correct-horse');
    expect(res.user).toEqual({ id: 'u', name: 'N', role: 'office', universityId: 'uni' });
    expect(await jwt.verifyAsync(res.accessToken)).toMatchObject({ sub: 'u', role: 'office', uid: 'uni' });
  });

  it('rejects wrong password, unknown email and suspended users with the same error', async () => {
    const active = { id: 'u', role: 'office', universityId: 'uni', status: 'active', passwordHash: hash };
    await expect(service(active).login('a@b.iq', 'wrong-password')).rejects.toThrow(UnauthorizedException);
    await expect(service(null).login('a@b.iq', 'correct-horse')).rejects.toThrow(UnauthorizedException);
    await expect(service({ ...active, status: 'suspended' }).login('a@b.iq', 'correct-horse')).rejects.toThrow(UnauthorizedException);
  });
});
