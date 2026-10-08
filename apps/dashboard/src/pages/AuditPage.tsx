import { History } from 'lucide-react';
import { useState } from 'react';
import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { useAudit, useAuditEntities, type AuditRow } from '../lib/money';
import { Badge, Card, EmptyState, Input, PageHeader, SkeletonRows, Stagger, Table } from '../ui';

/** Readable "field: before → after" lines for rows that carry a before/after payload. */
function Changes({ row }: { row: AuditRow }) {
  const p = row.payload as { before?: Record<string, unknown> | null; after?: Record<string, unknown> | null } | null;
  if (!p || !('after' in p) || !p.after) return <span className="text-text-muted">—</span>;
  const show = (v: unknown) => (v === null || v === undefined ? '—' : typeof v === 'object' ? JSON.stringify(v) : String(v));
  return (
    <ul className="flex flex-col gap-1" dir="ltr">
      {Object.keys(p.after).map((k) => (
        <li key={k} className="text-caption">
          <span className="font-medium">{k}</span>: <span className="text-text-muted line-through">{show(p.before?.[k])}</span> → <span>{show(p.after![k])}</span>
        </li>
      ))}
    </ul>
  );
}

/** SA-05: who changed what and when, filterable by entity and date. */
export function AuditPage() {
  const { t, lang } = useI18n();
  const { session } = useAuth();
  const [entity, setEntity] = useState('');
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const q = useAudit({ entity, from, to });
  const entities = useAuditEntities();

  return (
    <Stagger>
      <PageHeader title={t('audit.title')} description={t(session?.user.role === 'super_admin' ? 'audit.descAdmin' : 'audit.desc')} />
      <Card animated>
        <div className="mb-5 flex flex-wrap items-end gap-3">
          <label className="flex min-w-48 flex-col gap-1.5 text-label">
            {t('audit.entity')}
            <select className="h-12 rounded-pill border border-border bg-surface px-5" value={entity} onChange={(e) => setEntity(e.target.value)} data-testid="audit-entity">
              <option value="">{t('audit.all')}</option>
              {(entities.data ?? []).map((e) => (
                <option key={e} value={e}>
                  {e}
                </option>
              ))}
            </select>
          </label>
          <Input id="audit-from" label={t('audit.from')} type="date" dir="ltr" value={from} onChange={(e) => setFrom(e.target.value)} />
          <Input id="audit-to" label={t('audit.to')} type="date" dir="ltr" value={to} onChange={(e) => setTo(e.target.value)} />
        </div>
        {q.isPending ? (
          <SkeletonRows />
        ) : (
          <Table
            caption={t('audit.title')}
            rows={q.data?.items ?? []}
            rowKey={(r) => r.id}
            empty={<EmptyState icon={History} title={t('audit.empty')} />}
            columns={[
              { key: 'at', header: t('audit.when'), cell: (r) => <span className="tabular whitespace-nowrap">{new Date(r.createdAt).toLocaleString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB')}</span> },
              { key: 'who', header: t('audit.who'), cell: (r) => <span>{(lang === 'ar' && r.actor?.nameAr) || r.actor?.name || '—'}</span> },
              {
                key: 'what',
                header: t('audit.what'),
                cell: (r) => (
                  <span className="flex flex-col gap-1">
                    <Badge tone="primary">{r.entity}</Badge>
                    <span className="text-caption text-text-muted" dir="ltr">
                      {r.action}
                    </span>
                  </span>
                ),
              },
              { key: 'changes', header: t('audit.changes'), cell: (r) => <Changes row={r} /> },
            ]}
          />
        )}
      </Card>
    </Stagger>
  );
}
