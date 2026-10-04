import { clsx } from 'clsx';
import { Check, FileText, Plus, Trash2 } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useEffect, useState } from 'react';
import { useI18n, type MessageKey } from '../../lib/i18n';
import { errorMessages, useRequirements, useSaveRequirements, type DriverRequirements } from '../../lib/queries';
import { Button, Card, IconButton, Input, PageHeader, SkeletonRows, Stagger, useToast } from '../../ui';
import { spring } from '../../ui/motion';
import { Errors } from '../UniversitiesPage';

const VEHICLES = ['coaster', 'minibus', 'bus', 'van'] as const;

const toKey = (label: string, i: number) =>
  label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/^(\d)/, 'd$1')
    .slice(0, 40) || `document_${i + 1}`;

export function RequirementsPage() {
  const { t } = useI18n();
  const toast = useToast();
  const q = useRequirements();
  const save = useSaveRequirements();
  const [form, setForm] = useState<DriverRequirements | null>(null);

  useEffect(() => {
    if (q.data && !form) setForm(structuredClone(q.data));
  }, [q.data, form]);

  async function submit() {
    if (!form) return;
    const body = { ...form, documents: form.documents.map((d, i) => ({ ...d, key: d.key || toKey(d.label, i) })) };
    try {
      setForm(await save.mutateAsync(body));
      toast('success', t('req.saved'));
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  return (
    <Stagger>
      <PageHeader
        title={t('req.title')}
        description={t('req.desc')}
        actions={
          <Button onClick={submit} loading={save.isPending} disabled={!form}>
            {t('req.save')}
          </Button>
        }
      />
      <Errors messages={errorMessages(save.error)} />
      {!form ? (
        <Card animated>
          <SkeletonRows />
        </Card>
      ) : (
        <div className="grid gap-6 lg:grid-cols-[minmax(0,1.4fr)_minmax(0,1fr)]">
          <Card
            animated
            title={t('req.documents')}
            actions={
              <Button variant="secondary" size="sm" icon={Plus} onClick={() => setForm({ ...form, documents: [...form.documents, { key: '', label: '', labelAr: '', required: true }] })}>
                {t('req.addDoc')}
              </Button>
            }
          >
            <ul className="flex flex-col gap-3">
              <AnimatePresence initial={false}>
                {form.documents.map((d, i) => (
                  <motion.li key={i} layout initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={spring} className="rounded-md border border-border p-4">
                    <div className="grid items-end gap-3 sm:grid-cols-[auto_minmax(0,1fr)_minmax(0,1fr)_auto_auto]">
                      <span className="mb-1 grid size-10 place-items-center rounded-pill bg-primary-soft text-primary" aria-hidden>
                        <FileText className="size-5" />
                      </span>
                      <Input id={`doc-ar-${i}`} label={t('req.docLabelAr')} value={d.labelAr ?? ''} onChange={(e) => setForm({ ...form, documents: form.documents.map((x, j) => (j === i ? { ...x, labelAr: e.target.value } : x)) })} />
                      <Input id={`doc-en-${i}`} label={t('req.docLabel')} dir="ltr" value={d.label} onChange={(e) => setForm({ ...form, documents: form.documents.map((x, j) => (j === i ? { ...x, label: e.target.value } : x)) })} />
                      <label className="mb-3 flex items-center gap-2 text-label">
                        <input
                          type="checkbox"
                          className="size-5 accent-primary"
                          checked={d.required}
                          onChange={(e) => setForm({ ...form, documents: form.documents.map((x, j) => (j === i ? { ...x, required: e.target.checked } : x)) })}
                        />
                        {t('req.required')}
                      </label>
                      <IconButton icon={Trash2} tone="danger" label={t('common.cancel')} className="mb-1" onClick={() => setForm({ ...form, documents: form.documents.filter((_, j) => j !== i) })} />
                    </div>
                  </motion.li>
                ))}
              </AnimatePresence>
            </ul>
          </Card>
          <Card animated title={t('req.vehicle')}>
            <div className="flex flex-col gap-6">
              <fieldset>
                <legend className="mb-3 text-label">{t('req.vehicleTypes')}</legend>
                <div className="flex flex-wrap gap-2">
                  {VEHICLES.map((v) => {
                    const on = form.vehicleTypes.includes(v);
                    return (
                      <motion.button
                        key={v}
                        type="button"
                        aria-pressed={on}
                        whileTap={{ scale: 0.94 }}
                        onClick={() => setForm({ ...form, vehicleTypes: on ? form.vehicleTypes.filter((x) => x !== v) : [...form.vehicleTypes, v] })}
                        className={clsx(
                          'flex h-10 items-center gap-2 rounded-pill border px-4 text-label transition-colors duration-200',
                          on ? 'border-primary bg-primary text-on-primary' : 'border-border bg-surface hover:bg-surface-muted',
                        )}
                      >
                        {on ? <Check className="size-4" aria-hidden /> : null}
                        {t(`req.${v}` as MessageKey)}
                      </motion.button>
                    );
                  })}
                </div>
              </fieldset>
              <Input id="req-seats" label={t('req.minSeats')} dir="ltr" inputMode="numeric" value={String(form.minSeats)} onChange={(e) => setForm({ ...form, minSeats: Number(e.target.value) || 0 })} />
              <Input id="req-age" label={t('req.maxAge')} dir="ltr" inputMode="numeric" value={String(form.maxVehicleAgeYears)} onChange={(e) => setForm({ ...form, maxVehicleAgeYears: Number(e.target.value) || 0 })} />
            </div>
          </Card>
        </div>
      )}
    </Stagger>
  );
}
