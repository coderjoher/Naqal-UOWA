import { clsx } from 'clsx';
import { Ban, Bus, CircleCheck, ExternalLink, FileText, RotateCcw, ShieldCheck, X } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useMemo, useState } from 'react';
import { API_URL } from '../lib/api';
import { useI18n, type MessageKey } from '../lib/i18n';
import { documentLink, errorMessages, useDriver, useDrivers, useReviewDriver, type DriverStatus } from '../lib/queries';
import { Badge, Button, Card, Drawer, EmptyState, PageHeader, Skeleton, SkeletonRows, Stagger, Textarea, useToast, type Tone } from '../ui';
import { itemVariants, listVariants, spring } from '../ui/motion';
import { Errors } from './UniversitiesPage';

const TABS: DriverStatus[] = ['pending', 'approved', 'suspended', 'rejected'];
export const STATUS_TONE: Record<DriverStatus, Tone> = { draft: 'neutral', pending: 'warning', approved: 'success', rejected: 'danger', suspended: 'danger' };

function DocumentPreview({ driverId, docKey, label }: { driverId: string; docKey: string; label: string }) {
  const { t } = useI18n();
  const [link, setLink] = useState<{ url: string; mime: string } | null>(null);
  const [busy, setBusy] = useState(false);
  async function open() {
    setBusy(true);
    try {
      const l = await documentLink(driverId, docKey);
      const res = await fetch(`${API_URL}${l.url}`);
      setLink({ url: URL.createObjectURL(await res.blob()), mime: res.headers.get('content-type') ?? '' });
    } finally {
      setBusy(false);
    }
  }
  if (!link) {
    return (
      <Button variant="secondary" size="sm" icon={FileText} loading={busy} onClick={open}>
        {t('drivers.view')}
      </Button>
    );
  }
  return (
    <motion.div initial={{ opacity: 0, scale: 0.97 }} animate={{ opacity: 1, scale: 1 }} className="col-span-full flex flex-col gap-2">
      {link.mime.startsWith('image/') ? (
        <img src={link.url} alt={label} className="max-h-80 w-full rounded-md border border-border bg-surface-muted object-contain" />
      ) : (
        <a href={link.url} target="_blank" rel="noreferrer" className="inline-flex items-center gap-2 text-label text-primary">
          <ExternalLink className="size-4" aria-hidden /> {t('drivers.openNew')}
        </a>
      )}
      <p className="text-caption text-text-muted">{t('drivers.linkExpires')}</p>
    </motion.div>
  );
}

function DriverPanel({ id, onClose }: { id: string; onClose: () => void }) {
  const { t, lang } = useI18n();
  const toast = useToast();
  const q = useDriver(id);
  const review = useReviewDriver();
  const [mode, setMode] = useState<null | 'reject' | 'suspend'>(null);
  const [note, setNote] = useState('');
  const d = q.data;

  async function act(action: 'approve' | 'reject' | 'suspend' | 'reinstate') {
    if ((action === 'reject' || action === 'suspend') && !note.trim()) return;
    try {
      await review.mutateAsync({ id, action, note: note.trim() || undefined });
      toast('success', t('drivers.done'));
      setMode(null);
      setNote('');
      onClose();
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  if (!d) return <SkeletonRows rows={6} />;
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-4">
        <span className="grid size-14 place-items-center rounded-pill bg-primary-soft text-title text-primary" aria-hidden>
          {d.name.slice(0, 1) || '?'}
        </span>
        <div className="min-w-0 flex-1">
          <p className="text-headline">{d.name || '—'}</p>
          <p className="text-caption text-text-muted" dir="ltr">
            {d.phone}
          </p>
        </div>
        <Badge tone={STATUS_TONE[d.status]}>{t(`drivers.status.${d.status}` as MessageKey)}</Badge>
      </div>
      {d.reviewNote ? (
        <p className="rounded-md bg-surface-muted p-3 text-caption">
          <span className="font-medium">{t('drivers.note')}: </span>
          {d.reviewNote}
        </p>
      ) : null}
      <dl className="grid grid-cols-2 gap-4 rounded-md border border-border p-4">
        <div>
          <dt className="text-caption text-text-muted">{t('drivers.vehicle')}</dt>
          <dd className="text-label">{d.vehicleType ? t(`req.${d.vehicleType}` as MessageKey) ?? d.vehicleType : '—'} · {d.seats ?? '—'} {t('drivers.seats')}</dd>
        </div>
        <div>
          <dt className="text-caption text-text-muted">{t('drivers.model')}</dt>
          <dd className="text-label tabular">{d.modelYear ?? '—'}</dd>
        </div>
        <div className="col-span-2">
          <dt className="text-caption text-text-muted">{t('drivers.plate')}</dt>
          <dd className="text-label">{d.plate ?? '—'}</dd>
        </div>
      </dl>
      <section className="flex flex-col gap-3">
        <h3 className="text-headline">{t('drivers.documents')}</h3>
        {d.documents.map((doc) => (
          <div key={doc.key} className="grid grid-cols-[auto_1fr_auto] items-center gap-3 rounded-md border border-border p-3">
            <span className={clsx('grid size-9 place-items-center rounded-pill', doc.uploaded ? 'bg-success-soft text-success' : 'bg-danger-soft text-danger')} aria-hidden>
              {doc.uploaded ? <CircleCheck className="size-4" /> : <X className="size-4" />}
            </span>
            <span className="text-label">{(lang === 'ar' && doc.labelAr) || doc.label}</span>
            {doc.uploaded ? <DocumentPreview driverId={id} docKey={doc.key} label={(lang === 'ar' && doc.labelAr) || doc.label} /> : <span className="text-caption text-danger">{t('drivers.missingDoc')}</span>}
          </div>
        ))}
      </section>

      <AnimatePresence>
        {mode ? (
          <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: 'auto' }} exit={{ opacity: 0, height: 0 }} transition={spring} className="overflow-hidden">
            <Textarea id="review-note" label={t('drivers.reason')} value={note} onChange={(e) => setNote(e.target.value)} error={note.trim() ? undefined : t('drivers.reasonRequired')} />
          </motion.div>
        ) : null}
      </AnimatePresence>
      <Errors messages={errorMessages(review.error)} />
      <div className="flex flex-wrap gap-3">
        {d.status === 'pending' ? (
          mode === 'reject' ? (
            <>
              <Button variant="danger" icon={Ban} loading={review.isPending} disabled={!note.trim()} onClick={() => act('reject')}>
                {t('drivers.reject')}
              </Button>
              <Button variant="secondary" onClick={() => setMode(null)}>
                {t('common.cancel')}
              </Button>
            </>
          ) : (
            <>
              <Button icon={ShieldCheck} loading={review.isPending} disabled={d.missing.length > 0} onClick={() => act('approve')}>
                {t('drivers.approve')}
              </Button>
              <Button variant="secondary" icon={Ban} onClick={() => setMode('reject')}>
                {t('drivers.reject')}
              </Button>
            </>
          )
        ) : null}
        {d.status === 'approved' ? (
          mode === 'suspend' ? (
            <>
              <Button variant="danger" icon={Ban} loading={review.isPending} disabled={!note.trim()} onClick={() => act('suspend')}>
                {t('drivers.suspend')}
              </Button>
              <Button variant="secondary" onClick={() => setMode(null)}>
                {t('common.cancel')}
              </Button>
            </>
          ) : (
            <Button variant="secondary" icon={Ban} onClick={() => setMode('suspend')}>
              {t('drivers.suspend')}
            </Button>
          )
        ) : null}
        {d.status === 'suspended' ? (
          <Button icon={RotateCcw} loading={review.isPending} onClick={() => act('reinstate')}>
            {t('drivers.reinstate')}
          </Button>
        ) : null}
      </div>
    </div>
  );
}

