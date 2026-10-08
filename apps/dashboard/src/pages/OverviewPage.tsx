import { clsx } from 'clsx';
import { ArrowLeft, Building2, CalendarClock, Check, FileCheck2, Gauge, Hourglass, Layers, MapPin, Percent, Plus, Radio, Route, Users, Wallet, WifiOff, type LucideIcon } from 'lucide-react';
import { motion } from 'motion/react';
import { lazy, Suspense, useMemo, useState } from 'react';
import { Link } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n, useMoney, type MessageKey } from '../lib/i18n';
import { useLiveFeed } from '../lib/live';
import { baghdadMonth, usePlatformOverview } from '../lib/money';
import { useFreeDrivers } from '../lib/ops';
import { useCurrentUniversity, useDispatch, useLiveRuns, usePoints, useRequirements, useTiers, useWaves, type DispatchWave, type LiveRun } from '../lib/queries';
import { useTaxiOverview } from '../lib/taxi';
import { Badge, Button, Card, EmptyState, Input, Kpi, KpiGrid, PageHeader, SkeletonRows, Stagger, Table } from '../ui';
import type { MapMarker } from '../ui/MapView';
import { itemVariants } from '../ui/motion';
import { ExtraRunDrawer } from './DispatchPage';

const MapView = lazy(() => import('../ui/MapView').then((m) => ({ default: m.MapView })));
const baghdadDate = () => new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);

type WaveState = 'arrived' | 'onRoad' | 'waiting' | 'planned' | 'notPlanned';
const STATE_STYLE: Record<WaveState, { track: string; bar: string; text: string }> = {
  arrived: { track: 'bg-success-soft', bar: 'bg-success', text: 'text-success' },
  onRoad: { track: 'bg-primary-soft', bar: 'bg-primary', text: 'text-primary' },
  waiting: { track: 'bg-warning-soft', bar: 'bg-warning', text: 'text-warning' },
  planned: { track: 'bg-surface-muted', bar: 'bg-primary', text: 'text-text-muted' },
  notPlanned: { track: 'bg-surface-muted', bar: 'bg-text-muted', text: 'text-text-muted' },
};

/** Where a wave stands, from the dispatch board and today's live runs (no estimates). */
function waveProgress(w: DispatchWave, runs: LiveRun[]): { state: WaveState; share: number } {
  const mine = runs.filter((r) => r.wave.type === w.type && r.wave.time === w.time && r.status !== 'cancelled');
  const stops = mine.reduce((n, r) => n + r.stops.length, 0);
  const served = mine.reduce((n, r) => n + r.stops.filter((s) => s.served).length, 0);
  if (mine.length > 0 && mine.every((r) => r.status === 'done')) return { state: 'arrived', share: 1 };
  if (mine.some((r) => r.status === 'started' || r.status === 'at_stop')) return { state: 'onRoad', share: stops ? served / stops : 0 };
  const asked = w.counts.open + w.counts.assigned + w.counts.waitlisted;
  if (w.counts.waitlisted > 0) return { state: 'waiting', share: asked ? w.counts.assigned / asked : 0 };
  return { state: w.planned ? 'planned' : 'notPlanned', share: 0 };
}

