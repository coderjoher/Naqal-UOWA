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
    transports: ['websocket', 'polling'],
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
    s.on('run', refresh);
    s.on('run:updated', refresh);
    return () => {
      s.disconnect();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return { buses, connected };
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
