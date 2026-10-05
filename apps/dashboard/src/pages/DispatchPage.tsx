import { clsx } from 'clsx';
import { ArrowLeftRight, Bus, BusFront, ChevronDown, Clock, Hourglass, Moon, Plus, RefreshCw, Sun, Users, Zap } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useState } from 'react';
import { ApiError } from '../lib/api';
import { useI18n, useMoney } from '../lib/i18n';
import { useExtraRun, useFreeDrivers, useMoveStudent } from '../lib/ops';
import { usePlanWave, useDispatch, type DispatchRun, type DispatchWave } from '../lib/queries';
import { AnimatedNumber, Badge, Button, Card, Drawer, EmptyState, IconButton, PageHeader, SkeletonRows, Stagger, useToast } from '../ui';
import { itemVariants, listVariants, spring } from '../ui/motion';

/** Baghdad civil date, `plus` days from today. */
const baghdadDate = (plus = 0) => new Date(Date.now() + 3 * 3600_000 + plus * 86400_000).toISOString().slice(0, 10);

const clock = (iso: string | null) => (iso ? new Date(iso).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Baghdad' }) : '—');

export function DispatchPage() {
  const { t } = useI18n();
  const [plus, setPlus] = useState(0);
  const date = baghdadDate(plus);
  const q = useDispatch(date);

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('dispatch.title')}
        description={t('dispatch.desc')}
        actions={
          <div role="tablist" className="relative flex rounded-pill bg-surface p-1 shadow-sm">
            {[0, 1].map((p) => (
              <button
                key={p}
                role="tab"
                aria-selected={plus === p}
                onClick={() => setPlus(p)}
                className={clsx('relative z-10 h-10 rounded-pill px-5 text-label transition-colors', plus === p ? 'text-on-primary' : 'text-text-muted hover:text-text')}
              >
                {plus === p ? <motion.span layoutId="day-pill" transition={spring} className="absolute inset-0 -z-10 rounded-pill bg-primary" /> : null}
                {t(p === 0 ? 'dispatch.today' : 'dispatch.tomorrow')}
              </button>
            ))}
          </div>
        }
      />
      {q.isLoading ? (
        <Card>
          <SkeletonRows rows={5} />
        </Card>
      ) : !q.data?.length ? (
        <Card>
          <EmptyState icon={Clock} title={t('dispatch.noWaves')} message={t('dispatch.noWavesHint')} />
        </Card>
      ) : (
        <Stagger className="flex flex-col gap-6">
          {q.data.map((w) => (
            <motion.div key={`${date}-${w.waveId}`} variants={itemVariants}>
              <WaveCard wave={w} date={date} />
            </motion.div>
          ))}
        </Stagger>
      )}
    </div>
  );
}

function WaveCard({ wave, date }: { wave: DispatchWave; date: string }) {
  const { t } = useI18n();
  const plan = usePlanWave();
  const [queued, setQueued] = useState(false);
  const [moving, setMoving] = useState<Moving | null>(null);
  const [adding, setAdding] = useState(false);
  const Icon = wave.type === 'morning' ? Sun : Moon;

  async function run() {
    await plan.mutateAsync({ waveId: wave.waveId, date });
    setQueued(true);
    setTimeout(() => setQueued(false), 6000);
  }

  return (
    <Card
      data-testid={`wave-${wave.time}`}
      title={
        <span className="flex items-center gap-3">
          <span className="grid size-10 place-items-center rounded-pill bg-primary-soft text-primary">
            <Icon size={20} />
          </span>
          <span>
            {t(wave.type === 'morning' ? 'dispatch.morning' : 'dispatch.return')} <span dir="ltr">{wave.time}</span>
          </span>
          <Badge tone={wave.planned ? 'success' : 'neutral'}>{t(wave.planned ? 'dispatch.planned' : 'dispatch.notPlanned')}</Badge>
        </span>
      }
      actions={
        <Button variant={wave.planned ? 'secondary' : 'primary'} icon={wave.planned ? RefreshCw : Zap} loading={plan.isPending} onClick={run}>
          {t(wave.planned ? 'dispatch.recheck' : 'dispatch.planNow')}
        </Button>
      }
    >
      <AnimatePresence>
        {queued ? (
          <motion.p initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} exit={{ opacity: 0, height: 0 }} className="mb-4 text-caption text-primary" role="status">
            {t('dispatch.queued')}
          </motion.p>
        ) : null}
      </AnimatePresence>

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <Stat label={t('dispatch.open')} value={wave.counts.open} />
        <Stat label={t('dispatch.assigned')} value={wave.counts.assigned} tone="success" />
        <Stat label={t('dispatch.waitlisted')} value={wave.counts.waitlisted} tone="warning" />
        <Stat label={t('dispatch.cancelled')} value={wave.counts.cancelled} />
      </div>

      <div className="mt-6">
        {wave.runs.length === 0 ? (
          <div className="rounded-md bg-surface-muted">
            <EmptyState icon={Bus} title={t('dispatch.noRuns')} message={t('dispatch.noRunsHint')} />
          </div>
        ) : (
          <motion.div className="grid gap-4 lg:grid-cols-2" variants={listVariants} initial="hidden" animate="show">
            {wave.runs.map((r) => (
              <motion.div key={r.id} variants={itemVariants} layout>
                <RunCard run={r} onMove={wave.planned ? (p) => setMoving({ ...p, fromRunId: r.id, gender: r.gender }) : undefined} />
              </motion.div>
            ))}
          </motion.div>
        )}
      </div>

      {wave.waitlist.length ? <Waitlist wave={wave} onAddBus={wave.planned ? () => setAdding(true) : undefined} /> : null}
      <MoveDrawer wave={wave} moving={moving} onClose={() => setMoving(null)} />
      <ExtraRunDrawer wave={wave} date={date} open={adding} onClose={() => setAdding(false)} />
    </Card>
  );
}

