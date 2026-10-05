import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from './api';

const post = (body: unknown, method = 'POST') => ({ method, body: JSON.stringify(body) });

// ── TO-08 manual overrides ─────────────────────────────────────────────────────

export function useMoveStudent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (b: { requestId: string; runId: string }) => api<{ toRunId: string }>('/dispatch/move', post(b)),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['dispatch'] }),
  });
}

export interface FreeDriver {
  id: string;
  name: string;
  plate: string | null;
  seats: number;
  offered: boolean;
}
export const useFreeDrivers = (waveId: string, date: string, enabled: boolean) =>
  useQuery({ queryKey: ['free-drivers', waveId, date], queryFn: () => api<FreeDriver[]>(`/dispatch/free-drivers?waveId=${waveId}&date=${date}`), enabled });

export function useExtraRun() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (b: { waveId: string; date: string; driverId: string; gender: 'male' | 'female' }) => api<{ runId: string; placed: number }>('/dispatch/extra-run', post(b)),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['dispatch'] });
      qc.invalidateQueries({ queryKey: ['free-drivers'] });
    },
  });
}

// ── TO-10 reports ──────────────────────────────────────────────────────────────

export interface Rate {
  value: number | null;
  num: number;
  den: number;
}
export interface Report {
  month: string;
  tierId: string | null;
  subscribers: number;
  requests: number;
  served: number;
  fulfilment: Rate;
  onTime: Rate;
  waitlistExpiry: Rate;
  renewal: Rate;
  runs: number;
  revenue: number;
  tiers: { tierId: string; name: string; subscribers: number; subscriptions: number; cash: number; revenue: number }[];
}
export const useReport = (month: string, tierId: string) =>
  useQuery({ queryKey: ['report', month, tierId], queryFn: () => api<Report>(`/reports?month=${month}${tierId ? `&tierId=${tierId}` : ''}`) });

// ── ST-11 inbox ────────────────────────────────────────────────────────────────

export interface Problem {
  id: string;
  category: 'late' | 'driver' | 'vehicle' | 'safety' | 'app' | 'other';
  text: string;
  status: 'open' | 'resolved';
  reply: string | null;
  createdAt: string;
  resolvedAt: string | null;
  student: { name: string; nameAr: string | null; studentId: string | null; phone: string | null };
  ride: { date: string; waveType: 'morning' | 'return'; waveTime: string; driverName: string | null } | null;
}
export const useProblems = (status: '' | 'open' | 'resolved') => useQuery({ queryKey: ['problems', status], queryFn: () => api<Problem[]>(`/inbox/problems${status ? `?status=${status}` : ''}`) });

export function useResolveProblem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, reply }: { id: string; reply: string }) => api(`/problems/${id}`, post({ reply }, 'PATCH')),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['problems'] }),
  });
}

export interface Ratings {
  drivers: { driverId: string; name: string; average: number; count: number }[];
  recent: { id: string; stars: number; comment: string | null; createdAt: string; driver: string; student: string }[];
}
export const useRatings = () => useQuery({ queryKey: ['ratings'], queryFn: () => api<Ratings>('/inbox/ratings') });

// ── TO-11 announcements ────────────────────────────────────────────────────────

export interface AnnouncementInput {
  title: string;
  body: string;
  target: 'all' | 'wave' | 'point';
  waveId?: string;
  date?: string;
  pointId?: string;
  days?: number;
}
export interface Announcement {
  id: string;
  title: string;
  body: string;
  target: 'all' | 'wave' | 'point';
  date: string | null;
  recipients: number;
  createdAt: string;
  expiresAt: string;
  wave: { type: 'morning' | 'return'; time: string } | null;
  point: { name: string; nameAr: string | null } | null;
}
export const useAnnouncements = () => useQuery({ queryKey: ['announcements'], queryFn: () => api<Announcement[]>('/announcements') });
export const previewAnnouncement = (b: AnnouncementInput) => api<{ recipients: number }>('/announcements/preview', post(b));

export function useAnnounce() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (b: AnnouncementInput) => api<Announcement>('/announcements', post(b)),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['announcements'] }),
  });
}
