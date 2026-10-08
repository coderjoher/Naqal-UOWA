import { clsx } from 'clsx';
import { Megaphone, Send, Users } from 'lucide-react';
import { motion } from 'motion/react';
import { useEffect, useState } from 'react';
import { ApiError } from '../lib/api';
import { useI18n } from '../lib/i18n';
import { previewAnnouncement, useAnnounce, useAnnouncements, type AnnouncementInput } from '../lib/ops';
import { usePoints, useWaves } from '../lib/queries';
import { Badge, Button, Card, EmptyState, Input, PageHeader, SkeletonRows, Stagger, Textarea, useToast } from '../ui';
import { itemVariants } from '../ui/motion';

const today = () => new Date(Date.now() + 3 * 3600_000).toISOString().slice(0, 10);

/** TO-11: write to all students, one wave on a date, or one gathering point. */
export function AnnouncementsPage() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const list = useAnnouncements();
  const waves = useWaves();
  const points = usePoints();
  const announce = useAnnounce();
  const [form, setForm] = useState<AnnouncementInput>({ title: '', body: '', target: 'all', date: today(), days: 3 });
  const [count, setCount] = useState<number | null>(null);
  const set = (patch: Partial<AnnouncementInput>) => setForm((f) => ({ ...f, ...patch }));
  const ready = form.title.trim().length >= 2 && form.body.trim().length >= 2 && (form.target === 'all' || (form.target === 'wave' ? !!form.waveId && !!form.date : !!form.pointId));

  // Live recipient count while the office chooses the audience.
  useEffect(() => {
    if (!(form.target === 'all' || (form.target === 'wave' ? form.waveId && form.date : form.pointId))) return setCount(null);
    let live = true;
    previewAnnouncement({ ...form, title: 'xx', body: 'xx' })
      .then((r) => live && setCount(r.recipients))
      .catch(() => live && setCount(null));
    return () => {
      live = false;
    };
  }, [form.target, form.waveId, form.date, form.pointId]);

  async function send() {
    try {
      const a = await announce.mutateAsync({
        title: form.title.trim(),
        body: form.body.trim(),
        target: form.target,
        ...(form.target === 'wave' ? { waveId: form.waveId, date: form.date } : {}),
        ...(form.target === 'point' ? { pointId: form.pointId } : {}),
        ...(form.target !== 'wave' ? { days: form.days } : {}),
      });
      toast('success', t('ann.sent', { n: a.recipients }));
      setForm({ title: '', body: '', target: 'all', date: today(), days: 3 });
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  return (
    <Stagger>
      <PageHeader title={t('ann.title')} description={t('ann.desc')} />
      <div className="grid gap-6 xl:grid-cols-2">
        <Card animated title={t('ann.new')}>
          <div className="flex flex-col gap-4">
            <Input id="ann-title" label={t('ann.titleField')} value={form.title} onChange={(e) => set({ title: e.target.value })} maxLength={120} />
            <Textarea id="ann-body" label={t('ann.body')} value={form.body} onChange={(e) => set({ body: e.target.value })} maxLength={1000} />
            <fieldset className="flex flex-col gap-2">
              <legend className="mb-2 text-label">{t('ann.to')}</legend>
              <div className="grid grid-cols-3 gap-2">
                {(['all', 'wave', 'point'] as const).map((k) => (
                  <label key={k} className={clsx('flex cursor-pointer items-center justify-center gap-2 rounded-md border p-3 text-label transition-colors', form.target === k ? 'border-primary bg-primary-soft text-primary' : 'border-border')}>
                    <input type="radio" className="sr-only" name="ann-target" checked={form.target === k} onChange={() => set({ target: k })} />
                    {t(`ann.target.${k}`)}
                  </label>
                ))}
              </div>
            </fieldset>
            {form.target === 'wave' ? (
              <div className="grid gap-3 sm:grid-cols-2">
                <label className="flex flex-col gap-1.5 text-label">
                  {t('ann.wave')}
                  <select className="h-12 rounded-pill border border-border bg-surface px-5" value={form.waveId ?? ''} onChange={(e) => set({ waveId: e.target.value || undefined })} data-testid="ann-wave">
                    <option value="">—</option>
                    {(waves.data ?? []).filter((w) => w.active).map((w) => (
                      <option key={w.id} value={w.id}>
                        {t(w.type === 'morning' ? 'dispatch.morning' : 'dispatch.return')} {w.time}
                      </option>
                    ))}
                  </select>
                </label>
                <Input id="ann-date" label={t('ann.date')} type="date" dir="ltr" value={form.date ?? ''} onChange={(e) => set({ date: e.target.value })} />
              </div>
            ) : null}
            {form.target === 'point' ? (
              <label className="flex flex-col gap-1.5 text-label">
                {t('ann.point')}
                <select className="h-12 rounded-pill border border-border bg-surface px-5" value={form.pointId ?? ''} onChange={(e) => set({ pointId: e.target.value || undefined })} data-testid="ann-point">
                  <option value="">—</option>
                  {(points.data ?? []).filter((p) => p.active).map((p) => (
                    <option key={p.id} value={p.id}>
                      {(lang === 'ar' && p.nameAr) || p.name}
                    </option>
                  ))}
                </select>
              </label>
            ) : null}
            {form.target !== 'wave' ? (
              <Input id="ann-days" label={t('ann.days')} type="number" min={1} max={30} dir="ltr" value={String(form.days ?? 3)} onChange={(e) => set({ days: Number(e.target.value) || 3 })} />
            ) : null}
            <div className="flex flex-wrap items-center gap-3 border-t border-border pt-4">
              <span className="flex flex-1 items-center gap-2 text-caption text-text-muted" data-testid="ann-count">
                <Users size={16} aria-hidden />
                {count === null ? t('ann.chooseAudience') : t('ann.recipients', { n: count })}
              </span>
              <Button icon={Send} disabled={!ready || count === 0} loading={announce.isPending} onClick={send}>
                {t('ann.send')}
              </Button>
            </div>
          </div>
        </Card>
        <Card animated title={t('ann.sentList')}>
          {list.isPending ? (
            <SkeletonRows />
          ) : !list.data?.length ? (
            <EmptyState icon={Megaphone} title={t('ann.empty')} />
          ) : (
            <ul className="flex flex-col gap-3">
              {list.data.map((a) => (
                <motion.li key={a.id} variants={itemVariants} initial="hidden" animate="show" className="rounded-md border border-border p-4">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="flex-1 text-label">{a.title}</span>
                    <Badge tone="primary">
                      {a.target === 'all'
                        ? t('ann.target.all')
                        : a.target === 'wave'
                          ? `${t(a.wave?.type === 'return' ? 'dispatch.return' : 'dispatch.morning')} ${a.wave?.time ?? ''} · ${a.date}`
                          : ((lang === 'ar' && a.point?.nameAr) || a.point?.name) ?? ''}
                    </Badge>
                  </div>
                  <p className="mt-2 text-text-muted">{a.body}</p>
                  <p className="mt-2 text-caption text-text-muted">
                    {t('ann.recipients', { n: a.recipients })} · {new Date(a.createdAt).toLocaleString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB', { dateStyle: 'medium', timeStyle: 'short' })}
                  </p>
                </motion.li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </Stagger>
  );
}