function Stat({ label, value, tone }: { label: string; value: number; tone?: 'success' | 'warning' }) {
  return (
    <div className="rounded-md bg-surface-muted px-4 py-3">
      <p className="text-caption text-text-muted">{label}</p>
      <p className={clsx('text-title tabular-nums', tone === 'success' && value > 0 && 'text-success', tone === 'warning' && value > 0 && 'text-warning')}>
        <AnimatedNumber value={value} />
      </p>
    </div>
  );
}

type Passenger = DispatchRun['stops'][number]['passengers'][number];
interface Moving extends Passenger {
  fromRunId: string;
  gender: 'male' | 'female';
}

function RunCard({ run, onMove }: { run: DispatchRun; onMove?: (p: Passenger) => void }) {
  const { t, lang } = useI18n();
  const money = useMoney();
  const [open, setOpen] = useState<number | null>(null);
  const movable = !!onMove && run.status === 'planned';
  const share = run.capacity ? run.booked / run.capacity : 0;
  const cash = run.stops.reduce((n, s) => n + s.cashToCollect, 0);
  return (
    <article className="rounded-lg border border-border bg-surface p-4" data-testid="run">
      <header className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <p className="text-label">{run.driverName}</p>
          <p className="text-caption text-text-muted">{run.plate ?? '—'}</p>
        </div>
        <div className="flex flex-wrap gap-2">
          {run.tierName ? <Badge tone="primary">{`${t('dispatch.tier')} ${run.tierName}`}</Badge> : null}
          <Badge tone={run.femaleOnly ? 'female-only' : 'neutral'}>{t(run.femaleOnly ? 'dispatch.femaleOnly' : 'dispatch.male')}</Badge>
        </div>
      </header>

      <div className="mt-4 flex items-center gap-3">
        <Users size={16} className="text-text-muted" aria-hidden />
        <div className="h-2 flex-1 overflow-hidden rounded-pill bg-surface-muted" role="meter" aria-valuenow={run.booked} aria-valuemax={run.capacity} aria-label={t('dispatch.seats')}>
          <motion.div className={clsx('h-full rounded-pill', share >= 1 ? 'bg-warning' : 'bg-primary')} initial={{ width: 0 }} animate={{ width: `${Math.min(100, share * 100)}%` }} transition={spring} />
        </div>
        <span className="text-caption tabular-nums" dir="ltr">
          {run.booked}/{run.capacity}
        </span>
      </div>

      <ol className="mt-4 flex flex-col">
        {run.stops.map((s, i) => (
          <li key={s.seq} className="relative">
            <button
              type="button"
              className="flex w-full items-center gap-3 rounded-md py-2 text-start transition-colors hover:bg-surface-muted"
              aria-expanded={open === s.seq}
              onClick={() => setOpen(open === s.seq ? null : s.seq)}
            >
              <span className={clsx('absolute start-[13px] w-0.5 bg-border', i === 0 ? 'top-5' : 'top-0', i === run.stops.length - 1 ? 'h-5' : 'bottom-0')} aria-hidden />
              <span className="relative grid size-7 shrink-0 place-items-center rounded-pill border-2 border-primary bg-surface text-caption font-semibold text-primary">{s.seq}</span>
              <span className="min-w-0 flex-1 truncate">{lang === 'ar' && s.point.nameAr ? s.point.nameAr : s.point.name}</span>
              <span className="text-caption text-text-muted">{s.count}</span>
              <span className="w-14 text-end text-label tabular-nums" dir="ltr">
                {clock(s.eta)}
              </span>
              <ChevronDown size={16} className={clsx('text-text-muted transition-transform', open === s.seq && 'rotate-180')} aria-hidden />
            </button>
            <AnimatePresence initial={false}>
              {open === s.seq ? (
                <motion.ul initial={{ height: 0, opacity: 0 }} animate={{ height: 'auto', opacity: 1 }} exit={{ height: 0, opacity: 0 }} className="overflow-hidden ps-10">
                  {s.passengers.map((p) => (
                    <li key={p.requestId} className="flex items-center gap-2 py-1 text-caption" data-testid="passenger">
                      <span className="min-w-0 flex-1 truncate">
                        {p.name} <span className="text-text-muted">{p.studentId}</span>
                      </span>
                      {movable ? <IconButton icon={ArrowLeftRight} label={t('dispatch.move')} onClick={() => onMove!(p)} /> : null}
                    </li>
                  ))}
                </motion.ul>
              ) : null}
            </AnimatePresence>
          </li>
        ))}
      </ol>

      <footer className="mt-3 flex items-center justify-between border-t border-border pt-3 text-caption text-text-muted">
        <span>
          {t('dispatch.depart')} <span dir="ltr" className="font-semibold text-text">{clock(run.departAt)}</span>
        </span>
        {cash ? (
          <span className="text-success">
            {t('dispatch.cash')} {money(cash)}
          </span>
        ) : null}
      </footer>
    </article>
  );
}