function OfficeOverview() {
  const { t, lang } = useI18n();
  const { session } = useAuth();
  const date = baghdadDate();
  const board = useDispatch(date);
  const runs = useLiveRuns(date);
  const taxi = useTaxiOverview();
  const initial = useMemo(() => Object.fromEntries((runs.data ?? []).map((r) => [r.runId, r.bus])), [runs.data]);
  const { buses, connected } = useLiveFeed(initial, ['live-runs', date]);

  const waves = useMemo(() => [...(board.data ?? [])].sort((a, b) => a.time.localeCompare(b.time)), [board.data]);
  const runList = runs.data ?? [];
  const active = runList.filter((r) => r.status === 'started' || r.status === 'at_stop');
  const counted = runList.filter((r) => r.status !== 'cancelled');
  const asked = waves.reduce((n, w) => n + w.counts.open + w.counts.assigned + w.counts.waitlisted, 0);
  const seated = waves.reduce((n, w) => n + w.counts.assigned, 0);
  const waiting = waves.reduce((n, w) => n + w.counts.waitlisted, 0);
  const worst = waves.filter((w) => w.counts.waitlisted > 0).sort((a, b) => b.counts.waitlisted - a.counts.waitlisted)[0];
  const k = taxi.data?.kpis;
  const online = taxi.data?.online ?? [];
  const dash = () => '—';

  return (
    <Stagger>
      <PageHeader
        title={`${t('overview.welcome')}${lang === 'ar' ? '، ' : ', '}${session?.user.name ?? ''}`}
        actions={
          <Button asChild>
            <Link to="/dispatch">
              <Route className="size-4" aria-hidden />
              {t('overview.action')}
            </Link>
          </Button>
        }
      />

      <KpiGrid>
        <Kpi
          tone="brand"
          label={t('overview.requestsToday')}
          value={asked}
          loading={board.isPending}
          format={board.isError ? dash : undefined}
          sub={board.isError ? t('common.error') : asked ? t('overview.seatedPct', { n: Math.round((seated / asked) * 100) }) : t('overview.noRequests')}
        />
        <Kpi
          label={t('overview.busesOnRoad')}
          value={active.length}
          loading={runs.isPending}
          format={runs.isError ? dash : undefined}
          sub={runs.isError ? t('common.error') : counted.length ? t('overview.runsToday', { n: counted.length }) : t('overview.noRunsYet')}
          subTone={runs.isError ? 'danger' : active.length ? 'success' : 'default'}
        />
        <Kpi
          label={t('overview.waitlist')}
          value={waiting}
          loading={board.isPending}
          format={board.isError ? dash : undefined}
          sub={board.isError ? t('common.error') : worst ? t('overview.waveNeedsBus', { time: worst.time }) : t('overview.nobodyWaiting')}
          subTone={board.isError ? 'danger' : worst ? 'warning' : 'success'}
        />
        <Kpi
          tone="gold"
          label={t('overview.taxiOnline')}
          value={k?.online ?? 0}
          loading={taxi.isPending}
          format={taxi.isError || (!taxi.isPending && !k) ? dash : undefined}
          sub={taxi.isError ? t('common.error') : k ? t('overview.taxiBusy', { n: online.filter((o) => o.busy).length }) : null}
        />
      </KpiGrid>

      <div className="grid gap-4 xl:grid-cols-[minmax(0,2fr)_minmax(320px,1fr)]">
        <LiveMapCard runs={active} buses={buses} taxis={online} connected={connected} />
        <ScheduleCard waves={waves} runs={runList} loading={board.isPending} date={date} />
      </div>

      <SetupCard />
    </Stagger>
  );
}

