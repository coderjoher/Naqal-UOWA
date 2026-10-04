import { Users } from 'lucide-react';
import { useI18n } from '../lib/i18n';
import { useUsers } from '../lib/queries';
import { Badge, Card, EmptyState, PageHeader, SkeletonRows, Stagger, Table } from '../ui';

export function UsersPage() {
  const { t } = useI18n();
  const q = useUsers();
  return (
    <Stagger>
      <PageHeader title={t('users.title')} description={t('users.desc')} />
      <Card animated>
        {q.isPending ? (
          <SkeletonRows />
        ) : q.isError ? (
          <p className="text-danger" role="alert">
            {t('common.error')}
          </p>
        ) : (
          <Table
            caption={t('users.title')}
            rows={q.data}
            rowKey={(u) => u.id}
            empty={<EmptyState icon={Users} title={t('common.empty')} />}
            columns={[
              {
                key: 'name',
                header: t('users.name'),
                cell: (u) => (
                  <span className="flex items-center gap-3">
                    <span className="grid size-9 place-items-center rounded-pill bg-primary-soft text-label text-primary" aria-hidden>
                      {u.name.slice(0, 1)}
                    </span>
                    {u.name}
                  </span>
                ),
              },
              { key: 'email', header: t('users.email'), cell: (u) => <span dir="ltr">{u.email ?? '—'}</span> },
              { key: 'role', header: t('users.role'), cell: (u) => t(`role.${u.role}`) },
              {
                key: 'status',
                header: t('users.status'),
                cell: (u) => <Badge tone={u.status === 'active' ? 'success' : 'danger'}>{t(`status.${u.status}`)}</Badge>,
              },
            ]}
          />
        )}
      </Card>
    </Stagger>
  );
}
