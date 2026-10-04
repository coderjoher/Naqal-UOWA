import { useQuery } from '@tanstack/react-query';
import { api, type Role } from '../lib/api';
import { useI18n } from '../lib/i18n';
import { Badge, Card, Table } from '../ui';

interface User {
  id: string;
  name: string;
  email: string | null;
  role: Role;
  status: 'active' | 'suspended';
}

export function UsersPage() {
  const { t } = useI18n();
  const q = useQuery({ queryKey: ['users'], queryFn: () => api<User[]>('/users') });
  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-title">{t('users.title')}</h1>
      <Card>
        {q.isPending ? (
          <p className="text-text-muted">{t('common.loading')}</p>
        ) : q.isError ? (
          <p className="text-danger" role="alert">
            {t('common.error')}
          </p>
        ) : (
          <Table
            caption={t('users.title')}
            rows={q.data}
            rowKey={(u) => u.id}
            empty={t('common.empty')}
            columns={[
              { key: 'name', header: t('users.name'), cell: (u) => u.name },
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
    </div>
  );
}
