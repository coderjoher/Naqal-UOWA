import { clsx } from 'clsx';
import { CarTaxiFront, CircleCheck, Clock, HandCoins, Hourglass, Navigation, Power, Timer } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { lazy, Suspense, useEffect, useMemo, useState } from 'react';
import { useI18n, useMoney, type MessageKey } from '../lib/i18n';
import { agoParts, useNow } from '../lib/live';
import { errorMessages, useCurrentUniversity } from '../lib/queries';
import { previewFare, useSaveTaxiSettings, useTaxiOverview, useTaxiSettings, type TaxiSettings, type TaxiStatus } from '../lib/taxi';
import { AnimatedNumber, Badge, Button, Card, EmptyState, Input, PageHeader, SkeletonRows, Stagger, Table, useToast } from '../ui';
import type { MapMarker } from '../ui/MapView';
import { spring } from '../ui/motion';
import { Errors } from './UniversitiesPage';

const MapView = lazy(() => import('../ui/MapView').then((m) => ({ default: m.MapView })));

const TONE: Record<TaxiStatus, 'neutral' | 'primary' | 'success' | 'warning' | 'danger'> = {
  requested: 'warning',
  accepted: 'primary',
  arrived: 'primary',
  on_trip: 'primary',
  done: 'success',
  cancelled: 'neutral',
  expired: 'danger',
};
const SAMPLE_KM = [3, 6, 10, 15];
const time = (iso: string) => new Date(iso).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Baghdad' });

