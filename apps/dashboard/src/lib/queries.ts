import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, API_URL, ApiError, loadSession, type Role } from './api';

export interface University {
  id: string;
  name: string;
  nameAr: string | null;
  slug: string;
  campusLat: number;
  campusLng: number;
  coverage: [number, number][];
  commissionPct: string;
  waitlistMinutes: number;
}
export interface User {
  id: string;
  name: string;
  email: string | null;
  role: Role;
  status: 'active' | 'suspended';
}
export interface Tier {
  id: string;
  name: string;
  minKm: number;
  maxKm: number | null;
  subscriptionPrice: number;
  ridePrice: number;
}
export interface Point {
  id: string;
  name: string;
  nameAr: string | null;
  lat: number;
  lng: number;
  tierId: string;
  tierOverridden: boolean;
  distanceKm: number | null;
  durationMin: number | null;
  active: boolean;
  tier?: { id: string; name: string };
}
export interface Wave {
  id: string;
  type: 'morning' | 'return';
  time: string;
  minuteOfDay: number;
  weekdays: number;
  active: boolean;
}
export interface DocRequirement {
  key: string;
  label: string;
  labelAr?: string;
  required: boolean;
}
export interface DriverRequirements {
  documents: DocRequirement[];
  vehicleTypes: string[];
  minSeats: number;
  maxVehicleAgeYears: number;
}

const json = (body: unknown, method = 'POST') => ({ method, body: JSON.stringify(body) });

export const useUniversities = () => useQuery({ queryKey: ['universities'], queryFn: () => api<University[]>('/universities') });
export const useCurrentUniversity = (enabled = true) => useQuery({ queryKey: ['university'], queryFn: () => api<University>('/universities/current'), enabled });
export const useUsers = () => useQuery({ queryKey: ['users'], queryFn: () => api<User[]>('/users') });
export const useTiers = () => useQuery({ queryKey: ['tiers'], queryFn: () => api<Tier[]>('/tiers') });
export const usePoints = () => useQuery({ queryKey: ['points'], queryFn: () => api<Point[]>('/gathering-points') });
export const useWaves = () => useQuery({ queryKey: ['waves'], queryFn: () => api<Wave[]>('/waves') });
export const useRequirements = () => useQuery({ queryKey: ['requirements'], queryFn: () => api<DriverRequirements>('/driver-requirements') });

/** Mutation that refreshes the given queries on success. */
function useSave<TVars, TResult = unknown>(fn: (v: TVars) => Promise<TResult>, invalidate: string[][]) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: fn,
    onSuccess: () => Promise.all(invalidate.map((queryKey) => qc.invalidateQueries({ queryKey }))),
  });
}

export const useCreateUniversity = () => useSave((body: object) => api<University>('/universities', json(body)), [['universities']]);
export const useUpdateUniversity = () =>
  useSave(({ id, ...body }: { id: string } & Record<string, unknown>) => api<University>(`/universities/${id}`, json(body, 'PATCH')), [['universities']]);
export type TierInput = Omit<Tier, 'id'> & { id?: string };
export const useSaveTiers = () => useSave((tiers: TierInput[]) => api<Tier[]>('/tiers', json({ tiers }, 'PUT')), [['tiers'], ['points']]);
export const useCreatePoint = () => useSave((body: object) => api<Point>('/gathering-points', json(body)), [['points']]);
export const useUpdatePoint = () => useSave(({ id, ...body }: { id: string } & Record<string, unknown>) => api<Point>(`/gathering-points/${id}`, json(body, 'PATCH')), [['points']]);
export const useCreateWave = () => useSave((body: object) => api<Wave>('/waves', json(body)), [['waves']]);
export const useUpdateWave = () => useSave(({ id, ...body }: { id: string } & Record<string, unknown>) => api<Wave>(`/waves/${id}`, json(body, 'PATCH')), [['waves']]);
export const useSaveRequirements = () => useSave((body: DriverRequirements) => api<DriverRequirements>('/driver-requirements', json(body, 'PUT')), [['requirements']]);

/** Server validation messages (Nest returns `message: string | string[]`). */
export function errorMessages(e: unknown): string[] {
  if (e instanceof ApiError) return e.messages;
  return [];
}

export type DriverStatus = 'draft' | 'pending' | 'approved' | 'rejected' | 'suspended';
export interface DriverRow {
  id: string;
  name: string;
  phone: string | null;
  status: DriverStatus;
  vehicleType: string | null;
  plate: string | null;
  seats: number | null;
  modelYear: number | null;
  documents: string[];
  submittedAt: string | null;
  reviewNote: string | null;
}
export interface DriverDetail extends Omit<DriverRow, 'documents'> {
  documents: { key: string; label: string; labelAr?: string; required: boolean; uploaded: boolean; mime: string | null }[];
  missing: string[];
}
export interface RosterStudent {
  id: string;
  studentId: string;
  name: string;
  nameAr: string | null;
  gender: 'male' | 'female';
  activated: boolean;
  activationPending: boolean;
  phone: string | null;
}