function LiveMapCard({
  runs,
  buses,
  taxis,
  connected,
}: {
  runs: LiveRun[];
  buses: ReturnType<typeof useLiveFeed>['buses'];
  taxis: NonNullable<ReturnType<typeof useTaxiOverview>['data']>['online'];
  connected: boolean;
}) {
  const { t } = useI18n();
  const uni = useCurrentUniversity();
  const markers = useMemo<MapMarker[]>(() => {
    const out: MapMarker[] = [];
    if (uni.data) out.push({ id: 'campus', lat: uni.data.campusLat, lng: uni.data.campusLng, label: t('live.campus'), kind: 'campus' });
    for (const r of runs) {
      const p = buses[r.runId];
      if (p) out.push({ id: r.runId, lat: p.lat, lng: p.lng, label: `${r.driverName} · ${r.plate ?? ''}`, kind: r.femaleOnly ? 'bus-female' : 'bus' });
    }
    for (const o of taxis) out.push({ id: `taxi-${o.driverId}`, lat: o.lat, lng: o.lng, label: `${o.name} · ${o.plate ?? ''} · ${t(o.busy ? 'taxi.busy' : 'taxi.free')}`, kind: o.busy ? 'taxi-busy' : 'taxi' });
    return out;
  }, [uni.data, runs, buses, taxis, t]);
  const vehicles = markers.length - (uni.data ? 1 : 0);

  return (
    <motion.section variants={itemVariants} aria-labelledby="ov-map" className="flex min-w-0 flex-col overflow-hidden rounded-lg border border-border bg-surface shadow-card dark:shadow-none">
      <header className="flex flex-wrap items-center gap-3 px-5 py-4">
        <h2 id="ov-map" className="flex-1 text-headline">
          {t('overview.mapTitle')}
        </h2>
        <span className="hidden items-center gap-3 text-caption text-text-muted sm:flex" aria-hidden>
          <span className="inline-flex items-center gap-1.5">
            <span className="size-3 rounded-[4px] bg-primary" />
            {t('overview.legendBus')}
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="size-3 rounded-[4px] bg-female-only" />
            {t('dispatch.femaleOnly')}
          </span>
          <span className="inline-flex items-center gap-1.5">
            <span className="size-3 rounded-[4px] bg-warning" />
            {t('overview.legendTaxi')}
          </span>
        </span>
        <span role="status" className={clsx('inline-flex items-center gap-1.5 text-label font-semibold', connected ? 'text-success' : 'text-warning')}>
          {connected ? <span className="size-2 animate-pulse rounded-pill bg-success" aria-hidden /> : <WifiOff className="size-4" aria-hidden />}
          {t(connected ? 'live.connected' : 'live.reconnecting')}
        </span>
      </header>
      <div className="relative min-h-[320px] flex-1 md:min-h-[400px]">
        {uni.data ? (
          <Suspense fallback={<div className="absolute inset-0 animate-pulse bg-surface-muted" />}>
            <MapView className="absolute inset-0" label={t('live.map')} center={{ lat: uni.data.campusLat, lng: uni.data.campusLng }} markers={markers} />
          </Suspense>
        ) : (
          <div className="absolute inset-0 animate-pulse bg-surface-muted" />
        )}
        {uni.data && vehicles === 0 ? (
          <p className="pointer-events-none absolute inset-x-4 bottom-4 mx-auto w-fit max-w-[calc(100%-2rem)] rounded-pill bg-surface px-4 py-2 text-center text-label font-normal text-text-muted shadow-card">
            {t('overview.mapEmpty')}
          </p>
        ) : null}
      </div>
      <footer className="flex items-center justify-end border-t border-border px-5 py-3">
        <Link to="/live" className="inline-flex min-h-10 items-center gap-2 rounded-pill px-3 text-label text-primary hover:bg-primary-soft">
          <Radio className="size-4" aria-hidden />
          {t('overview.openLive')}
          <ArrowLeft className="size-4 ltr:rotate-180" aria-hidden />
        </Link>
      </footer>
    </motion.section>
  );
}

function ScheduleCard({ waves, runs, loading, date }: { waves: DispatchWave[]; runs: LiveRun[]; loading: boolean; date: string }) {
  const { t } = useI18n();
  const short = waves.find((w) => w.planned && w.counts.waitlisted > 0);
  return (
    <Card animated title={t('overview.schedule')} className="flex flex-col">
      {loading ? (
        <SkeletonRows rows={4} />
      ) : waves.length === 0 ? (
        <EmptyState
          icon={CalendarClock}
          title={t('overview.scheduleEmpty')}
          message={t('overview.scheduleEmptyHint')}
          action={
            <Button asChild variant="secondary" size="sm">
              <Link to="/settings/waves">{t('nav.waves')}</Link>
            </Button>
          }
        />
      ) : (
        <ul className="flex flex-col gap-4">
          {waves.map((w) => {
            const { state, share } = waveProgress(w, runs);
            const st = STATE_STYLE[state];
            const label =
              state === 'waiting' ? t('overview.wave.waiting', { n: w.counts.waitlisted }) : t(`overview.wave.${state}` as MessageKey);
            return (
              <li key={w.waveId} className="flex items-center gap-3">
                <span className="w-16 shrink-0">
                  <span className="block text-[15px] leading-5 font-semibold tabular" dir="ltr">
                    {w.time}
                  </span>
                  <span className="block text-caption text-text-muted">{t(w.type === 'morning' ? 'dispatch.morning' : 'dispatch.return')}</span>
                </span>
                <span
                  className={clsx('h-2 flex-1 overflow-hidden rounded-pill', st.track)}
                  role="progressbar"
                  aria-label={t('overview.wave.progress', { time: w.time })}
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={Math.round(share * 100)}
                  aria-valuetext={label}
                >
                  <motion.span className={clsx('block h-full rounded-pill', st.bar)} initial={{ width: 0 }} animate={{ width: `${share * 100}%` }} transition={{ duration: 0.7, ease: 'easeOut' }} />
                </span>
                <span className={clsx('w-24 shrink-0 text-end text-caption font-semibold', st.text)}>{label}</span>
              </li>
            );
          })}
        </ul>
      )}
      {short ? <div className="mt-5 flex flex-1 flex-col">{<WaitlistAlert wave={short} date={date} />}</div> : null}
    </Card>
  );
}