function Waitlist({ wave, onAddBus }: { wave: DispatchWave; onAddBus?: () => void }) {
  const { t } = useI18n();
  return (
    <section className="mt-6">
      <h3 className="mb-3 flex items-center gap-2 text-label">
        <Hourglass size={16} className="text-warning" aria-hidden /> <span className="flex-1">{t('dispatch.waitlist')}</span>
        {onAddBus ? (
          <Button variant="secondary" icon={Plus} onClick={onAddBus}>
            {t('dispatch.addBus')}
          </Button>
        ) : null}
      </h3>
      <ul className="divide-y divide-border rounded-md border border-border">
        {wave.waitlist.map((w) => (
          <li key={w.id} className="flex flex-wrap items-center gap-3 px-4 py-3">
            <span className="min-w-0 flex-1">
              <span className="text-label">{w.name}</span> <span className="text-caption text-text-muted">{w.studentId}</span>
            </span>
            <span className="text-caption text-text-muted">{w.point}</span>
            <Badge tone={w.subscriber ? 'primary' : 'neutral'}>{t(w.subscriber ? 'dispatch.subscriber' : 'dispatch.payPerRide')}</Badge>
            {w.status === 'open' ? (
              <Badge>{t('dispatch.statusOpen')}</Badge>
            ) : (
              <span className="text-caption text-warning">
                {t('dispatch.until')} <span dir="ltr">{clock(w.until)}</span>
              </span>
            )}
          </li>
        ))}
      </ul>
    </section>
  );
}

