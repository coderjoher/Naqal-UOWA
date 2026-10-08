import { clsx } from 'clsx';
import { MapPin, Plus, Power } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { lazy, Suspense, useMemo, useState, type FormEvent } from 'react';
import { useI18n } from '../../lib/i18n';
import { errorMessages, useCreatePoint, useCurrentUniversity, usePoints, useTiers, useUpdatePoint, type Point } from '../../lib/queries';
import { Badge, Button, Card, EmptyState, IconButton, Input, PageHeader, Select, Skeleton, SkeletonRows, Stagger, useToast } from '../../ui';
import { itemVariants, listVariants, spring } from '../../ui/motion';
import type { MapMarker } from '../../ui/MapView';
import { Errors } from '../UniversitiesPage';

const MapView = lazy(() => import('../../ui/MapView').then((m) => ({ default: m.MapView })));

interface Draft {
  id?: string;
  lat: number;
  lng: number;
  name: string;
  nameAr: string;
  tierId: string; // '' = automatic
}

export function PointsPage() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const uni = useCurrentUniversity();
  const points = usePoints();
  const tiers = useTiers();
  const create = useCreatePoint();
  const update = useUpdatePoint();
  const [draft, setDraft] = useState<Draft | null>(null);

  const tierName = (id: string) => tiers.data?.find((x) => x.id === id)?.name ?? '?';
  const pointName = (p: Point) => (lang === 'ar' && p.nameAr) || p.name;

  const markers = useMemo<MapMarker[]>(() => {
    if (!uni.data) return [];
    const list: MapMarker[] = [{ id: 'campus', lat: uni.data.campusLat, lng: uni.data.campusLng, label: t('points.campus'), badge: '★', kind: 'campus' }];
    for (const p of points.data ?? []) list.push({ id: p.id, lat: p.lat, lng: p.lng, label: pointName(p), badge: tierName(p.tierId), kind: p.active ? 'point' : 'inactive' });
    if (draft && !draft.id) list.push({ id: 'draft', lat: draft.lat, lng: draft.lng, label: t('points.add'), badge: '+', kind: 'draft' });
    return list;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [uni.data, points.data, tiers.data, draft, lang]);

  const select = (id: string) => {
    const p = points.data?.find((x) => x.id === id);
    if (p) setDraft({ id: p.id, lat: p.lat, lng: p.lng, name: p.name, nameAr: p.nameAr ?? '', tierId: p.tierOverridden ? p.tierId : '' });
  };

  async function submit(e: FormEvent) {
    e.preventDefault();
    if (!draft) return;
    const body = { name: draft.name || draft.nameAr, nameAr: draft.nameAr || undefined, lat: draft.lat, lng: draft.lng };
    try {
      if (draft.id) await update.mutateAsync({ id: draft.id, ...body, tierId: draft.tierId || null });
      else await create.mutateAsync({ ...body, tierId: draft.tierId || undefined });
      toast('success', t('points.saved'));
      setDraft(null);
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  const noTiers = tiers.data && tiers.data.length === 0;
  const busy = create.isPending || update.isPending;
  const error = errorMessages(create.error ?? update.error);

  return (
    <Stagger>
      <PageHeader title={t('points.title')} description={noTiers ? t('points.needTiers') : t('points.desc')} />
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1.6fr)_minmax(0,1fr)]">
        <motion.div variants={itemVariants} className="relative min-h-[520px] overflow-hidden rounded-lg bg-surface shadow-card">
          {uni.data ? (
            <Suspense fallback={<Skeleton className="absolute inset-0" />}>
              <MapView
                className="absolute inset-0"
                label={t('points.title')}
                center={{ lat: uni.data.campusLat, lng: uni.data.campusLng }}
                markers={markers}
                selectedId={draft?.id ?? (draft ? 'draft' : null)}
                onSelect={(id) => id !== 'campus' && id !== 'draft' && select(id)}
                onPick={noTiers ? undefined : (p) => setDraft((d) => (d && !d.id ? { ...d, ...p } : { ...p, name: '', nameAr: '', tierId: '' }))}
              />
            </Suspense>
          ) : (
            <Skeleton className="absolute inset-0" />
          )}
          <AnimatePresence>
            {!draft && !noTiers ? (
              <motion.p
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0 }}
                className="pointer-events-none absolute top-4 start-4 flex items-center gap-2 rounded-pill bg-ink px-4 py-2 text-caption text-on-ink"
              >
                <Plus className="size-4" aria-hidden /> {t('points.clickMap')}
              </motion.p>
            ) : null}
          </AnimatePresence>
        </motion.div>

        <div className="flex min-w-0 flex-col gap-6">
          <AnimatePresence mode="popLayout">
            {draft ? (
              <motion.div key={draft.id ?? 'new'} initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }} transition={spring}>
                <Card title={draft.id ? pointName(points.data!.find((p) => p.id === draft.id)!) : t('points.add')}>
                  <form onSubmit={submit} className="flex flex-col gap-4">
                    <Errors messages={error} />
                    <Input id="point-name-ar" label={t('points.nameAr')} value={draft.nameAr} onChange={(e) => setDraft({ ...draft, nameAr: e.target.value })} required />
                    <Input id="point-name" label={t('points.name')} dir="ltr" value={draft.name} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
                    <Select id="point-tier" label={t('points.tier')} value={draft.tierId} onChange={(e) => setDraft({ ...draft, tierId: e.target.value })}>
                      <option value="">{t('points.auto')}</option>
                      {tiers.data?.map((x) => (
                        <option key={x.id} value={x.id}>
                          {t('points.override')}: {x.name}
                        </option>
                      ))}
                    </Select>
                    <p className="text-caption text-text-muted" dir="ltr">
                      {t('points.coords')}: {draft.lat.toFixed(5)}, {draft.lng.toFixed(5)}
                    </p>
                    <div className="flex gap-3">
                      <Button type="submit" loading={busy}>
                        {t('common.save')}
                      </Button>
                      <Button variant="secondary" onClick={() => setDraft(null)}>
                        {t('common.cancel')}
                      </Button>
                    </div>
                  </form>
                </Card>
              </motion.div>
            ) : null}
          </AnimatePresence>

          <Card title={t('points.list')} actions={<span className="text-caption text-text-muted tabular">{points.data?.length ?? 0}</span>}>
            {points.isPending ? (
              <SkeletonRows />
            ) : (points.data?.length ?? 0) === 0 ? (
              <EmptyState icon={MapPin} title={t('points.emptyTitle')} message={t('points.emptyBody')} />
            ) : (
              <motion.ul variants={listVariants} initial="hidden" animate="show" className="flex flex-col gap-2">
                {points.data!.map((p) => (
                  <motion.li
                    key={p.id}
                    variants={itemVariants}
                    className={clsx('flex items-center gap-3 rounded-md border p-3 transition-colors duration-200', draft?.id === p.id ? 'border-primary bg-primary-soft' : 'border-border hover:bg-surface-muted')}
                  >
                    <button type="button" onClick={() => select(p.id)} className="flex min-w-0 flex-1 items-center gap-3 text-start">
                      <span className={clsx('grid size-9 shrink-0 place-items-center rounded-pill text-label', p.active ? 'bg-primary text-on-primary' : 'bg-surface-muted text-text-muted')}>{tierName(p.tierId)}</span>
                      <span className="min-w-0">
                        <span className="block truncate text-label">{pointName(p)}</span>
                        <span className="block text-caption text-text-muted tabular">
                          {p.distanceKm ?? '—'} {t('points.km')} · {p.durationMin === null ? '—' : Math.round(p.durationMin)} {t('points.min')}
                          {p.tierOverridden ? ` · ${t('points.override')}` : ''}
                        </span>
                      </span>
                    </button>
                    {p.active ? null : <Badge>{t('points.inactive')}</Badge>}
                    <IconButton
                      icon={Power}
                      tone={p.active ? 'danger' : 'default'}
                      label={p.active ? t('points.deactivate') : t('points.activate')}
                      onClick={() => update.mutateAsync({ id: p.id, active: !p.active }).then(() => toast('success', t('points.saved')))}
                    />
                  </motion.li>
                ))}
              </motion.ul>
            )}
          </Card>
        </div>
      </div>
    </Stagger>
  );
}
