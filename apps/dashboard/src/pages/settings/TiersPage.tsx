import { Layers, Plus, Trash2 } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useEffect, useState } from 'react';
import { useI18n, useMoney } from '../../lib/i18n';
import { errorMessages, useSaveTiers, useTiers, type TierInput } from '../../lib/queries';
import { Button, Card, EmptyState, IconButton, Input, PageHeader, SkeletonRows, Stagger, useToast } from '../../ui';
import { spring } from '../../ui/motion';
import { Errors } from '../UniversitiesPage';

interface Row extends Omit<TierInput, 'minKm' | 'maxKm' | 'subscriptionPrice' | 'ridePrice'> {
  key: string;
  minKm: string;
  maxKm: string;
  subscriptionPrice: string;
  ridePrice: string;
}

let seq = 0;
const SUGGESTED: Omit<Row, 'key'>[] = [
  { name: 'A', minKm: '0', maxKm: '5', subscriptionPrice: '40000', ridePrice: '1500' },
  { name: 'B', minKm: '5', maxKm: '15', subscriptionPrice: '60000', ridePrice: '2000' },
  { name: 'C', minKm: '15', maxKm: '', subscriptionPrice: '80000', ridePrice: '3000' },
];

/** Tiers are edited as one set because they must stay contiguous (the API validates the whole set). */
export function TiersPage() {
  const { t } = useI18n();
  const money = useMoney();
  const toast = useToast();
  const q = useTiers();
  const save = useSaveTiers();
  const [rows, setRows] = useState<Row[] | null>(null);

  useEffect(() => {
    if (q.data && rows === null) {
      setRows(
        q.data.map((x) => ({ key: x.id, id: x.id, name: x.name, minKm: String(x.minKm), maxKm: x.maxKm === null ? '' : String(x.maxKm), subscriptionPrice: String(x.subscriptionPrice), ridePrice: String(x.ridePrice) })),
      );
    }
  }, [q.data, rows]);

  const update = (key: string, k: keyof Row, v: string) =>
    setRows((rs) => {
      const next = rs!.map((r) => (r.key === key ? { ...r, [k]: v } : r));
      // Keep tiers contiguous while typing: a tier's "to" becomes the next tier's "from".
      if (k === 'maxKm') {
        const i = next.findIndex((r) => r.key === key);
        if (next[i + 1]) next[i + 1] = { ...next[i + 1], minKm: v };
      }
      return next;
    });

  const add = () =>
    setRows((rs) => {
      const list = rs ?? [];
      const last = list[list.length - 1];
      const from = last ? (last.maxKm || String(Number(last.minKm) + 10)) : '0';
      const patched = last && !last.maxKm ? list.map((r, i) => (i === list.length - 1 ? { ...r, maxKm: from } : r)) : list;
      return [...patched, { key: `new-${++seq}`, name: String.fromCharCode(65 + list.length), minKm: from, maxKm: '', subscriptionPrice: '', ridePrice: '' }];
    });

  const remove = (key: string) => setRows((rs) => rs!.filter((r) => r.key !== key));

  async function submit() {
    const tiers: TierInput[] = rows!.map((r) => ({
      id: r.id,
      name: r.name,
      minKm: Number(r.minKm),
      maxKm: r.maxKm === '' ? null : Number(r.maxKm),
      subscriptionPrice: Number(r.subscriptionPrice),
      ridePrice: Number(r.ridePrice),
    }));
    try {
      const saved = await save.mutateAsync(tiers);
      setRows(saved.map((x) => ({ key: x.id, id: x.id, name: x.name, minKm: String(x.minKm), maxKm: x.maxKm === null ? '' : String(x.maxKm), subscriptionPrice: String(x.subscriptionPrice), ridePrice: String(x.ridePrice) })));
      toast('success', t('tiers.saved'));
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  return (
    <Stagger>
      <PageHeader
        title={t('tiers.title')}
        description={t('tiers.desc')}
        actions={
          rows && rows.length > 0 ? (
            <>
              <Button variant="secondary" icon={Plus} onClick={add}>
                {t('tiers.add')}
              </Button>
              <Button onClick={submit} loading={save.isPending}>
                {t('tiers.save')}
              </Button>
            </>
          ) : null
        }
      />
      {rows === null ? (
        <Card animated>
          <SkeletonRows rows={3} />
        </Card>
      ) : rows.length === 0 ? (
        <Card animated>
          <EmptyState
            icon={Layers}
            title={t('tiers.emptyTitle')}
            message={t('tiers.emptyBody')}
            action={<Button onClick={() => setRows(SUGGESTED.map((r) => ({ ...r, key: `new-${++seq}` })))}>{t('tiers.useDefaults')}</Button>}
          />
        </Card>
      ) : (
        <>
          <Errors messages={errorMessages(save.error)} />
          <div className="flex flex-col gap-4">
            <AnimatePresence initial={false}>
              {rows.map((r, i) => (
                <motion.div key={r.key} layout initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, scale: 0.98 }} transition={spring}>
                  <Card>
                    <div className="grid items-end gap-4 md:grid-cols-[minmax(0,1.2fr)_repeat(4,minmax(0,1fr))_auto]">
                      <Input id={`tier-name-${i}`} label={t('tiers.name')} value={r.name} onChange={(e) => update(r.key, 'name', e.target.value)} />
                      <Input id={`tier-from-${i}`} label={t('tiers.from')} dir="ltr" inputMode="decimal" value={r.minKm} disabled={i > 0} onChange={(e) => update(r.key, 'minKm', e.target.value)} />
                      <Input
                        id={`tier-to-${i}`}
                        label={t('tiers.to')}
                        dir="ltr"
                        inputMode="decimal"
                        placeholder={i === rows.length - 1 ? t('tiers.open') : ''}
                        value={r.maxKm}
                        onChange={(e) => update(r.key, 'maxKm', e.target.value)}
                      />
                      <Input id={`tier-sub-${i}`} label={t('tiers.sub')} dir="ltr" inputMode="numeric" suffix={t('tiers.iqd')} value={r.subscriptionPrice} onChange={(e) => update(r.key, 'subscriptionPrice', e.target.value)} />
                      <Input id={`tier-ride-${i}`} label={t('tiers.ride')} dir="ltr" inputMode="numeric" suffix={t('tiers.iqd')} value={r.ridePrice} onChange={(e) => update(r.key, 'ridePrice', e.target.value)} />
                      <IconButton icon={Trash2} tone="danger" label={t('tiers.remove')} onClick={() => remove(r.key)} disabled={rows.length === 1} className="mb-1" />
                    </div>
                    {Number(r.subscriptionPrice) > 0 ? (
                      <p className="mt-3 text-caption text-text-muted">
                        {t('tiers.preview')}: {r.minKm || 0}–{r.maxKm || '∞'} {t('points.km')} · {money(Number(r.subscriptionPrice))} / {money(Number(r.ridePrice || 0))}
                      </p>
                    ) : null}
                  </Card>
                </motion.div>
              ))}
            </AnimatePresence>
          </div>
        </>
      )}
    </Stagger>
  );
}