/** TO-08: pick the bus to move a student to. The server checks gender, seats and the wave time again. */
function MoveDrawer({ wave, moving, onClose }: { wave: DispatchWave; moving: Moving | null; onClose: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const move = useMoveStudent();
  const [target, setTarget] = useState<string | null>(null);
  const options = wave.runs.filter((r) => r.id !== moving?.fromRunId);

  async function confirm() {
    if (!moving || !target) return;
    try {
      await move.mutateAsync({ requestId: moving.requestId, runId: target });
      toast('success', t('dispatch.moved'));
      setTarget(null);
      onClose();
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  return (
    <Drawer
      open={!!moving}
      title={t('dispatch.moveTitle')}
      onClose={() => (setTarget(null), onClose())}
      footer={
        <>
          <Button icon={ArrowLeftRight} disabled={!target} loading={move.isPending} onClick={confirm}>
            {t('dispatch.moveConfirm')}
          </Button>
          <Button variant="secondary" onClick={() => (setTarget(null), onClose())}>
            {t('common.cancel')}
          </Button>
        </>
      }
    >
      {moving ? (
        <div className="flex flex-col gap-4">
          <p className="text-headline">
            {moving.name} <span className="text-caption text-text-muted">{moving.studentId}</span>
          </p>
          <p className="text-text-muted">{t('dispatch.moveHint')}</p>
          <fieldset className="flex flex-col gap-2">
            <legend className="mb-2 text-label">{t('dispatch.moveTo')}</legend>
            {options.length === 0 ? <p className="text-caption text-text-muted">{t('dispatch.noOtherBus')}</p> : null}
            {options.map((r) => {
              const why = r.gender !== moving.gender ? t('dispatch.whyGender') : r.booked >= r.capacity ? t('dispatch.whyFull') : r.status !== 'planned' ? t('dispatch.whyStarted') : null;
              return (
                <label key={r.id} className={clsx('flex items-center gap-3 rounded-md border p-3', target === r.id ? 'border-primary bg-primary-soft' : 'border-border', why && 'opacity-60')}>
                  <input type="radio" name="move-target" value={r.id} disabled={!!why} checked={target === r.id} onChange={() => setTarget(r.id)} />
                  <BusFront size={18} className="text-text-muted" aria-hidden />
                  <span className="min-w-0 flex-1">
                    <span className="block text-label">{r.driverName}</span>
                    <span className="text-caption text-text-muted">{why ?? `${r.booked}/${r.capacity} ${t('dispatch.seats')}`}</span>
                  </span>
                  <Badge tone={r.femaleOnly ? 'female-only' : 'neutral'}>{t(r.femaleOnly ? 'dispatch.femaleOnly' : 'dispatch.male')}</Badge>
                </label>
              );
            })}
          </fieldset>
        </div>
      ) : null}
    </Drawer>
  );
}

/** TO-08: an extra bus for the waitlist. */
function ExtraRunDrawer({ wave, date, open, onClose }: { wave: DispatchWave; date: string; open: boolean; onClose: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const drivers = useFreeDrivers(wave.waveId, date, open);
  const extra = useExtraRun();
  const [driverId, setDriverId] = useState('');
  const [gender, setGender] = useState<'male' | 'female'>(wave.waitlist[0]?.gender ?? 'male');

  async function confirm() {
    try {
      const r = await extra.mutateAsync({ waveId: wave.waveId, date, driverId, gender });
      toast('success', t('dispatch.busAdded', { n: r.placed }));
      setDriverId('');
      onClose();
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  return (
    <Drawer
      open={open}
      title={t('dispatch.addBusTitle')}
      onClose={onClose}
      footer={
        <>
          <Button icon={Plus} disabled={!driverId} loading={extra.isPending} onClick={confirm}>
            {t('dispatch.addBus')}
          </Button>
          <Button variant="secondary" onClick={onClose}>
            {t('common.cancel')}
          </Button>
        </>
      }
    >
      <div className="flex flex-col gap-5">
        <p className="text-text-muted">{t('dispatch.addBusHint', { n: wave.waitlist.length })}</p>
        <fieldset className="flex gap-2">
          <legend className="mb-2 text-label">{t('dispatch.busFor')}</legend>
          {(['male', 'female'] as const).map((g) => (
            <label key={g} className={clsx('flex flex-1 items-center gap-2 rounded-md border p-3', gender === g ? 'border-primary bg-primary-soft' : 'border-border')}>
              <input type="radio" name="extra-gender" checked={gender === g} onChange={() => setGender(g)} />
              {t(g === 'female' ? 'dispatch.femaleOnly' : 'dispatch.male')}
            </label>
          ))}
        </fieldset>
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-2 text-label">{t('dispatch.driver')}</legend>
          {drivers.isPending ? <SkeletonRows rows={2} /> : null}
          {drivers.data?.length === 0 ? <p className="text-caption text-text-muted">{t('dispatch.noFreeDriver')}</p> : null}
          {drivers.data?.map((d) => (
            <label key={d.id} className={clsx('flex items-center gap-3 rounded-md border p-3', driverId === d.id ? 'border-primary bg-primary-soft' : 'border-border')}>
              <input type="radio" name="extra-driver" value={d.id} checked={driverId === d.id} onChange={() => setDriverId(d.id)} />
              <span className="min-w-0 flex-1">
                <span className="block text-label">{d.name}</span>
                <span className="text-caption text-text-muted">
                  {d.plate ?? '—'} · {d.seats} {t('dispatch.seats')}
                </span>
              </span>
              {d.offered ? <Badge tone="success">{t('dispatch.offered')}</Badge> : null}
            </label>
          ))}
        </fieldset>
      </div>
    </Drawer>
  );
}
