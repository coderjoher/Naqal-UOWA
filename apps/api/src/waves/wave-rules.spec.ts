import { ALL_DAYS, findClash, fromHHMM, SUN_TO_THU, toHHMM, validateWave } from './wave-rules';

describe('wave rules', () => {
  it('[T1-07] accepts morning and return types with a weekday mask', () => {
    expect(validateWave({ type: 'morning', minuteOfDay: fromHHMM('08:00'), weekdays: SUN_TO_THU })).toEqual([]);
    expect(validateWave({ type: 'return', minuteOfDay: fromHHMM('14:30'), weekdays: ALL_DAYS })).toEqual([]);
  });

  it('[T1-07] rejects invalid times and empty weekday masks', () => {
    expect(validateWave({ type: 'morning', minuteOfDay: 1440, weekdays: 1 })).toHaveLength(1);
    expect(validateWave({ type: 'morning', minuteOfDay: -1, weekdays: 1 })).toHaveLength(1);
    expect(validateWave({ type: 'morning', minuteOfDay: 480, weekdays: 0 })).toHaveLength(1);
    expect(validateWave({ type: 'morning', minuteOfDay: 480, weekdays: 128 })).toHaveLength(1);
    expect(() => fromHHMM('24:00')).toThrow();
    expect(toHHMM(fromHHMM('07:05'))).toBe('07:05');
  });

  it('[T1-07] no duplicate time per type and day', () => {
    const existing = [{ id: '1', type: 'morning' as const, minuteOfDay: 480, weekdays: 0b0000011 }];
    expect(findClash({ type: 'morning', minuteOfDay: 480, weekdays: 0b0000010 }, existing)?.id).toBe('1');
    expect(findClash({ type: 'morning', minuteOfDay: 480, weekdays: 0b0000100 }, existing)).toBeUndefined(); // other day
    expect(findClash({ type: 'return', minuteOfDay: 480, weekdays: 0b0000011 }, existing)).toBeUndefined(); // other type
    expect(findClash({ type: 'morning', minuteOfDay: 600, weekdays: 0b0000011 }, existing)).toBeUndefined(); // other time
    expect(findClash({ id: '1', type: 'morning', minuteOfDay: 480, weekdays: 0b0000011 }, existing)).toBeUndefined(); // itself
    expect(findClash({ type: 'morning', minuteOfDay: 480, weekdays: 1 }, [{ ...existing[0], active: false }])).toBeUndefined();
  });
});
