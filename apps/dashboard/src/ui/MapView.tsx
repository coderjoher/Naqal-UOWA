import 'maplibre-gl/dist/maplibre-gl.css';
import maplibregl from 'maplibre-gl';
import { useEffect, useRef } from 'react';

export interface MapMarker {
  id: string;
  lat: number;
  lng: number;
  label: string;
  /** Short text inside the pin (e.g. tier letter). */
  badge?: string;
  kind?: 'campus' | 'point' | 'draft' | 'inactive' | 'bus' | 'bus-female' | 'stop' | 'stop-done';
}

const BUS_SVG =
  '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 6 2 7"/><path d="M10 6h4"/><path d="m22 7-2-1"/><rect width="16" height="16" x="4" y="3" rx="2"/><path d="M4 11h16"/><path d="M8 15h.01"/><path d="M16 15h.01"/><path d="M6 19v2"/><path d="M18 21v-2"/></svg>';

/** Moves a marker to a new position over `ms` (buses glide instead of jumping every ping). */
function glide(marker: maplibregl.Marker, to: [number, number], ms = 900) {
  const from = marker.getLngLat();
  if (Math.abs(from.lng - to[0]) < 1e-7 && Math.abs(from.lat - to[1]) < 1e-7) return;
  const reduce = typeof window.matchMedia === 'function' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (reduce) return void marker.setLngLat(to);
  const start = performance.now();
  const step = (t: number) => {
    const k = Math.min(1, (t - start) / ms);
    const e = 1 - (1 - k) ** 3;
    marker.setLngLat([from.lng + (to[0] - from.lng) * e, from.lat + (to[1] - from.lat) * e]);
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

/** Muted light basemap (CARTO Positron raster) so markers stand out; no labels clutter. */
const STYLE: maplibregl.StyleSpecification = {
  version: 8,
  sources: {
    base: {
      type: 'raster',
      tiles: ['a', 'b', 'c', 'd'].map((s) => `https://${s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png`),
      tileSize: 256,
      attribution: '© OpenStreetMap contributors © CARTO',
    },
  },
  layers: [{ id: 'base', type: 'raster', source: 'base' }],
};

export function MapView({
  center,
  markers,
  onPick,
  selectedId,
  onSelect,
  className,
  label,
}: {
  center: { lat: number; lng: number };
  markers: MapMarker[];
  onPick?: (p: { lat: number; lng: number }) => void;
  selectedId?: string | null;
  onSelect?: (id: string) => void;
  className?: string;
  label: string;
}) {
  const el = useRef<HTMLDivElement>(null);
  const map = useRef<maplibregl.Map | null>(null);
  const live = useRef(new Map<string, maplibregl.Marker>());
  const selectRef = useRef(onSelect);
  selectRef.current = onSelect;
  const pickRef = useRef(onPick);
  pickRef.current = onPick;

  useEffect(() => {
    if (!el.current) return;
    const m = new maplibregl.Map({ container: el.current, style: STYLE, center: [center.lng, center.lat], zoom: 11.5, attributionControl: { compact: true } });
    m.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');
    m.on('click', (e) => pickRef.current?.({ lat: Number(e.lngLat.lat.toFixed(6)), lng: Number(e.lngLat.lng.toFixed(6)) }));
    map.current = m;
    const markers = live.current;
    return () => {
      // Markers belong to this map instance; forget them so a remount (StrictMode) re-adds them.
      markers.forEach((mk) => mk.remove());
      markers.clear();
      m.remove();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Markers are kept by id and updated in place, so live positions move smoothly.
  useEffect(() => {
    const m = map.current;
    if (!m) return;
    const seen = new Set<string>();
    for (const mk of markers) {
      seen.add(mk.id);
      const isBus = mk.kind === 'bus' || mk.kind === 'bus-female';
      const cls = `naql-pin naql-pin--${mk.kind ?? 'point'}${mk.id === selectedId ? ' is-selected' : ''}`;
      const existing = live.current.get(mk.id);
      if (existing) {
        const node = existing.getElement();
        // Keep MapLibre's own marker classes (they position the element); swap only ours.
        node.classList.remove(...[...node.classList].filter((c) => c.startsWith('naql-pin') || c === 'is-selected'));
        node.classList.add(...cls.split(' '));
        node.setAttribute('aria-label', mk.label);
        node.title = mk.label;
        if (!isBus) node.textContent = mk.badge ?? '';
        glide(existing, [mk.lng, mk.lat], isBus ? 900 : 0);
        continue;
      }
      const node = document.createElement('button');
      node.type = 'button';
      node.className = cls;
      node.setAttribute('aria-label', mk.label);
      node.title = mk.label;
      if (isBus) node.innerHTML = BUS_SVG;
      else node.textContent = mk.badge ?? '';
      node.dataset.markerId = mk.id;
      node.addEventListener('click', (ev) => {
        ev.stopPropagation();
        selectRef.current?.(mk.id);
      });
      live.current.set(mk.id, new maplibregl.Marker({ element: node, anchor: 'center' }).setLngLat([mk.lng, mk.lat]).addTo(m));
    }
    for (const [id, mk] of live.current) {
      if (!seen.has(id)) {
        mk.remove();
        live.current.delete(id);
      }
    }
  }, [markers, selectedId]);

  // MapLibre forces `position: relative` on its container, so size comes from this wrapper.
  return (
    <div className={className}>
      <div ref={el} role="application" aria-label={label} className="h-full w-full" />
    </div>
  );
}
