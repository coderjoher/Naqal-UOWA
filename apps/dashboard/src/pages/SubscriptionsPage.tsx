import { clsx } from 'clsx';
import { Banknote, CircleCheck, Download, ReceiptText, Search, Undo2, UserRound } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useMemo, useState, type FormEvent } from 'react';
import { ApiError } from '../lib/api';
import { useI18n, useMoney } from '../lib/i18n';
import { downloadReceipt, subscriptionPreview, useRecordSubscription, useReversePayment, useSubscriptions, type SubscriptionPreview, type SubscriptionRow } from '../lib/queries';
import { Badge, Button, Card, Drawer, EmptyState, IconButton, Input, Kpi, KpiGrid, PageHeader, SkeletonRows, Stagger, Table, Textarea, useToast } from '../ui';
import { spring } from '../ui/motion';

const thisMonth = () => {
  const d = new Date(Date.now() + 3 * 3600_000); // Baghdad
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
};

function RecordPayment({ month }: { month: string }) {
  const { t, lang } = useI18n();
  const money = useMoney();
  const toast = useToast();
  const record = useRecordSubscription();
  const [number, setNumber] = useState('');
  const [preview, setPreview] = useState<SubscriptionPreview | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [finding, setFinding] = useState(false);
  const [done, setDone] = useState<{ id: string; receiptNo: number; amount: number } | null>(null);

  async function find(e: FormEvent) {
    e.preventDefault();
    if (!number.trim()) return;
    setFinding(true);
    setError(null);
    setPreview(null);
    setDone(null);
    try {
      setPreview(await subscriptionPreview(number.trim(), month));
    } catch (err) {
      setError(err instanceof ApiError && err.status === 404 ? t('subs.notFound') : t('common.error'));
    } finally {
      setFinding(false);
    }
  }

  async function confirm() {
    if (!preview) return;
    try {
      const res = await record.mutateAsync({ studentId: preview.student.studentId ?? preview.student.id, month });
      setDone(res.payment);
      toast('success', t('subs.recorded'));
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  function reset() {
    setNumber('');
    setPreview(null);
    setDone(null);
  }

  const blocked = preview && (!preview.point || preview.alreadySubscribed);
  return (
    <Card animated title={t('subs.record')}>
      <form onSubmit={find} className="flex flex-wrap items-end gap-3">
        <Input id="sub-student" className="min-w-56 flex-1" label={t('subs.studentNumber')} dir="ltr" value={number} onChange={(e) => setNumber(e.target.value)} error={error ?? undefined} />
        <Button type="submit" variant="secondary" icon={Search} loading={finding} className="mb-0.5">
          {t('subs.find')}
        </Button>
      </form>
      <AnimatePresence mode="wait">
        {preview && !done ? (
          <motion.div key="preview" initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -6 }} transition={spring} className="mt-6 grid gap-4 rounded-md border border-border p-5 sm:grid-cols-[auto_1fr_auto] sm:items-center">
            <span className="grid size-14 place-items-center rounded-pill bg-primary-soft text-primary" aria-hidden>
              <UserRound className="size-7" />
            </span>
            <div className="min-w-0">
              <p className="text-headline">{(lang === 'ar' && preview.student.nameAr) || preview.student.name}</p>
              <p className="mt-1 flex flex-wrap items-center gap-2 text-caption text-text-muted">
                <span dir="ltr">{preview.student.studentId}</span>
                {preview.student.gender ? <Badge tone={preview.student.gender === 'female' ? 'female-only' : 'primary'}>{t(preview.student.gender === 'female' ? 'students.female' : 'students.male')}</Badge> : null}
                {preview.point ? (
                  <span>
                    {t('subs.point')}: {(lang === 'ar' && preview.point.nameAr) || preview.point.name} · {t('subs.tier')} {preview.tier?.name}
                  </span>
                ) : null}
              </p>
              {blocked ? (
                <p role="alert" className="mt-2 text-caption text-danger">
                  {!preview.point ? t('subs.noPoint') : t('subs.already')}
                </p>
              ) : null}
            </div>
            <div className="flex flex-col items-stretch gap-2 sm:items-end">
              {preview.price !== null ? <p className="text-title tabular">{money(preview.price)}</p> : null}
              <Button icon={Banknote} loading={record.isPending} disabled={!!blocked} onClick={confirm}>
                {t('subs.confirm')}
              </Button>
            </div>
          </motion.div>
        ) : null}
        {done ? (
          <motion.div key="done" initial={{ opacity: 0, scale: 0.97 }} animate={{ opacity: 1, scale: 1 }} transition={spring} className="mt-6 flex flex-wrap items-center gap-5 rounded-md bg-success-soft p-5">
            <motion.span initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ ...spring, delay: 0.1 }} className="grid size-14 place-items-center rounded-pill bg-success text-on-primary" aria-hidden>
              <CircleCheck className="size-7" />
            </motion.span>
            <div className="min-w-0 flex-1">
              <p className="text-headline text-success">{t('subs.recorded')}</p>
              <p className="text-label">
                {t('subs.receiptNo')}: <span className="tabular" data-testid="receipt-no">{done.receiptNo}</span> · {money(done.amount)}
              </p>
            </div>
            <Button icon={Download} onClick={() => downloadReceipt(done.id, done.receiptNo).catch(() => toast('danger', t('common.error')))}>
              {t('subs.download')}
            </Button>
            <Button variant="secondary" onClick={reset}>
              {t('subs.next')}
            </Button>
          </motion.div>
        ) : null}
      </AnimatePresence>
    </Card>
  );
}

