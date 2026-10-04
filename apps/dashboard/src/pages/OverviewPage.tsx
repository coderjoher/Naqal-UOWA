import { clsx } from 'clsx';
import { ArrowLeft, Building2, CalendarClock, Check, FileCheck2, Layers, MapPin, Percent, Users, type LucideIcon } from 'lucide-react';
import { motion } from 'motion/react';
import { Link } from 'react-router';
import { useAuth } from '../lib/auth';
import { useI18n, type MessageKey } from '../lib/i18n';
import { usePoints, useRequirements, useTiers, useUniversities, useUsers, useWaves } from '../lib/queries';
import { AnimatedNumber, Card, PageHeader, Skeleton, Stagger } from '../ui';
import { itemVariants, spring } from '../ui/motion';

function Kpi({ icon: Icon, label, value, loading, format }: { icon: LucideIcon; label: string; value: number; loading?: boolean; format?: (n: number) => string }) {
  return (
    <motion.div variants={itemVariants} whileHover={{ y: -3 }} transition={spring} className="flex items-center gap-4 rounded-lg bg-surface p-5 shadow-card">
      <span className="grid size-12 shrink-0 place-items-center rounded-md bg-primary-soft text-primary" aria-hidden>
        <Icon className="size-6" />
      </span>
      <div className="min-w-0">
        <p className="text-title">{loading ? <Skeleton className="h-7 w-12" /> : <AnimatedNumber value={value} format={format} />}</p>
        <p className="truncate text-caption text-text-muted">{label}</p>
      </div>
    </motion.div>
  );
}

function OfficeOverview() {
  const { t } = useI18n();
  const { session } = useAuth();
  const tiers = useTiers();
  const points = usePoints();
  const waves = useWaves();
  const users = useUsers();
  const reqs = useRequirements();

  const activePoints = points.data?.filter((p) => p.active).length ?? 0;
  const activeWaves = waves.data?.filter((w) => w.active).length ?? 0;
  const steps: { key: MessageKey; to: string; icon: LucideIcon; done: boolean }[] = [
    { key: 'step.tiers', to: '/settings/tiers', icon: Layers, done: (tiers.data?.length ?? 0) > 0 },
    { key: 'step.points', to: '/settings/points', icon: MapPin, done: activePoints > 0 },
    { key: 'step.waves', to: '/settings/waves', icon: CalendarClock, done: waves.data?.some((w) => w.type === 'morning' && w.active) === true && waves.data?.some((w) => w.type === 'return' && w.active) === true },
    { key: 'step.requirements', to: '/settings/requirements', icon: FileCheck2, done: (reqs.data?.documents?.length ?? 0) > 0 },
  ];
  const doneCount = steps.filter((s) => s.done).length;

  return (
    <Stagger>
      <PageHeader title={`${t('overview.welcome')}، ${session?.user.name ?? ''}`} description={t('overview.subtitle')} />
      <motion.div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4" variants={{ show: { transition: { staggerChildren: 0.05 } } }}>
        <Kpi icon={MapPin} label={t('overview.kpi.points')} value={activePoints} loading={points.isPending} />
        <Kpi icon={Layers} label={t('overview.kpi.tiers')} value={tiers.data?.length ?? 0} loading={tiers.isPending} />
        <Kpi icon={CalendarClock} label={t('overview.kpi.waves')} value={activeWaves} loading={waves.isPending} />
        <Kpi icon={Users} label={t('overview.kpi.users')} value={users.data?.length ?? 0} loading={users.isPending} />
      </motion.div>
      <Card animated title={t('overview.setup')} description={t('overview.setupDesc')} actions={<span className="text-label text-text-muted tabular">{doneCount}/{steps.length}</span>}>
        <div className="mb-5 h-2 overflow-hidden rounded-pill bg-surface-muted" role="progressbar" aria-valuemin={0} aria-valuemax={steps.length} aria-valuenow={doneCount}>
          <motion.div className="h-full rounded-pill bg-primary" initial={{ width: 0 }} animate={{ width: `${(doneCount / steps.length) * 100}%` }} transition={{ duration: 0.7, ease: 'easeOut' }} />
        </div>
        <ol className="flex flex-col gap-2">
          {steps.map((s) => (
            <li key={s.key}>
              <Link to={s.to} className="group flex items-center gap-4 rounded-md p-3 transition-colors duration-200 hover:bg-surface-muted">
                <span className={clsx('grid size-10 shrink-0 place-items-center rounded-pill', s.done ? 'bg-success-soft text-success' : 'bg-primary-soft text-primary')} aria-hidden>
                  {s.done ? <Check className="size-5" /> : <s.icon className="size-5" />}
                </span>
                <span className="flex-1 text-label">{t(s.key)}</span>
                <span className={clsx('text-caption font-medium', s.done ? 'text-success' : 'text-text-muted')}>{s.done ? t('overview.done') : t('overview.todo')}</span>
                <ArrowLeft className="size-4 text-text-muted transition-transform duration-200 group-hover:-translate-x-1 ltr:rotate-180 ltr:group-hover:translate-x-1" aria-hidden />
              </Link>
            </li>
          ))}
        </ol>
      </Card>
    </Stagger>
  );
}

function AdminOverview() {
  const { t } = useI18n();
  const { session } = useAuth();
  const unis = useUniversities();
  const list = unis.data ?? [];
  const avg = list.length ? list.reduce((s, u) => s + Number(u.commissionPct), 0) / list.length : 0;
  return (
    <Stagger>
      <PageHeader title={`${t('overview.welcome')}، ${session?.user.name ?? ''}`} description={t('overview.admin.subtitle')} />
      <motion.div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3" variants={{ show: { transition: { staggerChildren: 0.05 } } }}>
        <Kpi icon={Building2} label={t('overview.kpi.universities')} value={list.length} loading={unis.isPending} />
        <Kpi icon={Percent} label={t('overview.kpi.avgCommission')} value={Math.round(avg * 10)} loading={unis.isPending} format={(n) => `${(n / 10).toFixed(1)}%`} />
      </motion.div>
    </Stagger>
  );
}

export function OverviewPage() {
  const { session } = useAuth();
  return session?.user.role === 'super_admin' ? <AdminOverview /> : <OfficeOverview />;
}
