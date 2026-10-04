import { plainToInstance } from 'class-transformer';
import { validateSync } from 'class-validator';
import { CreateUniversityDto, UpdateUniversityDto } from './universities.dto';

const errorsFor = (dto: object) => validateSync(plainToInstance(UpdateUniversityDto, dto)).map((e) => e.property);

describe('university settings validation', () => {
  it('[T1-02] commission accepts 0–100 % with up to 2 decimals', () => {
    for (const ok of [0, 10, 12.5, 7.25, 100]) expect(errorsFor({ commissionPct: ok })).toEqual([]);
    for (const bad of [-1, 100.01, 10.123]) expect(errorsFor({ commissionPct: bad })).toEqual(['commissionPct']);
  });

  it('[T1-02] waitlist duration is whole minutes from 1 to 240', () => {
    for (const ok of [1, 30, 240]) expect(errorsFor({ waitlistMinutes: ok })).toEqual([]);
    for (const bad of [0, 241, 12.5]) expect(errorsFor({ waitlistMinutes: bad })).toEqual(['waitlistMinutes']);
  });

  it('create requires a slug, campus location and a strong office password', () => {
    const errs = validateSync(plainToInstance(CreateUniversityDto, { name: 'X', slug: 'Bad Slug', campusLat: 91, campusLng: 0, officeAccount: { name: 'o', email: 'x', password: 'short' } }));
    expect(errs.map((e) => e.property).sort()).toEqual(['campusLat', 'officeAccount', 'slug']);
  });
});