/** P10 / TX-06: campus taxis — tariff and switch, who is online, and today's rides. */
export function TaxiPage() {
  const { t } = useI18n();
  const money = useMoney();
  const uni = useCurrentUniversity();
  const overview = useTaxiOverview();
  const settings = useTaxiSettings();
  const [selected, setSelected] = useState<string | null>(null);
  const now = useNow(5000);
  const k = overview.data?.kpis;
  const online = overview.data?.online ?? [];
  const rides = overview.data?.rides ?? [];

  const markers = useMemo<MapMarker[]>(() => {
    const out: MapMarker[] = [];
    if (uni.data) out.push({ id: 'campus', lat: uni.data.campusLat, lng: uni.data.campusLng, label: t('live.campus'), kind: 'campus' });
    for (const o of online) out.push({ id: o.driverId, lat: o.lat, lng: o.lng, label: `${o.name} · ${o.plate ?? ''} · ${t(o.busy ? 'taxi.busy' : 'taxi.free')}`, kind: o.busy ? 'taxi-busy' : 'taxi' });
    return out;
  }, [uni.data, online, t]);

  return (
    <Stagger className="flex flex-col gap-6">
      <PageHeader
        title={t('taxi.title')}
        description={t('taxi.desc')}
        actions={settings.data ? <ServiceSwitch settings={settings.data} /> : null}
      />

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Kpi icon={CarTaxiFront} label={t('taxi.kpi.online')} value={k?.online ?? 0} tone="warning" />
        <Kpi icon={Navigation} label={t('taxi.kpi.active')} value={k?.active ?? 0} tone="primary" />
        <Kpi icon={CircleCheck} label={t('taxi.kpi.done')} value={k?.done ?? 0} tone="success" />
        <Kpi icon={Hourglass} label={t('taxi.kpi.unserved')} value={k?.unserved ?? 0} tone="danger" />
        <Kpi icon={HandCoins} label={t('taxi.kpi.cash')} value={k?.cash ?? 0} tone="success" format={(n) => money(n)} />
        <Kpi icon={Timer} label={t('taxi.kpi.accept')} value={k?.avgAcceptSec ?? 0} tone="primary" format={(n) => (k?.avgAcceptSec == null ? '—' : n < 60 ? t('taxi.sec', { n }) : t('taxi.min', { n: Math.round(n / 60) }))} />
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <Card className="overflow-hidden p-0">
          {uni.data ? (
            <Suspense fallback={<div className="h-[460px] animate-pulse bg-surface-muted" />}>
              <MapView
                className="h-[460px]"
                label={t('taxi.map')}
                center={{ lat: uni.data.campusLat, lng: uni.data.campusLng }}
                markers={markers}
                selectedId={selected}
                onSelect={(id: string) => (id === 'campus' ? null : setSelected(id === selected ? null : id))}
              />
            </Suspense>
          ) : (
            <div className="h-[460px] animate-pulse bg-surface-muted" />
          )}
        </Card>

        <Card title={t('taxi.onlineTitle')} description={t('taxi.onlineHint')}>
          {overview.isLoading ? (
            <SkeletonRows rows={3} />
          ) : online.length === 0 ? (
            <EmptyState icon={CarTaxiFront} title={t('taxi.noneOnline')} message={t('taxi.noneOnlineHint')} />
          ) : (
            <ul className="-mx-2 flex max-h-[360px] flex-col gap-1 overflow-y-auto">
              <AnimatePresence initial={false}>
                {online.map((o) => {
                  const ago = agoParts((now - Date.parse(o.at)) / 1000);
                  return (
                    <motion.li key={o.driverId} layout initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={spring}>
                      <button
                        type="button"
                        onClick={() => setSelected(o.driverId === selected ? null : o.driverId)}
                        aria-pressed={o.driverId === selected}
                        className={clsx(
                          'flex min-h-12 w-full items-center gap-3 rounded-md px-2 py-2 text-start transition-colors duration-200',
                          o.driverId === selected ? 'bg-primary-soft' : 'hover:bg-surface-muted',
                        )}
                      >
                        <span className={clsx('grid size-9 shrink-0 place-items-center rounded-md', o.busy ? 'bg-ink text-surface' : 'bg-warning-soft text-warning')} aria-hidden>
                          <CarTaxiFront size={18} />
                        </span>
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-label">{o.name}</span>
                          <span className="block truncate text-caption text-text-muted">
                            {o.plate ?? '—'} · {t(ago.key, { n: ago.n })}
                          </span>
                        </span>
                        <Badge tone={o.busy ? 'primary' : 'success'}>{t(o.busy ? 'taxi.busy' : 'taxi.free')}</Badge>
                      </button>
                    </motion.li>
                  );
                })}
              </AnimatePresence>
            </ul>
          )}
        </Card>
      </div>

      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_360px]">
        <Card title={t('taxi.ridesTitle')} description={t('taxi.ridesHint')}>
          {overview.isLoading ? (
            <SkeletonRows />
          ) : (
            <Table
              caption={t('taxi.ridesTitle')}
              rows={rides}
              rowKey={(r) => r.id}
              empty={<EmptyState icon={Clock} title={t('taxi.noRides')} message={t('taxi.noRidesHint')} />}
              columns={[
                { key: 'time', header: t('taxi.col.time'), cell: (r) => <span className="tabular" dir="ltr">{time(r.createdAt)}</span> },
                { key: 'student', header: t('taxi.col.student'), cell: (r) => <span className="text-label">{r.student}</span> },
                {
                  key: 'dir',
                  header: t('taxi.col.trip'),
                  cell: (r) => (
                    <span className="flex flex-col">
                      <span>{t(r.direction === 'to_campus' ? 'taxi.toCampus' : 'taxi.fromCampus')}</span>
                      <span className="text-caption text-text-muted">
                        <span dir="ltr">{r.distanceKm.toFixed(1)}</span> {t('taxi.km')}
                        {r.label ? ` · ${r.label}` : ''}
                      </span>
                    </span>
                  ),
                },
                { key: 'fare', header: t('taxi.col.fare'), cell: (r) => <span className="tabular">{money(r.fare)}</span> },
                { key: 'driver', header: t('taxi.col.driver'), cell: (r) => (r.driver ? <span className="flex flex-col"><span>{r.driver}</span><span className="text-caption text-text-muted">{r.plate}</span></span> : <span className="text-text-muted">—</span>) },
                { key: 'status', header: t('taxi.col.status'), cell: (r) => <Badge tone={TONE[r.status]}>{t(`taxi.status.${r.status}` as MessageKey)}</Badge> },
              ]}
            />
          )}
        </Card>

        <TariffCard />
      </div>
    </Stagger>
  );
}

/** The office switches the service on/off for students and taxi drivers. */
function ServiceSwitch({ settings }: { settings: TaxiSettings }) {
  const { t } = useI18n();
  const toast = useToast();
  const save = useSaveTaxiSettings();
  const on = settings.taxiEnabled;
  return (
    <motion.button
      type="button"
      role="switch"
      aria-checked={on}
      whileTap={{ scale: 0.96 }}
      disabled={save.isPending}
      onClick={async () => {
        try {
          await save.mutateAsync({ taxiEnabled: !on });
          toast('success', t(on ? 'taxi.turnedOff' : 'taxi.turnedOn'));
        } catch {
          toast('danger', t('common.saveFailed'));
        }
      }}
      className={clsx(
        'inline-flex h-11 items-center gap-3 rounded-pill ps-2 pe-4 text-label transition-colors duration-200',
        on ? 'bg-success-soft text-success' : 'bg-surface-muted text-text-muted',
      )}
    >
      <span className={clsx('relative h-7 w-12 rounded-pill transition-colors duration-200', on ? 'bg-success' : 'bg-border')} aria-hidden>
        <motion.span layout transition={spring} className={clsx('absolute top-1 size-5 rounded-pill bg-surface shadow-sm', on ? 'end-1' : 'start-1')} />
      </span>
      <Power size={16} aria-hidden />
      {t(on ? 'taxi.serviceOn' : 'taxi.serviceOff')}
    </motion.button>
  );
}