export function DriversPage() {
  const { t, lang } = useI18n();
  const q = useDrivers();
  const [tab, setTab] = useState<DriverStatus>('pending');
  const [open, setOpen] = useState<string | null>(null);
  const counts = useMemo(() => Object.fromEntries(TABS.map((s) => [s, q.data?.filter((d) => d.status === s).length ?? 0])), [q.data]);
  const rows = q.data?.filter((d) => d.status === tab) ?? [];
  const date = (iso: string | null) => (iso ? new Date(iso).toLocaleDateString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB', { day: 'numeric', month: 'short' }) : '—');

  return (
    <Stagger>
      <PageHeader title={t('drivers.title')} description={t('drivers.desc')} />
      <motion.div variants={itemVariants} role="tablist" aria-label={t('drivers.title')} className="flex flex-wrap gap-2">
        {TABS.map((s) => (
          <button
            key={s}
            role="tab"
            aria-selected={tab === s}
            onClick={() => setTab(s)}
            className={clsx('relative flex h-11 items-center gap-2 rounded-pill px-5 text-label transition-colors duration-200', tab === s ? 'text-on-primary' : 'bg-surface text-text hover:bg-surface-muted')}
          >
            {tab === s ? <motion.span layoutId="driver-tab" className="absolute inset-0 rounded-pill bg-primary" transition={spring} /> : null}
            <span className="relative">{t(`drivers.tab.${s}` as MessageKey)}</span>
            <span className={clsx('relative grid h-6 min-w-6 place-items-center rounded-pill px-2 text-caption tabular', tab === s ? 'bg-on-primary text-primary' : 'bg-surface-muted text-text-muted')}>{counts[s]}</span>
          </button>
        ))}
      </motion.div>
      <Card animated>
        {q.isPending ? (
          <SkeletonRows />
        ) : rows.length === 0 ? (
          <EmptyState icon={Bus} title={t('drivers.emptyTitle')} message={t('drivers.emptyBody')} />
        ) : (
          <motion.ul key={tab} variants={listVariants} initial="hidden" animate="show" className="flex flex-col gap-2">
            {rows.map((d) => (
              <motion.li key={d.id} variants={itemVariants}>
                <button type="button" onClick={() => setOpen(d.id)} className="flex w-full items-center gap-4 rounded-md border border-border p-4 text-start transition-colors duration-200 hover:border-primary hover:bg-primary-soft">
                  <span className="grid size-11 shrink-0 place-items-center rounded-pill bg-primary-soft text-headline text-primary" aria-hidden>
                    {d.name.slice(0, 1) || '?'}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-label">{d.name || '—'}</span>
                    <span className="block truncate text-caption text-text-muted">
                      {d.vehicleType ? t(`req.${d.vehicleType}` as MessageKey) : '—'} · {d.seats ?? '—'} {t('drivers.seats')} · {d.plate ?? '—'}
                    </span>
                  </span>
                  <span className="hidden text-caption text-text-muted sm:block">
                    {t('drivers.submitted')}: {date(d.submittedAt)}
                  </span>
                  <Badge tone={STATUS_TONE[d.status]}>{t(`drivers.status.${d.status}` as MessageKey)}</Badge>
                </button>
              </motion.li>
            ))}
          </motion.ul>
        )}
      </Card>
      <Drawer open={!!open} title={t('drivers.title')} onClose={() => setOpen(null)}>
        {open ? <DriverPanel id={open} onClose={() => setOpen(null)} /> : <Skeleton className="h-40" />}
      </Drawer>
    </Stagger>
  );
}
