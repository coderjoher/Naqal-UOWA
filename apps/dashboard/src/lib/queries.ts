import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, ApiError, type Role } from './api';

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
