import { useAuth } from '../lib/auth';
import { useI18n } from '../lib/i18n';
import { Card } from '../ui';

export function OverviewPage() {
  const { session } = useAuth();
  const { t } = useI18n();
  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-title">
        {t('overview.welcome')}، {session?.user.name}
      </h1>
      <Card>
        <p className="text-text-muted">{t('overview.soon')}</p>
      </Card>
    </div>
  );
}
