import { redact } from './audit.interceptor';

describe('audit redact', () => {
  it('removes secrets at any depth', () => {
    expect(redact({ email: 'a', password: 'p', nested: [{ accessToken: 't', ok: 1 }] })).toEqual({
      email: 'a',
      password: '[redacted]',
      nested: [{ accessToken: '[redacted]', ok: 1 }],
    });
    expect(redact(null)).toBeNull();
  });
});
