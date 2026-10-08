import { clsx } from 'clsx';
import { GraduationCap, KeyRound, Search, Upload } from 'lucide-react';
import { AnimatePresence, motion } from 'motion/react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useSearchParams } from 'react-router';
import { parseRoster, type RosterRow } from '../lib/csv';
import { useI18n } from '../lib/i18n';
import { errorMessages, useImportRoster, useIssueCode, useStudents, type RosterStudent } from '../lib/queries';
import { Badge, Button, Card, Drawer, EmptyState, IconButton, PageHeader, SkeletonRows, Stagger, Table, useToast } from '../ui';
import { spring } from '../ui/motion';
import { Errors } from './UniversitiesPage';

export function StudentsPage() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const q = useStudents();
  const importRoster = useImportRoster();
  const issue = useIssueCode();
  const file = useRef<HTMLInputElement>(null);
  const [pending, setPending] = useState<{ rows: RosterRow[]; badLines: number[] } | null>(null);
  const [code, setCode] = useState<{ student: RosterStudent; code: string; expiresAt: string } | null>(null);
  const [params] = useSearchParams();
  const [query, setQuery] = useState(() => params.get('q') ?? '');
  // The global search links here with ?q=<student number>.
  useEffect(() => {
    const q = params.get('q');
    if (q !== null) setQuery(q);
  }, [params]);

  const rows = useMemo(() => {
    const qn = query.trim().toLowerCase();
    return (q.data ?? []).filter((s) => !qn || s.studentId.toLowerCase().includes(qn) || s.name.toLowerCase().includes(qn) || (s.nameAr ?? '').includes(qn));
  }, [q.data, query]);

  async function onFile(f: File | undefined) {
    if (!f) return;
    const parsed = parseRoster(await f.text());
    if (parsed.rows.length === 0) {
      toast('danger', t('students.badFile'));
      return;
    }
    setPending(parsed);
  }

  async function confirmImport() {
    if (!pending) return;
    try {
      await importRoster.mutateAsync(pending.rows);
      toast('success', t('students.importDone'));
      setPending(null);
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  async function issueCode(s: RosterStudent) {
    try {
      const res = await issue.mutateAsync(s.studentId);
      setCode({ student: s, code: res.code, expiresAt: res.expiresAt });
    } catch {
      toast('danger', t('common.saveFailed'));
    }
  }

  const state = (s: RosterStudent) =>
    s.activated ? <Badge tone="success">{t('students.activated')}</Badge> : s.activationPending ? <Badge tone="warning">{t('students.codeIssued')}</Badge> : <Badge>{t('students.notActivated')}</Badge>;

  return (
    <Stagger>
      <PageHeader
        title={t('students.title')}
        description={t('students.desc')}
        actions={
          <>
            <input ref={file} type="file" accept=".csv,text/csv" className="sr-only" id="roster-file" onChange={(e) => onFile(e.target.files?.[0]).finally(() => (e.target.value = ''))} />
            <Button icon={Upload} onClick={() => file.current?.click()}>
              {t('students.import')}
            </Button>
          </>
        }
      />
      <AnimatePresence>
        {pending ? (
          <motion.div initial={{ opacity: 0, y: -8 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -8 }} transition={spring}>
            <Card nested>
              <div className="flex flex-wrap items-center gap-4">
                <span className="grid size-11 place-items-center rounded-pill bg-primary-soft text-primary" aria-hidden>
                  <Upload className="size-5" />
                </span>
                <p className="flex-1 text-label">
                  <span className="text-title tabular">{pending.rows.length}</span> {t('students.rows')}
                  {pending.badLines.length ? <span className="block text-caption text-warning">{t('students.badFile')} ({pending.badLines.slice(0, 5).join('، ')})</span> : null}
                </p>
                <Button onClick={confirmImport} loading={importRoster.isPending}>
                  {t('students.confirmImport')}
                </Button>
                <Button variant="secondary" onClick={() => setPending(null)}>
                  {t('common.cancel')}
                </Button>
              </div>
              <Errors messages={errorMessages(importRoster.error)} />
            </Card>
          </motion.div>
        ) : null}
      </AnimatePresence>
      <Card animated>
        <div className="relative mb-4 max-w-sm">
          <Search className="pointer-events-none absolute inset-y-0 start-4 my-auto size-4 text-text-muted" aria-hidden />
          <input
            aria-label={t('students.search')}
            placeholder={t('students.search')}
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="h-12 w-full rounded-pill border border-border bg-surface ps-11 pe-5 text-body transition-[border-color,box-shadow] duration-200 hover:border-text-muted focus:border-primary focus:shadow-[0_0_0_4px_var(--color-primary-soft)] focus:outline-none"
          />
        </div>
        {q.isPending ? (
          <SkeletonRows />
        ) : (
          <Table
            caption={t('students.title')}
            rows={rows}
            rowKey={(s) => s.id}
            empty={<EmptyState icon={GraduationCap} title={t('students.emptyTitle')} message={t('students.emptyBody')} />}
            columns={[
              { key: 'id', header: t('students.id'), cell: (s) => <span dir="ltr" className="tabular text-text-muted">{s.studentId}</span> },
              { key: 'name', header: t('students.name'), cell: (s) => <span className="font-medium">{(lang === 'ar' && s.nameAr) || s.name}</span> },
              { key: 'gender', header: t('students.gender'), cell: (s) => <Badge tone={s.gender === 'female' ? 'female-only' : 'primary'}>{t(s.gender === 'female' ? 'students.female' : 'students.male')}</Badge> },
              { key: 'state', header: t('students.state'), cell: state },
              {
                key: 'actions',
                header: t('common.actions'),
                cell: (s) => (s.activated ? null : <IconButton icon={KeyRound} label={t('students.issueCode')} onClick={() => issueCode(s)} disabled={issue.isPending} />),
              },
            ]}
          />
        )}
      </Card>
      <Drawer open={!!code} title={t('students.codeTitle')} onClose={() => setCode(null)}>
        {code ? (
          <div className="flex flex-col items-center gap-6 py-6 text-center">
            <p className="text-headline">{(lang === 'ar' && code.student.nameAr) || code.student.name}</p>
            <p className="text-caption text-text-muted" dir="ltr">
              {code.student.studentId}
            </p>
            <motion.p
              initial={{ scale: 0.8, opacity: 0 }}
              animate={{ scale: 1, opacity: 1 }}
              transition={spring}
              dir="ltr"
              className={clsx('rounded-lg bg-primary-soft px-8 py-6 font-mono text-[44px] font-semibold tracking-[0.3em] text-primary tabular')}
              aria-label={code.code.split('').join(' ')}
            >
              {code.code}
            </motion.p>
            <p className="max-w-sm text-text-muted">{t('students.codeHint')}</p>
            <p className="text-caption text-text-muted">
              {t('students.codeExpires')}: {new Date(code.expiresAt).toLocaleDateString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB')}
            </p>
          </div>
        ) : null}
      </Drawer>
    </Stagger>
  );
}