export function SubscriptionsPage() {
  const { t, lang } = useI18n();
  const money = useMoney();
  const toast = useToast();
  const [month, setMonth] = useState(thisMonth());
  const q = useSubscriptions(month);
  const reverse = useReversePayment();
  const [reversing, setReversing] = useState<SubscriptionRow | null>(null);
  const [reason, setReason] = useState('');

  const stats = useMemo(() => {
    const rows = q.data ?? [];
    return { count: rows.filter((r) => r.status === 'active').length, total: rows.filter((r) => r.status === 'active').reduce((s, r) => s + r.price, 0) };
  }, [q.data]);

  async function doReverse() {
    if (!reversing || reason.trim().length < 3) return;
    try {
      await reverse.mutateAsync({ id: reversing.paymentId, reason: reason.trim() });
      toast('success', t('subs.reversed'));
      setReversing(null);
      setReason('');
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  return (
    <Stagger>
      <PageHeader
        title={t('subs.title')}
        description={t('subs.desc')}
        actions={<Input id="sub-month" label={t('subs.month')} type="month" dir="ltr" value={month} onChange={(e) => e.target.value && setMonth(e.target.value)} />}
      />
      <KpiGrid cols={2}>
        <Kpi tone="brand" icon={ReceiptText} label={t('subs.count')} value={stats.count} loading={q.isPending} />
        <Kpi tone="gold" compact icon={Banknote} label={t('subs.total')} value={stats.total} format={(n) => money(n)} loading={q.isPending} />
      </KpiGrid>
      <RecordPayment month={month} />
      <Card animated title={t('subs.list')}>
        {q.isPending ? (
          <SkeletonRows />
        ) : (
          <Table
            caption={t('subs.list')}
            rows={q.data ?? []}
            rowKey={(r) => r.id}
            empty={<EmptyState icon={ReceiptText} title={t('subs.empty')} />}
            columns={[
              { key: 'no', header: t('subs.receiptNo'), cell: (r) => <span className="tabular text-text-muted">#{r.payment.receiptNo}</span> },
              {
                key: 'student',
                header: t('subs.student'),
                cell: (r) => (
                  <span className="flex flex-col">
                    <span className="font-medium">{(lang === 'ar' && r.student.nameAr) || r.student.name}</span>
                    <span className="text-caption text-text-muted" dir="ltr">
                      {r.student.studentId}
                    </span>
                  </span>
                ),
              },
              { key: 'amount', header: t('subs.amount'), cell: (r) => <span className={clsx('tabular', r.status === 'cancelled' && 'line-through opacity-60')}>{money(r.price)}</span> },
              { key: 'date', header: t('subs.date'), cell: (r) => <span className="tabular">{new Date(r.createdAt).toLocaleDateString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB')}</span> },
              { key: 'status', header: t('subs.status'), cell: (r) => <Badge tone={r.status === 'active' ? 'success' : 'danger'}>{t(r.status === 'active' ? 'subs.active' : 'subs.cancelled')}</Badge> },
              {
                key: 'actions',
                header: t('common.actions'),
                cell: (r) => (
                  <span className="flex gap-2">
                    <IconButton icon={Download} label={t('subs.download')} onClick={() => downloadReceipt(r.paymentId, r.payment.receiptNo)} />
                    {r.status === 'active' ? <IconButton icon={Undo2} tone="danger" label={t('subs.reverse')} onClick={() => setReversing(r)} /> : null}
                  </span>
                ),
              },
            ]}
          />
        )}
      </Card>
      <Drawer
        open={!!reversing}
        title={t('subs.reverseTitle')}
        onClose={() => setReversing(null)}
        footer={
          <>
            <Button variant="danger" icon={Undo2} loading={reverse.isPending} disabled={reason.trim().length < 3} onClick={doReverse}>
              {t('subs.reverse')}
            </Button>
            <Button variant="secondary" onClick={() => setReversing(null)}>
              {t('common.cancel')}
            </Button>
          </>
        }
      >
        {reversing ? (
          <div className="flex flex-col gap-5">
            <p className="text-text-muted">{t('subs.reverseHint')}</p>
            <p className="text-headline">
              #{reversing.payment.receiptNo} · {(lang === 'ar' && reversing.student.nameAr) || reversing.student.name} · {money(reversing.price)}
            </p>
            <Textarea id="reverse-reason" label={t('subs.reason')} value={reason} onChange={(e) => setReason(e.target.value)} />
          </div>
        ) : null}
      </Drawer>
    </Stagger>
  );
}
