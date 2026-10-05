import { clsx } from 'clsx';
import { Download, Gauge, Hourglass, Repeat, Timer, Users, Wallet } from 'lucide-react';
import { motion } from 'motion/react';
import { useState } from 'react';
import { useI18n, useMoney } from '../lib/i18n';
import { baghdadMonth, downloadFile } from '../lib/money';
import { useReport, type Rate } from '../lib/ops';
import { useTiers } from '../lib/queries';
import { AnimatedNumber, Button, Card, EmptyState, Input, PageHeader, SkeletonRows, Stagger, Table, useToast } from '../ui';
import { itemVariants, spring } from '../ui/motion';

function Metric({ icon: Icon, label, rate, hint, testId, invert }: { icon: typeof Gauge; label: string; rate: Rate; hint: string; testId: string; invert?: boolean }) {
  const good = rate.value == null ? null : invert ? rate.value <= 10 : rate.value >= 90;
  return (
    <motion.div variants={itemVariants} whileHover={{ y: -3 }} transition={spring} className="flex flex-col gap-3 rounded-lg bg-surface p-5 shadow-card">
      <div className="flex items-center gap-3">
        <span className={clsx('grid size-10 place-items-center rounded-md', good === null ? 'bg-surface-muted text-text-muted' : good ? 'bg-success-soft text-success' : 'bg-warning-soft text-warning')} aria-hidden>
          <Icon className="size-5" />
        </span>
        <p className="text-label">{label}</p>
      </div>
      <p className="text-title tabular" data-testid={testId} data-value={rate.value ?? ''}>
        {rate.value == null ? '—' : <AnimatedNumber value={Math.round(rate.value * 10)} format={(n) => `${(n / 10).toFixed(1)}%`} />}
      </p>
      <div className="h-2 overflow-hidden rounded-pill bg-surface-muted" aria-hidden>
        <motion.div className={clsx('h-full rounded-pill', good === false ? 'bg-warning' : 'bg-primary')} initial={{ width: 0 }} animate={{ width: `${rate.value ?? 0}%` }} transition={{ duration: 0.7, ease: 'easeOut' }} />
      </div>
      <p className="text-caption text-text-muted">
        <span className="tabular">
          {rate.num}/{rate.den}
        </span>{' '}
        · {hint}
      </p>
    </motion.div>
  );
}

/** TO-10: monthly service and money figures, by tier, with CSV export. */
export function ReportsPage() {
  const { t } = useI18n();
  const money = useMoney();
  const toast = useToast();
  const [month, setMonth] = useState(baghdadMonth());
  const [tierId, setTierId] = useState('');
  const tiers = useTiers();
  const q = useReport(month, tierId);
  const r = q.data;

  const csv = () => downloadFile(`/reports/export.csv?month=${month}${tierId ? `&tierId=${tierId}` : ''}`, `report-${month}.csv`).catch(() => toast('danger', t('common.error')));

  return (
    <Stagger>
      <PageHeader
        title={t('reports.title')}
        description={t('reports.desc')}
        actions={
          <div className="flex flex-wrap items-end gap-3">
            <Input id="report-month" label={t('subs.month')} type="month" dir="ltr" value={month} onChange={(e) => e.target.value && setMonth(e.target.value)} />
            <label className="flex flex-col gap-1.5 text-label">
              {t('subs.tier')}
              <select className="h-11 rounded-md border border-border bg-surface px-3" value={tierId} onChange={(e) => setTierId(e.target.value)} data-testid="report-tier">
                <option value="">{t('reports.allTiers')}</option>
                {(tiers.data ?? []).map((x) => (
                  <option key={x.id} value={x.id}>
                    {x.name}
                  </option>
                ))}
              </select>
            </label>
            <Button variant="secondary" icon={Download} onClick={csv} className="mb-0.5">
              CSV
            </Button>
          </div>
        }
      />
      {q.isPending || !r ? (
        <Card>
          <SkeletonRows />
        </Card>
      ) : (
        <>
          <motion.div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4" variants={{ show: { transition: { staggerChildren: 0.05 } } }}>
            <Metric icon={Gauge} label={t('reports.fulfilment')} rate={r.fulfilment} hint={t('reports.fulfilmentHint')} testId="m-fulfilment" />
            <Metric icon={Timer} label={t('reports.onTime')} rate={r.onTime} hint={t('reports.onTimeHint')} testId="m-ontime" />
            <Metric icon={Hourglass} label={t('reports.expiry')} rate={r.waitlistExpiry} hint={t('reports.expiryHint')} testId="m-expiry" invert />
            <Metric icon={Repeat} label={t('reports.renewal')} rate={r.renewal} hint={t('reports.renewalHint')} testId="m-renewal" />
          </motion.div>
          <motion.div variants={itemVariants} className="grid gap-4 sm:grid-cols-3">
            {[
              { icon: Users, label: t('reports.subscribers'), value: r.subscribers, testId: 'm-subscribers' },
              { icon: Gauge, label: t('reports.runs'), value: r.runs, testId: 'm-runs' },
              { icon: Wallet, label: t('reports.revenue'), value: r.revenue, testId: 'm-revenue', money: true },
            ].map((k) => (
              <div key={k.label} className="flex items-center gap-4 rounded-lg bg-surface p-5 shadow-card">
                <span className="grid size-12 place-items-center rounded-md bg-primary-soft text-primary" aria-hidden>
                  <k.icon className="size-6" />
                </span>
                <div>
                  <p className="text-title" data-testid={k.testId} data-value={k.value}>
                    <AnimatedNumber value={k.value} format={k.money ? money : undefined} />
                  </p>
                  <p className="text-caption text-text-muted">{k.label}</p>
                </div>
              </div>
            ))}
          </motion.div>
          <Card animated title={t('reports.byTier')}>
            <Table
              caption={t('reports.byTier')}
              rows={r.tiers}
              rowKey={(x) => x.tierId}
              empty={<EmptyState icon={Wallet} title={t('reports.empty')} />}
              columns={[
                { key: 'name', header: t('subs.tier'), cell: (x) => <span className="font-medium">{x.name}</span> },
                { key: 'subs', header: t('reports.subscribers'), cell: (x) => <span className="tabular">{x.subscribers}</span> },
                { key: 'subscriptions', header: t('reports.subscriptions'), cell: (x) => <span className="tabular">{money(x.subscriptions)}</span> },
                { key: 'cash', header: t('reports.cash'), cell: (x) => <span className="tabular">{money(x.cash)}</span> },
                { key: 'revenue', header: t('reports.revenue'), cell: (x) => <span className="tabular font-semibold">{money(x.revenue)}</span> },
              ]}
            />
          </Card>
        </>
      )}
    </Stagger>
  );
}
