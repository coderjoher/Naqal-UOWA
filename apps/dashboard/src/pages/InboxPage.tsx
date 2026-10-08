import { clsx } from 'clsx';
import { Inbox, MessageSquareReply, Star } from 'lucide-react';
import { motion } from 'motion/react';
import { useState } from 'react';
import { ApiError } from '../lib/api';
import { useI18n, type MessageKey } from '../lib/i18n';
import { useProblems, useRatings, useResolveProblem, type Problem } from '../lib/ops';
import { Badge, Button, Card, Drawer, EmptyState, PageHeader, SkeletonRows, Stagger, Textarea, useToast } from '../ui';
import { itemVariants } from '../ui/motion';

function Stars({ n }: { n: number }) {
  return (
    <span className="inline-flex" aria-label={`${n}/5`}>
      {[1, 2, 3, 4, 5].map((i) => (
        <Star key={i} size={14} className={i <= Math.round(n) ? 'fill-current text-warning' : 'text-border'} aria-hidden />
      ))}
    </span>
  );
}

/** ST-11: problem reports from students (answer and close) and ride ratings per driver. */
export function InboxPage() {
  const { t, lang } = useI18n();
  const toast = useToast();
  const [status, setStatus] = useState<'' | 'open' | 'resolved'>('open');
  const problems = useProblems(status);
  const ratings = useRatings();
  const resolve = useResolveProblem();
  const [answering, setAnswering] = useState<Problem | null>(null);
  const [reply, setReply] = useState('');
  const date = (iso: string) => new Date(iso).toLocaleString(lang === 'ar' ? 'ar-IQ-u-nu-latn' : 'en-GB', { dateStyle: 'medium', timeStyle: 'short' });

  async function send() {
    if (!answering) return;
    try {
      await resolve.mutateAsync({ id: answering.id, reply: reply.trim() });
      toast('success', t('inbox.answered'));
      setAnswering(null);
      setReply('');
    } catch (err) {
      toast('danger', err instanceof ApiError && err.messages[0] ? err.messages[0] : t('common.saveFailed'));
    }
  }

  return (
    <Stagger>
      <PageHeader title={t('inbox.title')} description={t('inbox.desc')} />
      <div className="grid gap-4 xl:grid-cols-[2fr_1fr]">
        <Card
          animated
          title={t('inbox.problems')}
          actions={
            <div role="tablist" className="flex rounded-pill bg-surface-muted p-1">
              {(['open', 'resolved', ''] as const).map((s) => (
                <button key={s || 'all'} role="tab" aria-selected={status === s} onClick={() => setStatus(s)} className={clsx('h-10 rounded-pill px-4 text-label transition-colors', status === s ? 'bg-surface text-text shadow-card' : 'text-text-muted hover:text-text')}>
                  {t(s === 'open' ? 'inbox.open' : s === 'resolved' ? 'inbox.resolved' : 'audit.all')}
                </button>
              ))}
            </div>
          }
        >
          {problems.isPending ? (
            <SkeletonRows />
          ) : !problems.data?.length ? (
            <EmptyState icon={Inbox} title={t('inbox.empty')} />
          ) : (
            <ul className="flex flex-col gap-3">
              {problems.data.map((p) => (
                <motion.li key={p.id} variants={itemVariants} initial="hidden" animate="show" className="rounded-md border border-border p-4" data-testid="problem">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge tone={p.category === 'safety' ? 'danger' : 'primary'}>{t(`inbox.cat.${p.category}` as MessageKey)}</Badge>
                    <span className="text-label">{(lang === 'ar' && p.student.nameAr) || p.student.name}</span>
                    <span className="text-caption text-text-muted" dir="ltr">
                      {p.student.studentId}
                    </span>
                    <span className="ms-auto text-caption text-text-muted">{date(p.createdAt)}</span>
                  </div>
                  {p.ride ? (
                    <p className="mt-1 text-caption text-text-muted">
                      <span dir="ltr">{p.ride.date}</span> · {t(p.ride.waveType === 'morning' ? 'dispatch.morning' : 'dispatch.return')} <span dir="ltr">{p.ride.waveTime}</span>
                      {p.ride.driverName ? ` · ${p.ride.driverName}` : ''}
                    </p>
                  ) : null}
                  <p className="mt-2">{p.text}</p>
                  {p.reply ? (
                    <p className="mt-3 rounded-md bg-success-soft p-3 text-caption text-success">
                      <MessageSquareReply size={14} className="me-1 inline" aria-hidden />
                      {p.reply}
                    </p>
                  ) : (
                    <div className="mt-3">
                      <Button variant="secondary" icon={MessageSquareReply} onClick={() => setAnswering(p)}>
                        {t('inbox.answer')}
                      </Button>
                    </div>
                  )}
                </motion.li>
              ))}
            </ul>
          )}
        </Card>
        <Card animated title={t('inbox.ratings')} description={t('inbox.ratingsHint')}>
          {ratings.isPending ? (
            <SkeletonRows />
          ) : !ratings.data?.drivers.length ? (
            <EmptyState icon={Star} title={t('inbox.noRatings')} />
          ) : (
            <div className="flex flex-col gap-5">
              <ul className="flex flex-col gap-2">
                {ratings.data.drivers.map((d) => (
                  <li key={d.driverId} className="flex items-center gap-3" data-testid="driver-rating">
                    <span className="min-w-0 flex-1 truncate text-label">{d.name}</span>
                    <Stars n={d.average} />
                    <span className="w-16 text-end text-caption tabular text-text-muted">
                      {d.average.toFixed(1)} ({d.count})
                    </span>
                  </li>
                ))}
              </ul>
              <ul className="flex flex-col gap-3 border-t border-border pt-4">
                {ratings.data.recent.slice(0, 10).map((r) => (
                  <li key={r.id} className="text-caption">
                    <div className="flex items-center gap-2">
                      <Stars n={r.stars} />
                      <span className="text-text-muted">{r.driver}</span>
                    </div>
                    {r.comment ? <p className="mt-1">{r.comment}</p> : null}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </Card>
      </div>
      <Drawer
        open={!!answering}
        title={t('inbox.answerTitle')}
        onClose={() => setAnswering(null)}
        footer={
          <>
            <Button icon={MessageSquareReply} disabled={reply.trim().length < 2} loading={resolve.isPending} onClick={send}>
              {t('inbox.send')}
            </Button>
            <Button variant="secondary" onClick={() => setAnswering(null)}>
              {t('common.cancel')}
            </Button>
          </>
        }
      >
        {answering ? (
          <div className="flex flex-col gap-4">
            <p className="rounded-md bg-surface-muted p-3">{answering.text}</p>
            <Textarea id="problem-reply" label={t('inbox.reply')} value={reply} onChange={(e) => setReply(e.target.value)} />
            <p className="text-caption text-text-muted">{t('inbox.replyHint')}</p>
          </div>
        ) : null}
      </Drawer>
    </Stagger>
  );
}
