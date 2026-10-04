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
  kind?: 'campus' | 'point' | 'draft' | 'inactive';
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
  const live = useRef<maplibregl.Marker[]>([]);
  const pickRef = useRef(onPick);
  pickRef.current = onPick;

  useEffect(() => {
    if (!el.current) return;
    const m = new maplibregl.Map({ container: el.current, style: STYLE, center: [center.lng, center.lat], zoom: 11.5, attributionControl: { compact: true } });
    m.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');
    m.on('click', (e) => pickRef.current?.({ lat: Number(e.lngLat.lat.toFixed(6)), lng: Number(e.lngLat.lng.toFixed(6)) }));
    map.current = m;
    return () => m.remove();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    const m = map.current;
    if (!m) return;
    live.current.forEach((mk) => mk.remove());
    live.current = markers.map((mk) => {
      const node = document.createElement('button');
      node.type = 'button';
      node.className = `naql-pin naql-pin--${mk.kind ?? 'point'}${mk.id === selectedId ? ' is-selected' : ''}`;
      node.setAttribute('aria-label', mk.label);
      node.title = mk.label;
      node.textContent = mk.badge ?? '';
      node.addEventListener('click', (ev) => {
        ev.stopPropagation();
        onSelect?.(mk.id);
      });
      return new maplibregl.Marker({ element: node, anchor: 'center' }).setLngLat([mk.lng, mk.lat]).addTo(m);
    });
  }, [markers, selectedId, onSelect]);

  // MapLibre forces `position: relative` on its container, so size comes from this wrapper.
  return (
    <div className={className}>
      <div ref={el} role="application" aria-label={label} className="h-full w-full" />
    </div>
  );
}
