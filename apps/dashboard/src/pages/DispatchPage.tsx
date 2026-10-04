import { clsx } from 'clsx';
import { Bus, Clock, Hourglass, Moon, RefreshCw, Sun, Users, Zap } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useState } from 'react';
import { useI18n, useMoney } from '../lib/i18n';
import { usePlanWave, useDispatch, type DispatchRun, type DispatchWave } from '../lib/queries';
import { AnimatedNumber, Badge, Button, Card, EmptyState, PageHeader, SkeletonRows, Stagger } from '../ui';
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
                <RunCard run={r} />
              </motion.div>
            ))}
          </motion.div>
        )}
      </div>

      {wave.waitlist.length ? <Waitlist wave={wave} /> : null}
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

function RunCard({ run }: { run: DispatchRun }) {
  const { t, lang } = useI18n();
  const money = useMoney();
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
          <li key={s.seq} className="relative flex items-center gap-3 py-2">
            <span className={clsx('absolute start-[13px] w-0.5 bg-border', i === 0 ? 'top-1/2' : 'top-0', i === run.stops.length - 1 ? 'bottom-1/2' : 'bottom-0')} aria-hidden />
            <span className="relative grid size-7 shrink-0 place-items-center rounded-pill border-2 border-primary bg-surface text-caption font-semibold text-primary">{s.seq}</span>
            <span className="min-w-0 flex-1 truncate">{lang === 'ar' && s.point.nameAr ? s.point.nameAr : s.point.name}</span>
            <span className="text-caption text-text-muted">{s.count}</span>
            <span className="w-14 text-end text-label tabular-nums" dir="ltr">
              {clock(s.eta)}
            </span>
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

function Waitlist({ wave }: { wave: DispatchWave }) {
  const { t } = useI18n();
  return (
    <section className="mt-6">
      <h3 className="mb-3 flex items-center gap-2 text-label">
        <Hourglass size={16} className="text-warning" aria-hidden /> {t('dispatch.waitlist')}
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
