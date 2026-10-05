import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api, API_URL, ApiError, loadSession } from './api';

export interface SettlementLine {
  driverId: string;
  name: string;
  nameAr: string | null;
  phone: string | null;
  plate: string | null;
  runs: number;
  cash: number;
  cashCommission: number;
  payout: number;
}
export interface Settlement {
  id: string;
  month: string;
  status: 'draft' | 'approved';
  commissionPct: number;
  tiers: { tierId: string; name: string; pool: number; runs: number; commission: number }[];
  totals: { pool: number; payout: number; commission: number; cash: number; unallocated: number; residual: number };
  excludedRuns: number;
  computedAt: string;
  approvedAt: string | null;
  lines: SettlementLine[];
}
export interface ReviewRun {
  id: string;
  date: string;
  waveType: 'morning' | 'return';
  waveMinute: number;
  driver: string;
  status: string;
  gpsVerified: boolean | null;
  flags: string[];
  officeVerdict: boolean | null;
  officeNote: string | null;
  counted: boolean;
  positions: number;
  stops: number;
}

export const useSettlement = (month: string) =>
  useQuery({ queryKey: ['settlement', month], queryFn: () => api<{ settlement: Settlement | null; review: ReviewRun[] }>(`/settlements/${month}`) });

export function useSettlementAction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ month, action }: { month: string; action: 'compute' | 'approve' }) => api<Settlement>(`/settlements/${month}/${action}`, { method: 'POST' }),
    onSuccess: (_d, v) => qc.invalidateQueries({ queryKey: ['settlement', v.month] }),
  });
}

export function useRunVerdict(month: string) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ runId, verdict, note }: { runId: string; verdict: boolean | null; note?: string }) => api(`/runs/${runId}/verdict`, { method: 'PATCH', body: JSON.stringify({ verdict, note }) }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['settlement', month] }),
  });
}

/** Authenticated download of a file the API generates (PDF, XLSX). */
export async function downloadFile(path: string, filename: string) {
  const session = loadSession();
  const res = await fetch(`${API_URL}${path}`, { headers: session ? { authorization: `Bearer ${session.accessToken}` } : {} });
  if (!res.ok) throw new ApiError(res.status, res.statusText);
  const url = URL.createObjectURL(await res.blob());
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 10_000);
}

export interface AuditRow {
  id: string;
  universityId: string | null;
  actorId: string;
  action: string;
  entity: string;
  entityId: string | null;
  payload: { before?: Record<string, unknown> | null; after?: Record<string, unknown> | null } | Record<string, unknown> | null;
  createdAt: string;
  actor: { id: string; name: string; nameAr: string | null; role: string } | null;
}

export const useAudit = (filter: { entity?: string; from?: string; to?: string; actorId?: string }) =>
  useQuery({
    queryKey: ['audit', filter],
    queryFn: () => {
      const q = new URLSearchParams(Object.entries(filter).filter(([, v]) => v) as [string, string][]);
      return api<{ items: AuditRow[]; next: string | null }>(`/audit?${q}`);
    },
  });

export const useAuditEntities = () => useQuery({ queryKey: ['audit-entities'], queryFn: () => api<string[]>('/audit/entities') });

export interface UniversityMonth {
  universityId: string;
  name: string;
  commissionPct: number;
  revenue: { subscriptions: number; cashFares: number; tierDifference: number; total: number };
  commission: number;
  payout: number;
  settlement: 'approved' | 'draft' | 'estimate';
  subscribers: number;
  requests: number;
  fulfilment: number | null;
  runs: number;
}
export interface PlatformOverview {
  month: string;
  universities: UniversityMonth[];
  totals: { revenue: number; subscriptions: number; cashFares: number; commission: number; payout: number; subscribers: number; runs: number; requests: number; fulfilment: number | null };
}

export const usePlatformOverview = (month: string) => useQuery({ queryKey: ['platform-overview', month], queryFn: () => api<PlatformOverview>(`/admin/overview?month=${month}`) });

export const baghdadMonth = (offset = 0) => {
  const d = new Date(Date.now() + 3 * 3600_000);
  const m = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + offset, 1));
  return `${m.getUTCFullYear()}-${String(m.getUTCMonth() + 1).padStart(2, '0')}`;
};
