import { Building2, Pencil, Plus } from 'lucide-react';
import { useState, type FormEvent } from 'react';
import { useI18n } from '../lib/i18n';
import { errorMessages, useCreateUniversity, useUniversities, useUpdateUniversity, type University } from '../lib/queries';
import { Button, Card, Drawer, EmptyState, IconButton, Input, PageHeader, SkeletonRows, Stagger, Table, useToast } from '../ui';

function Errors({ messages }: { messages: string[] }) {
  if (!messages.length) return null;
  return (
    <ul role="alert" className="flex flex-col gap-1 rounded-md bg-danger-soft p-4 text-caption text-danger">
      {messages.map((m) => (
        <li key={m}>{m}</li>
      ))}
    </ul>
  );
}

function CreateForm({ onDone }: { onDone: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const create = useCreateUniversity();
  const [f, setF] = useState({ name: '', nameAr: '', slug: '', campusLat: '', campusLng: '', commissionPct: '10', waitlistMinutes: '30', officeName: '', officeEmail: '', officePassword: '' });
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((s) => ({ ...s, [k]: e.target.value }));

  async function submit(e: FormEvent) {
    e.preventDefault();
    await create.mutateAsync({
      name: f.name,
      nameAr: f.nameAr || undefined,
      slug: f.slug,
      campusLat: Number(f.campusLat),
      campusLng: Number(f.campusLng),
      commissionPct: Number(f.commissionPct),
      waitlistMinutes: Number(f.waitlistMinutes),
      officeAccount: f.officeEmail ? { name: f.officeName, email: f.officeEmail, password: f.officePassword } : undefined,
    });
    toast('success', t('universities.created'));
    onDone();
  }

  return (
    <form id="create-university" onSubmit={(e) => submit(e).catch(() => toast('danger', t('common.saveFailed')))} className="flex flex-col gap-5">
      <Errors messages={errorMessages(create.error)} />
      <Input id="u-name" label={t('universities.name')} value={f.name} onChange={set('name')} required />
      <Input id="u-name-ar" label={t('universities.nameAr')} value={f.nameAr} onChange={set('nameAr')} />
      <Input id="u-slug" label={t('universities.slug')} hint={t('universities.slugHint')} dir="ltr" value={f.slug} onChange={set('slug')} required />
      <div className="grid grid-cols-2 gap-4">
        <Input id="u-lat" label={t('universities.lat')} dir="ltr" inputMode="decimal" value={f.campusLat} onChange={set('campusLat')} required />
        <Input id="u-lng" label={t('universities.lng')} dir="ltr" inputMode="decimal" value={f.campusLng} onChange={set('campusLng')} required />
      </div>
      <div className="grid grid-cols-2 gap-4">
        <Input id="u-commission" label={t('universities.commission')} suffix="%" dir="ltr" inputMode="decimal" value={f.commissionPct} onChange={set('commissionPct')} />
        <Input id="u-waitlist" label={t('universities.waitlist')} suffix={t('common.minutes')} dir="ltr" inputMode="numeric" value={f.waitlistMinutes} onChange={set('waitlistMinutes')} />
      </div>
      <fieldset className="flex flex-col gap-4 rounded-md border border-border p-4">
        <legend className="px-2 text-label">{t('universities.office')}</legend>
        <Input id="u-office-name" label={t('universities.officeName')} value={f.officeName} onChange={set('officeName')} />
        <Input id="u-office-email" label={t('universities.officeEmail')} type="email" dir="ltr" value={f.officeEmail} onChange={set('officeEmail')} />
        <Input id="u-office-password" label={t('universities.officePassword')} type="password" dir="ltr" value={f.officePassword} onChange={set('officePassword')} />
      </fieldset>
    </form>
  );
}

function EditForm({ uni, onDone }: { uni: University; onDone: () => void }) {
  const { t } = useI18n();
  const toast = useToast();
  const update = useUpdateUniversity();
  const [commission, setCommission] = useState(String(Number(uni.commissionPct)));
  const [waitlist, setWaitlist] = useState(String(uni.waitlistMinutes));
  async function submit(e: FormEvent) {
    e.preventDefault();
    await update.mutateAsync({ id: uni.id, commissionPct: Number(commission), waitlistMinutes: Number(waitlist) });
    toast('success', t('universities.saved'));
    onDone();
  }
  return (
    <form id="edit-university" onSubmit={(e) => submit(e).catch(() => toast('danger', t('common.saveFailed')))} className="flex flex-col gap-5">
      <Errors messages={errorMessages(update.error)} />
      <Input id="e-commission" label={t('universities.commission')} suffix="%" dir="ltr" inputMode="decimal" value={commission} onChange={(e) => setCommission(e.target.value)} />
      <Input id="e-waitlist" label={t('universities.waitlist')} suffix={t('common.minutes')} dir="ltr" inputMode="numeric" value={waitlist} onChange={(e) => setWaitlist(e.target.value)} />
    </form>
  );
}

export function UniversitiesPage() {
  const { t, lang } = useI18n();
  const q = useUniversities();
  const [creating, setCreating] = useState(false);
  const [editing, setEditing] = useState<University | null>(null);
  return (
    <Stagger>
      <PageHeader
        title={t('universities.title')}
        description={t('universities.desc')}
        actions={
          <Button icon={Plus} onClick={() => setCreating(true)}>
            {t('universities.add')}
          </Button>
        }
      />
      <Card animated>
        {q.isPending ? (
          <SkeletonRows />
        ) : q.isError ? (
          <p className="text-danger" role="alert">
            {t('common.error')}
          </p>
        ) : (
          <Table
            caption={t('universities.title')}
            rows={q.data}
            rowKey={(u) => u.id}
            empty={<EmptyState icon={Building2} title={t('universities.empty')} />}
            columns={[
              { key: 'name', header: t('universities.name'), cell: (u) => <span className="font-medium">{(lang === 'ar' && u.nameAr) || u.name}</span> },
              { key: 'slug', header: t('universities.slug'), cell: (u) => <span dir="ltr" className="text-text-muted">{u.slug}</span> },
              { key: 'commission', header: t('universities.commission'), cell: (u) => <span className="tabular">{Number(u.commissionPct)}%</span> },
              { key: 'waitlist', header: t('universities.waitlist'), cell: (u) => <span className="tabular">{u.waitlistMinutes} {t('common.minutes')}</span> },
              { key: 'actions', header: t('common.actions'), cell: (u) => <IconButton icon={Pencil} label={t('universities.edit')} onClick={() => setEditing(u)} /> },
            ]}
          />
        )}
      </Card>

      <Drawer
        open={creating}
        title={t('universities.add')}
        onClose={() => setCreating(false)}
        footer={
          <>
            <Button type="submit" form="create-university">
              {t('common.save')}
            </Button>
            <Button variant="secondary" onClick={() => setCreating(false)}>
              {t('common.cancel')}
            </Button>
          </>
        }
      >
        <CreateForm onDone={() => setCreating(false)} />
      </Drawer>
      <Drawer
        open={!!editing}
        title={editing ? `${t('universities.edit')} · ${(lang === 'ar' && editing.nameAr) || editing.name}` : ''}
        onClose={() => setEditing(null)}
        footer={
          <>
            <Button type="submit" form="edit-university">
              {t('common.save')}
            </Button>
            <Button variant="secondary" onClick={() => setEditing(null)}>
              {t('common.cancel')}
            </Button>
          </>
        }
      >
        {editing ? <EditForm uni={editing} onDone={() => setEditing(null)} /> : null}
      </Drawer>
    </Stagger>
  );
}

export { Errors };
