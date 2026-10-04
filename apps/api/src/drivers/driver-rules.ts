import type { DriverRequirementsDto } from '../driver-requirements/requirements.dto';

export type DriverStatus = 'draft' | 'pending' | 'approved' | 'rejected' | 'suspended';
export type ReviewAction = 'approve' | 'reject' | 'suspend' | 'reinstate';

/** Office review transitions (TO-02). */
const TRANSITIONS: Record<ReviewAction, { from: DriverStatus[]; to: DriverStatus }> = {
  approve: { from: ['pending'], to: 'approved' },
  reject: { from: ['pending'], to: 'rejected' },
  suspend: { from: ['approved'], to: 'suspended' },
  reinstate: { from: ['suspended'], to: 'approved' },
};

export function nextStatus(current: DriverStatus, action: ReviewAction): DriverStatus | null {
  const t = TRANSITIONS[action];
  return t.from.includes(current) ? t.to : null;
}

/** The driver can edit and (re)submit only before review or after a rejection. */
export const editable = (s: DriverStatus) => s === 'draft' || s === 'rejected';

export interface Application {
  name: string | null;
  phone: string | null;
  vehicleType: string | null;
  plate: string | null;
  seats: number | null;
  modelYear: number | null;
  documentKeys: string[];
}

/** Everything the office requires (TO-01) that is still missing or invalid (DR-01). Empty = complete. */
export function missingRequirements(app: Application, req: DriverRequirementsDto, year = new Date().getFullYear()): string[] {
  const missing: string[] = [];
  if (!app.name?.trim()) missing.push('name');
  if (!app.phone) missing.push('phone');
  if (!app.vehicleType || !req.vehicleTypes.includes(app.vehicleType)) missing.push('vehicle_type');
  if (!app.plate?.trim()) missing.push('plate');
  if (!app.seats || app.seats < req.minSeats) missing.push('seats');
  if (!app.modelYear || app.modelYear < year - req.maxVehicleAgeYears || app.modelYear > year + 1) missing.push('model_year');
  for (const d of req.documents) if (d.required && !app.documentKeys.includes(d.key)) missing.push(`doc_${d.key}`);
  return missing;
}
