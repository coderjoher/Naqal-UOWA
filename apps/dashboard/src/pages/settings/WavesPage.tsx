import { clsx } from 'clsx';
import { CalendarClock, Moon, Plus, Sun } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useState, type FormEvent } from 'react';
import { useI18n, type MessageKey } from '../../lib/i18n';
import { errorMessages, useCreateWave, useUpdateWave, useWaves, type Wave } from '../../lib/queries';
import { Badge, Button, Card, Drawer, EmptyState, Input, PageHeader, SkeletonRows, Stagger, useToast, WeekdayPicker } from '../../ui';
import { itemVariants, listVariants } from '../../ui/motion';
import { Errors } from '../UniversitiesPage';

const SUN_TO_THU = 0b0011111;

function DayDots({ mask, labels }: { mask: number; labels: string[] }) {
  return (
    <span className="flex flex-wrap gap-1">
      {labels.map((l, bit) => (
        <span key={bit} className={clsx('rounded-sm px-2 py-0.5 text-caption', mask & (1 << bit) ? 'bg-primary-soft text-primary' : 'text-text-muted opacity-60')}>
          {l}
        </span>
      ))}
    </span>
  );
}

export function WavesPage() {
  const { t } = useI18n();
  const toast = useToast();
  const q = useWaves();
  const create = useCreateWave();
  const update = useUpdateWave();
  const [open, setOpen] = useState<null | 'morning' | 'return'>(null);
  const [time, setTime] = useState('08:00');
  const [days, setDays] = useState(SUN_TO_THU);
  const dayLabels = [0, 1, 2, 3, 4, 5, 6].map((d) => t(`day.${d}` as MessageKey));

  function start(type: 'morning' | 'return') {
    setTime(type === 'morning' ? '08:00' : '14:00');
    setDays(SUN_TO_THU);
    create.reset();
    setOpen(type);
  }

  async function submit(e: FormEvent) {
    e.preventDefault();
    try {
      await create.mutateAsync({ type: open, time, weekdays: days });
      toast('success', t('waves.saved'));
      setOpen(null);
    } catch {
      /* errors shown in the form */
    }
  }

  const section = (type: 'morning' | 'return', title: MessageKey, hint: MessageKey, Icon: typeof Sun) => {
    const list = (q.data ?? []).filter((w) => w.type === type);
    return (
      <Card
        animated
        title={
          <span className="flex items-center gap-3">
            <span className="grid size-10 place-items-center rounded-pill bg-primary-soft text-primary" aria-hidden>
              <Icon className="size-5" />
            </span>
            {t(title)}
          </span>
        }
        description={t(hint)}
        actions={
          <Button variant="secondary" size="sm" icon={Plus} onClick={() => start(type)}>
            {t('waves.add')}
          </Button>
        }
      >
        {q.isPending ? (
          <SkeletonRows rows={2} />
        ) : list.length === 0 ? (
          <EmptyState icon={CalendarClock} title={t('waves.emptyTitle')} />
        ) : (
          <motion.ul variants={listVariants} initial="hidden" animate="show" className="flex flex-col gap-2">
            {list.map((w: Wave) => (
              <motion.li key={w.id} variants={itemVariants} className={clsx('flex flex-wrap items-center gap-4 rounded-md border border-border p-3', !w.active && 'opacity-60')}>
                <span className="w-20 text-title tabular" dir="ltr">
                  {w.time}
                </span>
                <span className="min-w-0 flex-1">
                  <DayDots mask={w.weekdays} labels={dayLabels} />
                </span>
                {w.active ? null : <Badge>{t('waves.off')}</Badge>}
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() =>
                    update
                      .mutateAsync({ id: w.id, active: !w.active })
                      .then(() => toast('success', t('waves.saved')))
                      .catch(() => toast('danger', t('common.saveFailed')))
                  }
                >
                  {w.active ? t('waves.disable') : t('waves.enable')}
                </Button>
              </motion.li>
            ))}
          </motion.ul>
        )}
      </Card>
    );
  };

  return (
    <Stagger>
      <PageHeader title={t('waves.title')} description={t('waves.desc')} />
      <div className="grid gap-6 lg:grid-cols-2">
        {section('morning', 'waves.morning', 'waves.morningHint', Sun)}
        {section('return', 'waves.return', 'waves.returnHint', Moon)}
      </div>
      <Drawer
        open={open !== null}
        title={`${t('waves.add')} · ${open === 'return' ? t('waves.return') : t('waves.morning')}`}
        onClose={() => setOpen(null)}
        footer={
          <>
            <Button type="submit" form="wave-form" loading={create.isPending}>
              {t('common.save')}
            </Button>
            <Button variant="secondary" onClick={() => setOpen(null)}>
              {t('common.cancel')}
            </Button>
          </>
        }
      >
        <form id="wave-form" onSubmit={submit} className="flex flex-col gap-6">
          <AnimatePresence>{create.error ? <Errors messages={errorMessages(create.error)} /> : null}</AnimatePresence>
          <Input id="wave-time" label={t('waves.time')} type="time" dir="ltr" value={time} onChange={(e) => setTime(e.target.value)} required />
          <WeekdayPicker legend={t('waves.days')} value={days} onChange={setDays} labels={dayLabels} />
        </form>
      </Drawer>
    </Stagger>
  );
}
