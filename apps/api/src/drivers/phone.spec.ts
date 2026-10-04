import { normalizeIraqiPhone } from './phone';

describe('normalizeIraqiPhone', () => {
  it('accepts local, international and spaced forms', () => {
    for (const v of ['07701234567', '+9647701234567', '9647701234567', '0770 123 4567', '7701234567']) expect(normalizeIraqiPhone(v)).toBe('+9647701234567');
  });
  it('rejects landlines and foreign numbers', () => {
    for (const v of ['040123456', '+44770123456', '0770123456', 'abc']) expect(() => normalizeIraqiPhone(v)).toThrow();
  });
});