export const useDrivers = (enabled = true) => useQuery({ queryKey: ['drivers'], queryFn: () => api<DriverRow[]>('/drivers'), enabled });
export const useDriver = (id: string | null) => useQuery({ queryKey: ['driver', id], queryFn: () => api<DriverDetail>(`/drivers/${id}`), enabled: !!id });
export const useReviewDriver = () =>
  useSave(({ id, action, note }: { id: string; action: 'approve' | 'reject' | 'suspend' | 'reinstate'; note?: string }) => api(`/drivers/${id}/${action}`, json({ note })), [['drivers'], ['driver']]);
export const documentLink = (driverId: string, key: string) => api<{ url: string; expiresAt: string }>(`/drivers/${driverId}/documents/${key}/link`, json({}));

export const useStudents = (enabled = true) => useQuery({ queryKey: ['students'], queryFn: () => api<RosterStudent[]>('/students'), enabled });
export const useImportRoster = () => useSave((rows: { studentId: string; name: string; nameAr?: string; gender: 'male' | 'female' }[]) => api<{ created: number; updated: number }>('/students/roster', json({ rows })), [['students']]);
export const useIssueCode = () => useSave((studentId: string) => api<{ studentId: string; code: string; expiresAt: string }>(`/students/${encodeURIComponent(studentId)}/activation-code`, json({})), [['students']]);

export interface SubscriptionPreview {
  student: { id: string; studentId: string | null; name: string; nameAr: string | null; gender: 'male' | 'female' | null; status: string };
  point: { id: string; name: string; nameAr: string | null; active: boolean } | null;
  tier: { id: string; name: string } | null;
  month: string;
  price: number | null;
  alreadySubscribed: boolean;
}
export interface SubscriptionRow {
  id: string;
  month: string;
  price: number;
  status: 'active' | 'cancelled';
  createdAt: string;
  paymentId: string;
  student: { id: string; name: string; nameAr: string | null; studentId: string | null };
  payment: { receiptNo: number; amount: number; createdAt: string; reversedBy: { id: string } | null };
}

export const subscriptionPreview = (studentId: string, month: string) => api<SubscriptionPreview>(`/subscriptions/preview?studentId=${encodeURIComponent(studentId)}&month=${month}`);
export const useSubscriptions = (month: string) => useQuery({ queryKey: ['subscriptions', month], queryFn: () => api<SubscriptionRow[]>(`/subscriptions?month=${month}`) });
export const useRecordSubscription = () =>
  useSave((body: { studentId: string; month: string }) => api<{ subscription: { id: string }; payment: { id: string; receiptNo: number; amount: number } }>('/subscriptions', json(body)), [['subscriptions']]);
export const useReversePayment = () => useSave(({ id, reason }: { id: string; reason: string }) => api(`/payments/${id}/reverse`, json({ reason })), [['subscriptions']]);

/** Fetches the receipt with the session token and saves it as a file. */
export async function downloadReceipt(paymentId: string, receiptNo: number) {
  const session = loadSession();
  const res = await fetch(`${API_URL}/payments/${paymentId}/receipt.pdf`, { headers: session ? { authorization: `Bearer ${session.accessToken}` } : {} });
  if (!res.ok) throw new ApiError(res.status, res.statusText);
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement('a');
  a.href = url;
  a.download = `receipt-${receiptNo}.pdf`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

export interface DispatchStop {
  seq: number;
  eta: string;
  served: boolean;
  point: { id: string; name: string; nameAr: string | null };
  count: number;
  cashToCollect: number;
  passengers: { requestId: string; name: string; studentId: string | null; fare: number; subscriber: boolean }[];
}
export interface DispatchRun {
  id: string;
  status: string;
  gender: 'male' | 'female';
  femaleOnly: boolean;
  capacity: number;
  booked: number;
  departAt: string | null;
  driverName: string;
  plate: string | null;
  tierName: string | null;
  stops: DispatchStop[];
}
export interface DispatchWave {
  waveId: string;
  type: 'morning' | 'return';
  time: string;
  planned: boolean;
  counts: { open: number; assigned: number; waitlisted: number; cancelled: number };
  runs: DispatchRun[];
  waitlist: { id: string; status: 'open' | 'waitlisted'; name: string; studentId: string | null; gender: 'male' | 'female'; point: string; subscriber: boolean; until: string | null }[];
}

/** Operations board; refreshes every 5 s so planning and re-checks show up without reloading. */
export const useDispatch = (date: string) => useQuery({ queryKey: ['dispatch', date], queryFn: () => api<DispatchWave[]>(`/dispatch?date=${date}`), refetchInterval: 5000 });
export const usePlanWave = () => useSave((body: { waveId: string; date: string }) => api<{ queued: boolean }>('/dispatch/plan', json(body)), [['dispatch']]);

export type RunStatus = 'planned' | 'started' | 'at_stop' | 'done' | 'cancelled';
export interface LiveRun {
  runId: string;
  status: RunStatus;
  wave: { type: 'morning' | 'return'; time: string };
  driverName: string;
  plate: string | null;
  femaleOnly: boolean;
  capacity: number;
  booked: number;
  boarded: number;
  noShows: number;
  stops: { seq: number; name: string; lat: number; lng: number; served: boolean; arrived: boolean }[];
  bus: import('./live').BusPosition | null;
}
export const useLiveRuns = (date: string) => useQuery({ queryKey: ['live-runs', date], queryFn: () => api<LiveRun[]>(`/live/runs?date=${date}`), refetchInterval: 30_000 });
