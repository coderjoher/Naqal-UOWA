/** Normalises Iraqi mobile numbers to +9647XXXXXXXXX. Throws on anything else. */
export function normalizeIraqiPhone(input: string): string {
  const digits = input.replace(/[\s\-()]/g, '').replace(/^\+/, '');
  let local: string;
  if (/^9647\d{9}$/.test(digits)) local = digits.slice(3);
  else if (/^07\d{9}$/.test(digits)) local = digits.slice(1);
  else if (/^7\d{9}$/.test(digits)) local = digits;
  else throw new Error(`Not an Iraqi mobile number: ${input}`);
  return `+964${local}`;
}

/** class-transformer helper: drop spaces, dashes and brackets people type in phone numbers. */
export const stripPhone = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.replace(/[\s\-()]/g, '') : value);