/** A planned wave with a waitlist: suggest a free driver and open the extra-bus drawer. */
function WaitlistAlert({ wave, date }: { wave: DispatchWave; date: string }) {
  const { t } = useI18n();
  const [open, setOpen] = useState(false);
  const free = useFreeDrivers(wave.waveId, date, true);
  const first = free.data?.[0];
  return (
    <>
    <div className="mt-auto flex flex-wrap items-center gap-3 rounded-md bg-warning-soft p-4" role="status">
      <span className="grid size-10 shrink-0 place-items-center rounded-pill bg-surface text-warning" aria-hidden>
        <Hourglass className="size-5" />
      </span>
      <p className="min-w-48 flex-1 text-label font-normal text-text">
        <b className="block font-semibold">{t('overview.alertTitle', { time: wave.time })}</b>
        {t('overview.alertBody', { n: wave.counts.waitlisted })}{' '}
        {free.isPending ? null : first ? t('overview.alertDriver', { name: first.name, n: first.seats }) : t('overview.alertNoDriver')}
      </p>
      <Button variant="ink" size="sm" icon={Plus} onClick={() => setOpen(true)}>
        {t('dispatch.addBus')}
      </Button>
    </div>
    <ExtraRunDrawer wave={wave} date={date} open={open} onClose={() => setOpen(false)} />
    </>
  );
}

/** Setup checklist; shown only until every step is done. */
function SetupCard() {
  const { t } = useI18n();
  const tiers = useTiers();
  const points = usePoints();
  const waves = useWaves();
  const reqs = useRequirements();
  const loading = tiers.isPending || points.isPending || waves.isPending || reqs.isPending;
  const steps: { key: MessageKey; to: string; icon: LucideIcon; done: boolean }[] = [
    { key: 'step.tiers', to: '/settings/tiers', icon: Layers, done: (tiers.data?.length ?? 0) > 0 },
    { key: 'step.points', to: '/settings/points', icon: MapPin, done: (points.data?.filter((p) => p.active).length ?? 0) > 0 },
    { key: 'step.waves', to: '/settings/waves', icon: CalendarClock, done: waves.data?.some((w) => w.type === 'morning' && w.active) === true && waves.data?.some((w) => w.type === 'return' && w.active) === true },
    { key: 'step.requirements', to: '/settings/requirements', icon: FileCheck2, done: (reqs.data?.documents?.length ?? 0) > 0 },
  ];
  const doneCount = steps.filter((s) => s.done).length;
  if (loading) return null;
  if (doneCount === steps.length)
    return (
      <motion.div variants={itemVariants} className="flex flex-wrap items-center gap-3 rounded-lg border border-border bg-surface px-5 py-4">
        <span className="grid size-10 place-items-center rounded-pill bg-success-soft text-success" aria-hidden>
          <Check className="size-5" />
        </span>
        <p className="flex-1 text-label">{t('overview.setup')}</p>
        <span className="text-label text-text-muted tabular">
          {doneCount}/{steps.length}
        </span>
        <Badge tone="success">{t('overview.done')}</Badge>
      </motion.div>
    );
  return (
    <Card animated title={t('overview.setup')} description={t('overview.setupDesc')} actions={<span className="text-label text-text-muted tabular">{doneCount}/{steps.length}</span>}>
      <div className="mb-5 h-2 overflow-hidden rounded-pill bg-surface-muted" role="progressbar" aria-label={t('overview.setup')} aria-valuemin={0} aria-valuemax={steps.length} aria-valuenow={doneCount}>
        <motion.div className="h-full rounded-pill bg-primary" initial={{ width: 0 }} animate={{ width: `${(doneCount / steps.length) * 100}%` }} transition={{ duration: 0.7, ease: 'easeOut' }} />
      </div>
      <ol className="grid gap-2 md:grid-cols-2">
        {steps.map((s) => (
          <li key={s.key}>
            <Link to={s.to} className="group flex min-h-14 items-center gap-4 rounded-md border border-border p-3 transition-colors duration-200 hover:bg-surface-muted">
              <span className={clsx('grid size-10 shrink-0 place-items-center rounded-pill', s.done ? 'bg-success-soft text-success' : 'bg-primary-soft text-primary')} aria-hidden>
                {s.done ? <Check className="size-5" /> : <s.icon className="size-5" />}
              </span>
              <span className="flex-1 text-label">{t(s.key)}</span>
              <span className={clsx('text-caption font-semibold', s.done ? 'text-success' : 'text-text-muted')}>{s.done ? t('overview.done') : t('overview.todo')}</span>
              <ArrowLeft className="size-4 text-text-muted transition-transform duration-200 group-hover:-translate-x-1 ltr:rotate-180 ltr:group-hover:translate-x-1" aria-hidden />
            </Link>
          </li>
        ))}
      </ol>
    </Card>
  );
}