/** TX-03: the tariff, with a preview of what students will pay. */
function TariffCard() {
  const { t } = useI18n();
  const money = useMoney();
  const toast = useToast();
  const q = useTaxiSettings();
  const save = useSaveTaxiSettings();
  const [form, setForm] = useState<TaxiSettings | null>(null);
  useEffect(() => {
    if (q.data && !form) setForm(q.data);
  }, [q.data, form]);

  const field = (key: 'taxiBaseFare' | 'taxiPerKm' | 'taxiMinFare' | 'taxiOfferSeconds', label: MessageKey, hint?: MessageKey) => (
    <Input
      id={`taxi-${key}`}
      label={t(label)}
      hint={hint ? t(hint) : undefined}
      dir="ltr"
      inputMode="numeric"
      value={form ? String(form[key]) : ''}
      onChange={(e) => form && setForm({ ...form, [key]: Number(e.target.value.replace(/\D/g, '')) || 0 })}
    />
  );

  return (
    <Card title={t('taxi.tariff')} description={t('taxi.tariffHint')}>
      {!form ? (
        <SkeletonRows rows={4} />
      ) : (
        <form
          className="flex flex-col gap-4"
          onSubmit={async (e) => {
            e.preventDefault();
            try {
              const { taxiBaseFare, taxiPerKm, taxiMinFare, taxiOfferSeconds } = form;
              setForm(await save.mutateAsync({ taxiBaseFare, taxiPerKm, taxiMinFare, taxiOfferSeconds }));
              toast('success', t('taxi.saved'));
            } catch {
              toast('danger', t('common.saveFailed'));
            }
          }}
        >
          <div className="grid grid-cols-2 gap-3">
            {field('taxiBaseFare', 'taxi.base')}
            {field('taxiPerKm', 'taxi.perKm')}
            {field('taxiMinFare', 'taxi.minFare')}
            {field('taxiOfferSeconds', 'taxi.offerSeconds', 'taxi.offerSecondsHint')}
          </div>
          <div className="rounded-md bg-surface-muted p-3">
            <p className="mb-2 text-caption text-text-muted">{t('taxi.preview')}</p>
            <ul className="grid grid-cols-2 gap-2">
              {SAMPLE_KM.map((km) => (
                <li key={km} className="flex items-baseline justify-between gap-2 rounded-md bg-surface px-3 py-2">
                  <span className="text-caption text-text-muted">
                    <span dir="ltr">{km}</span> {t('taxi.km')}
                  </span>
                  <motion.span key={previewFare(km, form)} initial={{ opacity: 0.4, y: -2 }} animate={{ opacity: 1, y: 0 }} className="tabular text-label">
                    {money(previewFare(km, form))}
                  </motion.span>
                </li>
              ))}
            </ul>
          </div>
          <Errors messages={errorMessages(save.error)} />
          <Button type="submit" loading={save.isPending}>
            {t('taxi.save')}
          </Button>
        </form>
      )}
    </Card>
  );
}

function Kpi({ icon: Icon, label, value, tone, format }: { icon: typeof CarTaxiFront; label: string; value: number; tone: 'primary' | 'warning' | 'success' | 'danger'; format?: (n: number) => string }) {
  return (
    <div className="flex items-center gap-3 rounded-lg bg-surface p-4 shadow-sm">
      <span
        className={clsx(
          'grid size-10 shrink-0 place-items-center rounded-pill',
          tone === 'primary' && 'bg-primary-soft text-primary',
          tone === 'warning' && 'bg-warning-soft text-warning',
          tone === 'success' && 'bg-success-soft text-success',
          tone === 'danger' && 'bg-danger-soft text-danger',
        )}
      >
        <Icon size={20} aria-hidden />
      </span>
      <span className="min-w-0">
        <span className="block truncate text-caption text-text-muted">{label}</span>
        <span className="block truncate text-title tabular-nums">
          <AnimatedNumber value={value} format={format} />
        </span>
      </span>
    </div>
  );
}
