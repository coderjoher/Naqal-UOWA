import { DEFAULT_REQUIREMENTS } from '../driver-requirements/requirements.service';
import { editable, missingRequirements, nextStatus } from './driver-rules';

describe('driver review state machine', () => {
  it('[T2-08] pending → approved | rejected; approved ↔ suspended; nothing else', () => {
    expect(nextStatus('pending', 'approve')).toBe('approved');
    expect(nextStatus('pending', 'reject')).toBe('rejected');
    expect(nextStatus('approved', 'suspend')).toBe('suspended');
    expect(nextStatus('suspended', 'reinstate')).toBe('approved');
    expect(nextStatus('draft', 'approve')).toBeNull();
    expect(nextStatus('rejected', 'approve')).toBeNull();
    expect(nextStatus('approved', 'reject')).toBeNull();
    expect(nextStatus('suspended', 'approve')).toBeNull();
    expect(editable('draft') && editable('rejected') && !editable('pending') && !editable('approved')).toBe(true);
  });

  it('[T2-06] lists every missing requirement until the application is complete', () => {
    const empty = { name: null, phone: '+9647701234567', vehicleType: null, plate: null, seats: null, modelYear: null, documentKeys: [] };
    expect(missingRequirements(empty, DEFAULT_REQUIREMENTS, 2026)).toEqual([
      'name', 'vehicle_type', 'plate', 'seats', 'model_year', 'doc_national_id', 'doc_driving_licence', 'doc_vehicle_registration',
    ]);
    const full = { ...empty, name: 'علي', vehicleType: 'coaster', plate: '12345 كربلاء', seats: 20, modelYear: 2018, documentKeys: ['national_id', 'driving_licence', 'vehicle_registration'] };
    expect(missingRequirements(full, DEFAULT_REQUIREMENTS, 2026)).toEqual([]);
    expect(missingRequirements({ ...full, modelYear: 2005 }, DEFAULT_REQUIREMENTS, 2026)).toEqual(['model_year']);
    expect(missingRequirements({ ...full, seats: 8 }, DEFAULT_REQUIREMENTS, 2026)).toEqual(['seats']);
    expect(missingRequirements({ ...full, vehicleType: 'taxi' }, DEFAULT_REQUIREMENTS, 2026)).toEqual(['vehicle_type']);
  });
});
