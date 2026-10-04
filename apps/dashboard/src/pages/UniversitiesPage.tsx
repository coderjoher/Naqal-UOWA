import { useQuery } from '@tanstack/react-query';
import { api } from '../lib/api';
import { useI18n } from '../lib/i18n';
import { Card, Table } from '../ui';

interface University {
  id: string;
  name: string;
  nameAr: string | null;
  slug: string;
  commissionPct: string;
  waitlistMinutes: number;
}

export function UniversitiesPage() {
  const { t, lang } = useI18n();
  const q = useQuery({ queryKey: ['universities'], queryFn: () => api<University[]>('/universities') });
  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-title">{t('universities.title')}</h1>
      <Card>
        {q.isPending ? (
          <p className="text-text-muted">{t('common.loading')}</p>
        ) : q.isError ? (
          <p className="text-danger" role="alert">
            {t('common.error')}
          </p>
        ) : (
          <Table
            caption={t('universities.title')}
            rows={q.data}
            rowKey={(u) => u.id}
            empty={t('common.empty')}
            columns={[
              { key: 'name', header: t('universities.name'), cell: (u) => (lang === 'ar' && u.nameAr) || u.name },
              { key: 'slug', header: t('universities.slug'), cell: (u) => <span dir="ltr">{u.slug}</span> },
              { key: 'commission', header: t('universities.commission'), cell: (u) => <span className="tabular">{Number(u.commissionPct)}%</span> },
              { key: 'waitlist', header: t('universities.waitlist'), cell: (u) => <span className="tabular">{u.waitlistMinutes} {t('common.minutes')}</span> },
            ]}
          />
        )}
      </Card>
    </div>
  );
}
