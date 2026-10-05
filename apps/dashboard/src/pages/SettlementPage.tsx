import { clsx } from 'clsx';
import { BadgeCheck, Calculator, CircleAlert, FileSpreadsheet, FileText, HandCoins, Lock, Percent, Wallet } from 'lucide-react';
import { motion } from 'motion/react';
import { useState } from 'react';
import { ApiError } from '../lib/api';
import { useI18n, useMoney, type MessageKey } from '../lib/i18n';
import { baghdadMonth, downloadFile, useRunVerdict, useSettlement, useSettlementAction, type ReviewRun } from '../lib/money';
import { AnimatedNumber, Badge, Button, Card, Drawer, EmptyState, Input, PageHeader, SkeletonRows, Stagger, Table, Textarea, useToast } from '../ui';
import { itemVariants, spring } from '../ui/motion';

const FLAG_KEYS: Record<string, MessageKey> = {
  not_completed: 'settle.flag.not_completed',
  no_gps: 'settle.flag.no_gps',
  ended_elsewhere: 'settle.flag.ended_elsewhere',
  too_fast: 'settle.flag.too_fast',
  teleport: 'settle.flag.teleport',
  off_path: 'settle.flag.off_path',
};

function Stat({ icon: Icon, label, value, tone = 'primary', testId }: { icon: typeof Wallet; label: string; value: number; tone?: 'primary' | 'success' | 'warning'; testId?: string }) {
  const money = useMoney();
  return (
    <motion.div variants={itemVariants} whileHover={{ y: -3 }} transition={spring} className="flex items-center gap-4 rounded-lg bg-surface p-5 shadow-card">
      <span className={clsx('grid size-12 shrink-0 place-items-center rounded-md', tone === 'success' ? 'bg-success-soft text-success' : tone === 'warning' ? 'bg-warning-soft text-warning' : 'bg-primary-soft text-primary')} aria-hidden>
        <Icon className="size-6" />
      </span>
      <div className="min-w-0">
        <p className="text-title" data-testid={testId} data-value={value}>
          <AnimatedNumber value={value} format={money} />
        </p>
        <p className="truncate text-caption text-text-muted">{label}</p>
      </div>
    </motion.div>
  );
}