/** SA-04: revenue, commission and usage across universities for one month. */
function AdminOverview() {
  const { t, lang } = useI18n();
  const { session } = useAuth();
  const money = useMoney();
  const [month, setMonth] = useState(baghdadMonth());
  const q = usePlatformOverview(month);
  const o = q.data?.totals ? q.data : undefined;
  const tone = { approved: 'success', draft: 'warning', estimate: 'neutral' } as const;
  return (
    <Stagger>
      <PageHeader
        title={`${t('overview.welcome')}${lang === 'ar' ? '، ' : ', '}${session?.user.name ?? ''}`}
        description={t('overview.admin.subtitle')}
        actions={<Input id="overview-month" label={t('subs.month')} type="month" dir="ltr" value={month} onChange={(e) => e.target.value && setMonth(e.target.value)} />}
      />
      <KpiGrid>
        <Kpi tone="brand" icon={Wallet} label={t('overview.kpi.revenue')} value={o?.totals.revenue ?? 0} loading={q.isPending} format={money} />
        <Kpi icon={Percent} label={t('overview.kpi.commission')} value={o?.totals.commission ?? 0} loading={q.isPending} format={money} />
        <Kpi icon={Users} label={t('overview.kpi.subscribers')} value={o?.totals.subscribers ?? 0} loading={q.isPending} />
        <Kpi
          tone="gold"
          icon={Gauge}
          label={t('overview.kpi.fulfilment')}
          value={Math.round((o?.totals.fulfilment ?? 0) * 10)}
          loading={q.isPending}
          format={(n) => (o?.totals.fulfilment == null ? '—' : `${(n / 10).toFixed(1)}%`)}
        />
      </KpiGrid>
      <Card animated title={t('overview.perUniversity')} description={t('overview.perUniversityHint')}>
        {q.isPending ? (
          <SkeletonRows />
        ) : (
          <Table
            caption={t('overview.perUniversity')}
            rows={o?.universities ?? []}
            rowKey={(u) => u.universityId}
            empty={<EmptyState icon={Building2} title={t('universities.empty')} />}
            columns={[
              { key: 'name', header: t('overview.university'), cell: (u) => <span className="font-medium">{u.name}</span> },
              { key: 'revenue', header: t('overview.kpi.revenue'), cell: (u) => <span className="tabular">{money(u.revenue.total)}</span> },
              {
                key: 'commission',
                header: t('overview.kpi.commission'),
                cell: (u) => (
                  <span className="flex items-center gap-2">
                    <span className="tabular" data-testid="uni-commission" data-value={u.commission}>
                      {money(u.commission)}
                    </span>
                    <Badge tone={tone[u.settlement]}>{t(`overview.settlement.${u.settlement}` as MessageKey)}</Badge>
                  </span>
                ),
              },
              { key: 'subs', header: t('overview.kpi.subscribers'), cell: (u) => <span className="tabular">{u.subscribers}</span> },
              { key: 'runs', header: t('overview.runs'), cell: (u) => <span className="tabular">{u.runs}</span> },
              { key: 'ful', header: t('overview.kpi.fulfilment'), cell: (u) => <span className="tabular">{u.fulfilment === null ? '—' : `${u.fulfilment}%`}</span> },
            ]}
          />
        )}
      </Card>
    </Stagger>
  );
}

export function OverviewPage() {
  const { session } = useAuth();
  return session?.user.role === 'super_admin' ? <AdminOverview /> : <OfficeOverview />;
}
