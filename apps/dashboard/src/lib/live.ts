import { useQueryClient } from '@tanstack/react-query';
import { io, type Socket } from 'socket.io-client';
import { useEffect, useState } from 'react';
import { API_URL, loadSession } from './api';

/** Socket.IO `/live` namespace behind the same `/api` prefix as the REST API. */
export function liveSocket(): Socket {
  const base = new URL(API_URL, window.location.origin);
  const prefix = base.pathname.replace(/\/$/, '');
  return io(`${base.origin}/live`, {
    path: `${prefix}/socket.io`,
    auth: (cb) => cb({ token: loadSession()?.accessToken ?? '' }),
    // WebSocket only, like the phone apps: works across API worker processes without sticky sessions.
    transports: ['websocket'],
    reconnectionDelayMax: 5000,
  });
}

export interface BusPosition {
  runId: string;
  lat: number;
  lng: number;
  at: string;
  speed: number | null;
  heading: number | null;
  etas: { seq: number; seconds: number }[];
}

/**
 * Live positions for the office (TO-07). Starts from the REST snapshot, then applies socket
 * events; run status changes refresh the snapshot.
 */
export function useLiveFeed(initial: Record<string, BusPosition | null> | undefined, queryKey: unknown[]) {
  const qc = useQueryClient();
  const [buses, setBuses] = useState<Record<string, BusPosition>>({});
  const [connected, setConnected] = useState(false);

  useEffect(() => {
    if (!initial) return;
    setBuses((cur) => {
      const next = { ...cur };
      for (const [id, pos] of Object.entries(initial)) if (pos && (!next[id] || Date.parse(pos.at) > Date.parse(next[id].at))) next[id] = pos;
      return next;
    });
  }, [initial]);

  useEffect(() => {
    const s = liveSocket();
    s.on('connect', () => setConnected(true));
    s.on('disconnect', () => setConnected(false));
    s.on('bus', (p: BusPosition) => setBuses((cur) => ({ ...cur, [p.runId]: p })));
    const refresh = () => qc.invalidateQueries({ queryKey });
    // A status change carries everything the list shows: apply it at once, then reconcile with
    // the server a little later (its snapshot is cached for a few seconds under load).
    let later: ReturnType<typeof setTimeout> | undefined;
    s.on('run', (e: RunStatusEvent) => {
      qc.setQueryData(queryKey, (old: unknown) => (Array.isArray(old) ? old.map((r) => (r?.runId === e.runId ? applyRunStatus(r, e) : r)) : old));
      clearTimeout(later);
      later = setTimeout(refresh, 6000);
    });
    s.on('run:updated', refresh);
    return () => {
      clearTimeout(later);
      s.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return { buses, connected };
}

export interface RunStatusEvent {
  runId: string;
  status: string;
  /** Stop number (1-based) the bus arrived at or left. */
  seq?: number | null;
}

/** The live-ops row after a run status event: new status, and the stop it reached or left. */
export function applyRunStatus<T extends { status: string; stops?: { seq: number; arrived: boolean; served: boolean }[] }>(run: T, e: RunStatusEvent): T {
  const stops = run.stops?.map((st) =>
    e.seq != null && st.seq === e.seq ? { ...st, arrived: true, served: st.served || (run.status === 'at_stop' && e.status !== 'at_stop') } : st,
  );
  return { ...run, status: e.status || run.status, ...(stops ? { stops } : {}) };
}

/** Re-render every `ms` (for "updated 12 s ago" labels). */
export function useNow(ms = 1000) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), ms);
    return () => clearInterval(t);
  }, [ms]);
  return now;
}

/** "Updated … ago" in the largest whole unit, so a bus silent for days does not read "2543081 s". */
export function agoParts(seconds: number): { key: 'live.updatedAgo' | 'live.updatedAgoMin' | 'live.updatedAgoHour' | 'live.updatedAgoDay'; n: number } {
  const s = Math.max(0, Math.floor(seconds));
  if (s < 60) return { key: 'live.updatedAgo', n: s };
  if (s < 3600) return { key: 'live.updatedAgoMin', n: Math.floor(s / 60) };
  if (s < 86400) return { key: 'live.updatedAgoHour', n: Math.floor(s / 3600) };
  return { key: 'live.updatedAgoDay', n: Math.floor(s / 86400) };
}