export function SettlementPage() {
  const { t, lang } = useI18n();
  const money = useMoney();
  const toast = useToast();
  const [month, setMonth] = useState(baghdadMonth(-1));
  const q = useSettlement(month);
  const action = useSettlementAction();
  const verdict = useRunVerdict(month);
  const [confirming, setConfirming] = useState(false);
  const [reviewing, setReviewing] = useState<ReviewRun | null>(null);
  const [note, setNote] = useState('');
  const s = q.data?.settlement ?? null;
  const review = q.data?.review ?? [];
  const approved = s?.status === 'approved';

  async function run(kind: 'compute' | 'approve') {
    try {
      await action.mutateAsync({ month, action: kind });
      toast('success', t(kind === 'compute' ? 'settle.computed' : 'settle.approvedToast'));
      setConfirming(false);
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  async function decide(v: boolean | null) {
    if (!reviewing) return;
    try {
      await verdict.mutateAsync({ runId: reviewing.id, verdict: v, note: note.trim() || undefined });
      toast('success', t('settle.verdictSaved'));
      setReviewing(null);
      setNote('');
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  const download = (kind: 'pdf' | 'xlsx') => downloadFile(`/settlements/${month}/export.${kind}`, `settlement-${month}.${kind}`).catch(() => toast('danger', t('common.error')));
  const flagLabel = (f: string) => (f.startsWith('missed_stop:') ? t('settle.flag.missed_stop', { n: f.split(':')[1] }) : t(FLAG_KEYS[f] ?? 'settle.flag.no_gps'));
  const wave = (r: ReviewRun) => `${t(r.waveType === 'morning' ? 'waves.morning' : 'waves.return')} ${String(Math.floor(r.waveMinute / 60)).padStart(2, '0')}:${String(r.waveMinute % 60).padStart(2, '0')}`;

  return (
    <Stagger>
      <PageHeader
        title={t('settle.title')}
        description={t('settle.desc')}
        actions={
          <div className="flex flex-wrap items-end gap-3">
            <Input id="settle-month" label={t('subs.month')} type="month" dir="ltr" value={month} onChange={(e) => e.target.value && setMonth(e.target.value)} />
            {!approved ? (
              <Button icon={Calculator} variant={s ? 'secondary' : 'primary'} loading={action.isPending && action.variables?.action === 'compute'} onClick={() => run('compute')} className="mb-0.5">
                {t(s ? 'settle.recompute' : 'settle.compute')}
              </Button>
            ) : null}
            {s && !approved ? (
              <Button icon={BadgeCheck} onClick={() => setConfirming(true)} className="mb-0.5">
                {t('settle.approve')}
              </Button>
            ) : null}
          </div>
        }
      />

      {q.isPending ? (
        <Card>
          <SkeletonRows />
        </Card>
      ) : !s ? (
        <Card animated>
          <EmptyState icon={Calculator} title={t('settle.none')} message={t('settle.noneHint')} />
        </Card>
      ) : (
        <>
          <motion.div variants={itemVariants} className={clsx('flex flex-wrap items-center gap-3 rounded-lg p-4', approved ? 'bg-success-soft text-success' : 'bg-warning-soft text-warning')}>
            {approved ? <Lock className="size-5" aria-hidden /> : <CircleAlert className="size-5" aria-hidden />}
            <span className="flex-1 text-label" data-testid="settlement-status">
              {approved ? t('settle.lockedNote', { date: new Date(s.approvedAt!).toLocaleDateString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB') }) : t('settle.draftNote')}
            </span>
            <Button variant="secondary" icon={FileText} onClick={() => download('pdf')}>
              PDF
            </Button>
            <Button variant="secondary" icon={FileSpreadsheet} onClick={() => download('xlsx')}>
              Excel
            </Button>
          </motion.div>

          <motion.div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4" variants={{ show: { transition: { staggerChildren: 0.05 } } }}>
            <Stat icon={Wallet} label={t('settle.pool')} value={s.totals.pool} />
            <Stat icon={HandCoins} label={t('settle.payout')} value={s.totals.payout} tone="success" testId="total-payout" />
            <Stat icon={Percent} label={`${t('settle.commission')} (${s.commissionPct}%)`} value={s.totals.commission} testId="total-commission" />
            <Stat icon={Wallet} label={t('settle.cash')} value={s.totals.cash} tone="warning" />
          </motion.div>

          <Card animated title={t('settle.drivers')} description={t('settle.driversHint')}>
            <Table
              caption={t('settle.drivers')}
              rows={s.lines}
              rowKey={(l) => l.driverId}
              empty={<EmptyState icon={HandCoins} title={t('settle.noDrivers')} />}
              columns={[
                {
                  key: 'driver',
                  header: t('settle.driver'),
                  cell: (l) => (
                    <span className="flex flex-col">
                      <span className="font-medium">{(lang === 'ar' && l.nameAr) || l.name}</span>
                      <span className="text-caption text-text-muted" dir="ltr">
                        {l.plate ?? ''}
                      </span>
                    </span>
                  ),
                },
                { key: 'runs', header: t('settle.runs'), cell: (l) => <span className="tabular">{l.runs}</span> },
                { key: 'cash', header: t('settle.cashKept'), cell: (l) => <span className="tabular">{money(l.cash)}</span> },
                { key: 'cc', header: t('settle.cashCommission'), cell: (l) => <span className="tabular text-text-muted">−{money(l.cashCommission)}</span> },
                {
                  key: 'payout',
                  header: t('settle.payoutCol'),
                  cell: (l) => (
                    <span data-testid="line-payout" data-value={l.payout} className={clsx('tabular font-semibold', l.payout < 0 && 'text-danger')}>
                      {money(l.payout)}
                    </span>
                  ),
                },
              ]}
            />
            <dl className="mt-4 grid gap-2 border-t border-border pt-4 text-caption text-text-muted sm:grid-cols-3">
              <div className="flex justify-between gap-2">
                <dt>{t('settle.unallocated')}</dt>
                <dd className="tabular">{money(s.totals.unallocated)}</dd>
              </div>
              <div className="flex justify-between gap-2">
                <dt>{t('settle.residual')}</dt>
                <dd className="tabular">{money(s.totals.residual)}</dd>
              </div>
              <div className="flex justify-between gap-2">
                <dt>{t('settle.excluded')}</dt>
                <dd className="tabular">{s.excludedRuns}</dd>
              </div>
            </dl>
          </Card>

          <Card animated title={t('settle.tiers')}>
            <Table
              caption={t('settle.tiers')}
              rows={s.tiers}
              rowKey={(x) => x.tierId}
              columns={[
                { key: 'name', header: t('subs.tier'), cell: (x) => <span className="font-medium">{x.name}</span> },
                { key: 'pool', header: t('settle.pool'), cell: (x) => <span className="tabular">{money(x.pool)}</span> },
                { key: 'runs', header: t('settle.runs'), cell: (x) => <span className="tabular">{x.runs}</span> },
                { key: 'commission', header: t('settle.commission'), cell: (x) => <span className="tabular">{money(x.commission)}</span> },
              ]}
            />
          </Card>
        </>
      )}

      {review.length ? (
        <Card animated title={t('settle.review')} description={t('settle.reviewHint')}>
          <ul className="flex flex-col gap-2">
            {review.map((r) => (
              <li key={r.id} data-testid="review-run" className="flex flex-wrap items-center gap-3 rounded-md border border-border p-3">
                <span className="min-w-40 flex-1">
                  <span className="block text-label">{r.driver}</span>
                  <span className="text-caption text-text-muted">
                    <span className="tabular" dir="ltr">
                      {r.date}
                    </span>{' '}
                    · {wave(r)}
                  </span>
                </span>
                <span className="flex flex-wrap gap-1">
                  {r.flags.map((f) => (
                    <Badge key={f} tone={f === 'off_path' ? 'warning' : 'danger'}>
                      {flagLabel(f)}
                    </Badge>
                  ))}
                </span>
                <Badge tone={r.counted ? 'success' : 'neutral'}>{t(r.counted ? 'settle.counted' : 'settle.notCounted')}</Badge>
                {!approved ? (
                  <Button variant="secondary" onClick={() => (setReviewing(r), setNote(r.officeNote ?? ''))}>
                    {t('settle.decide')}
                  </Button>
                ) : null}
              </li>
            ))}
          </ul>
        </Card>
      ) : null}

      <Drawer
        open={confirming}
        title={t('settle.approveTitle')}
        onClose={() => setConfirming(false)}
        footer={
          <>
            <Button icon={BadgeCheck} loading={action.isPending && action.variables?.action === 'approve'} onClick={() => run('approve')}>
              {t('settle.approveConfirm')}
            </Button>
            <Button variant="secondary" onClick={() => setConfirming(false)}>
              {t('common.cancel')}
            </Button>
          </>
        }
      >
        {s ? (
          <div className="flex flex-col gap-4">
            <p className="text-text-muted">{t('settle.approveHint')}</p>
            <p className="text-headline tabular">
              {t('settle.payout')}: {money(s.totals.payout)}
            </p>
            <p className="text-label tabular">
              {t('settle.commission')}: {money(s.totals.commission)}
            </p>
          </div>
        ) : null}
      </Drawer>

      <Drawer
        open={!!reviewing}
        title={t('settle.decideTitle')}
        onClose={() => setReviewing(null)}
        footer={
          <>
            <Button icon={BadgeCheck} loading={verdict.isPending} disabled={note.trim().length < 3} onClick={() => decide(true)}>
              {t('settle.countIt')}
            </Button>
            <Button variant="danger" loading={verdict.isPending} disabled={note.trim().length < 3} onClick={() => decide(false)}>
              {t('settle.excludeIt')}
            </Button>
            {reviewing?.officeVerdict !== null ? (
              <Button variant="secondary" onClick={() => decide(null)}>
                {t('settle.followGps')}
              </Button>
            ) : null}
          </>
        }
      >
        {reviewing ? (
          <div className="flex flex-col gap-4">
            <p className="text-headline">
              {reviewing.driver} · <span dir="ltr">{reviewing.date}</span>
            </p>
            <p className="text-text-muted">{t('settle.trackInfo', { points: String(reviewing.positions), stops: String(reviewing.stops) })}</p>
            <div className="flex flex-wrap gap-1">
              {reviewing.flags.map((f) => (
                <Badge key={f} tone="danger">
                  {flagLabel(f)}
                </Badge>
              ))}
            </div>
            <Textarea id="verdict-note" label={t('settle.note')} value={note} onChange={(e) => setNote(e.target.value)} />
          </div>
        ) : null}
      </Drawer>
    </Stagger>
  );
}
