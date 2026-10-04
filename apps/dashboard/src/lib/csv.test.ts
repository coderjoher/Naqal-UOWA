import { describe, expect, it } from 'vitest';
import { parseRoster } from './csv';

describe('parseRoster', () => {
  it('reads header + rows with Arabic names and genders in either language', () => {
    const { rows, badLines } = parseRoster('﻿student_id,name,name_ar,gender\nW-1,Zainab Kadhim,زينب كاظم,أنثى\nW-2,"Ali, Hassan",,M\n\nW-3,Hussein,حسين,male\n');
    expect(badLines).toEqual([]);
    expect(rows).toEqual([
      { studentId: 'W-1', name: 'Zainab Kadhim', nameAr: 'زينب كاظم', gender: 'female' },
      { studentId: 'W-2', name: 'Ali, Hassan', nameAr: undefined, gender: 'male' },
      { studentId: 'W-3', name: 'Hussein', nameAr: 'حسين', gender: 'male' },
    ]);
  });

  it('accepts three columns without an Arabic name and reports unreadable lines', () => {
    const { rows, badLines } = parseRoster('S1;Ali;ذكر\nS2;Mona;unknown\nS3;;F');
    expect(rows).toEqual([{ studentId: 'S1', name: 'Ali', nameAr: undefined, gender: 'male' }]);
    expect(badLines).toEqual([2, 3]);
  });
});
