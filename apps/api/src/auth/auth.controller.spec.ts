import { AuthController } from './auth.controller';

describe('AuthController', () => {
  it('delegates login and scopes /me to the caller', async () => {
    const auth = { login: jest.fn().mockResolvedValue({ accessToken: 't' }) } as any;
    const findUniqueOrThrow = jest.fn().mockResolvedValue({ id: 'u' });
    const ctrl = new AuthController(auth, { db: { user: { findUniqueOrThrow } } } as any);
    await expect(ctrl.login({ email: 'a@b.iq', password: 'password1' })).resolves.toEqual({ accessToken: 't' });
    await ctrl.me({ id: 'u', role: 'student', universityId: 'x' });
    expect(findUniqueOrThrow.mock.calls[0][0].where).toEqual({ id: 'u' });
  });
});
