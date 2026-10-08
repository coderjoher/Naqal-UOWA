import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';
import { api } from './api';
import { liveSocket } from './live';

export type TaxiStatus = 'requested' | 'accepted' | 'arrived' | 'on_trip' | 'done' | 'cancelled' | 'expired';

export interface TaxiSettings {
  taxiEnabled: boolean;
  taxiBaseFare: number;
  taxiPerKm: number;
  taxiMinFare: number;
  taxiOfferSeconds: number;
}

export interface TaxiRideRow {
  id: string;
  status: TaxiStatus;
  direction: 'to_campus' | 'from_campus';
  label: string | null;
  distanceKm: number;
  fare: number;
  createdAt: string;
  acceptedAt: string | null;
  endedAt: string | null;
  cancelledBy: string | null;
  student: string;
  driver: string | null;
  plate: string | null;
}

export interface OnlineTaxi {
  driverId: string;
  name: string;
  plate: string | null;
  lat: number;
  lng: number;
  at: string;
  busy: boolean;
}

export interface TaxiOverview {
  date: string;
  kpis: { requested: number; done: number; active: number; unserved: number; cash: number; avgAcceptSec: number | null; online: number };
  online: OnlineTaxi[];
  rides: TaxiRideRow[];
}

export const useTaxiSettings = () => useQuery({ queryKey: ['taxi-settings'], queryFn: () => api<TaxiSettings>('/taxi/settings') });

export function useSaveTaxiSettings() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body: Partial<TaxiSettings>) => api<TaxiSettings>('/taxi/settings', { method: 'PATCH', body: JSON.stringify(body) }),
    onSuccess: (data) => {
      qc.setQueryData(['taxi-settings'], data);
      void qc.invalidateQueries({ queryKey: ['taxi-overview'] });
    },
  });
}

/** TX-06: today's rides and online taxis. Refreshed by ride events, and every 15 s for positions. */
export function useTaxiOverview(date?: string) {
  const qc = useQueryClient();
  const key = ['taxi-overview', date ?? 'today'];
  useEffect(() => {
    const s = liveSocket();
    let t: ReturnType<typeof setTimeout> | undefined;
    s.on('taxi:ride', () => {
      clearTimeout(t);
      t = setTimeout(() => void qc.invalidateQueries({ queryKey: ['taxi-overview'] }), 300);
    });
    return () => {
      clearTimeout(t);
      s.disconnect();
    };
  }, [qc]);
  return useQuery({ queryKey: key, queryFn: () => api<TaxiOverview>(`/taxi/overview${date ? `?date=${date}` : ''}`), refetchInterval: 15_000 });
}

/** Same rule as the API (TX-03): base + per km, at least the minimum, rounded up to 250 IQD. */
export function previewFare(km: number, s: Pick<TaxiSettings, 'taxiBaseFare' | 'taxiPerKm' | 'taxiMinFare'>) {
  const raw = Math.max(s.taxiMinFare, s.taxiBaseFare + Math.ceil(Math.max(0, km) * s.taxiPerKm));
  return Math.ceil(raw / 250) * 250;
}
