/**
 * ST-09 notification rules. Pure: each event maps to messages with a stable dedupe key, and the
 * store keeps a key only once, so every event notifies exactly once however often it is seen.
 */
export const APPROACHING_S = 5 * 60;

export interface NotificationDraft {
  userId: string;
  kind:
    | 'ride.assigned'
    | 'ride.waitlisted'
    | 'ride.approaching'
    | 'ride.arrived'
    | 'ride.cancelled'
    | 'ride.bumped'
    | 'ride.expired'
    | 'ride.moved'
    | 'run.changed'
    | 'announcement'
    | 'problem.answered'
    | 'taxi.offer'
    | 'taxi.accepted'
    | 'taxi.arrived'
    | 'taxi.cancelled'
    | 'taxi.expired';
  dedupeKey: string;
  data: Record<string, unknown>;
}

export interface RiderAtStop {
  requestId: string;
  studentId: string;
  seq: number;
}

export type RideEvent =
  | { type: 'assigned'; requestId: string; studentId: string; runId: string }
  | { type: 'waitlisted'; requestId: string; studentId: string; until?: string }
  | { type: 'bumped'; requestId: string; studentId: string }
  | { type: 'expired'; requestId: string; studentId: string }
  | { type: 'cancelled'; requestId: string; studentId: string; reason: string }
  | { type: 'eta'; runId: string; etas: { seq: number; seconds: number }[]; riders: RiderAtStop[] }
  | { type: 'arrived'; runId: string; seq: number; riders: RiderAtStop[] };

export function notificationsFor(e: RideEvent): NotificationDraft[] {
  switch (e.type) {
    case 'assigned':
      // A move to another bus is news again; the same bus is not.
      return [{ userId: e.studentId, kind: 'ride.assigned', dedupeKey: `assigned:${e.requestId}:${e.runId}`, data: { requestId: e.requestId, runId: e.runId } }];
    case 'waitlisted':
      return [{ userId: e.studentId, kind: 'ride.waitlisted', dedupeKey: `waitlisted:${e.requestId}:${e.until ?? ''}`, data: { requestId: e.requestId, until: e.until } }];
    case 'bumped':
      return [{ userId: e.studentId, kind: 'ride.bumped', dedupeKey: `bumped:${e.requestId}`, data: { requestId: e.requestId } }];
    case 'expired':
      return [{ userId: e.studentId, kind: 'ride.expired', dedupeKey: `cancelled:${e.requestId}`, data: { requestId: e.requestId } }];
    case 'cancelled':
      return [{ userId: e.studentId, kind: 'ride.cancelled', dedupeKey: `cancelled:${e.requestId}`, data: { requestId: e.requestId, reason: e.reason } }];
    case 'eta':
      return e.riders.flatMap((r) => {
        const eta = e.etas.find((x) => x.seq === r.seq);
        if (!eta || eta.seconds > APPROACHING_S) return [];
        return [{ userId: r.studentId, kind: 'ride.approaching' as const, dedupeKey: `approaching:${r.requestId}`, data: { requestId: r.requestId, runId: e.runId, minutes: Math.max(1, Math.round(eta.seconds / 60)) } }];
      });
    case 'arrived':
      return e.riders
        .filter((r) => r.seq === e.seq)
        .map((r) => ({ userId: r.studentId, kind: 'ride.arrived' as const, dedupeKey: `arrived:${r.requestId}`, data: { requestId: r.requestId, runId: e.runId } }));
  }
}

/** Push text in Arabic and English. */
export function messageFor(n: Pick<NotificationDraft, 'kind' | 'data'>, lang: 'ar' | 'en'): { title: string; body: string } {
  const ar = lang === 'ar';
  const minutes = n.data.minutes as number | undefined;
  switch (n.kind) {
    case 'ride.assigned':
      return ar ? { title: 'تم تأكيد مقعدك', body: 'افتح التطبيق لترى حافلتك ووقت الصعود.' } : { title: 'Your seat is confirmed', body: 'Open the app to see your bus and pickup time.' };
    case 'ride.waitlisted':
      return ar ? { title: 'أنت على قائمة الانتظار', body: 'سنخبرك فور توفر مقعد.' } : { title: 'You are on the waitlist', body: 'We will tell you as soon as a seat frees up.' };
    case 'ride.bumped':
      return ar ? { title: 'نُقلت إلى قائمة الانتظار', body: 'أُعطي مقعدك لمشترك. سنحجز لك فور توفر مقعد.' } : { title: 'Moved to the waitlist', body: 'Your seat went to a subscriber. We will seat you when one frees up.' };
    case 'ride.approaching':
      return ar ? { title: 'الحافلة تقترب', body: `تصل إلى نقطتك خلال ${minutes ?? 5} دقائق تقريباً.` } : { title: 'Your bus is close', body: `About ${minutes ?? 5} minutes to your stop.` };
    case 'ride.arrived':
      return ar ? { title: 'الحافلة وصلت', body: 'الحافلة في نقطة التجمّع الآن.' } : { title: 'Your bus is here', body: 'The bus is at your gathering point now.' };
    case 'ride.expired':
      return ar ? { title: 'لم نجد مقعداً', body: 'انتهت مدة الانتظار وأُلغي الطلب. يمكنك طلب موعد آخر.' } : { title: 'No seat found', body: 'The waiting time ended and the request was cancelled.' };
    case 'ride.cancelled':
      return ar ? { title: 'أُلغيت الرحلة', body: 'أُلغي طلب رحلتك.' } : { title: 'Ride cancelled', body: 'Your ride request was cancelled.' };
    case 'ride.moved':
      return ar ? { title: 'تغيّرت حافلتك', body: 'نقلك مكتب النقل إلى حافلة أخرى. افتح التطبيق لترى التفاصيل.' } : { title: 'Your bus changed', body: 'The transport office moved you to another bus. Open the app for details.' };
    case 'run.changed':
      return ar ? { title: 'تغيّرت رحلتك', body: 'عدّل مكتب النقل ركاب رحلتك. راجع المحطات.' } : { title: 'Your run changed', body: 'The transport office changed your riders. Check the stops.' };
    case 'announcement':
      return { title: String(n.data.title ?? (ar ? 'إعلان' : 'Announcement')), body: String(n.data.body ?? '') };
    case 'problem.answered':
      return ar ? { title: 'ردّ مكتب النقل على بلاغك', body: String(n.data.reply ?? '') } : { title: 'The transport office answered your report', body: String(n.data.reply ?? '') };
    case 'taxi.offer': {
      const fare = Number(n.data.fare ?? 0).toLocaleString('en-US');
      const toCampus = n.data.direction === 'to_campus';
      return ar
        ? { title: 'طلب تكسي جديد', body: `${toCampus ? 'إلى الجامعة' : 'من الجامعة'} · ${fare} د.ع · اقبله قبل غيرك.` }
        : { title: 'New taxi request', body: `${toCampus ? 'To campus' : 'From campus'} · ${fare} IQD · first to accept takes it.` };
    }
    case 'taxi.accepted':
      return ar ? { title: 'التكسي في الطريق إليك', body: `${String(n.data.driverName ?? 'السائق')} قبل طلبك. افتح التطبيق لترى السيارة.` } : { title: 'Your taxi is on its way', body: `${String(n.data.driverName ?? 'A driver')} accepted. Open the app to see the car.` };
    case 'taxi.arrived':
      return ar ? { title: 'التكسي وصل', body: 'السائق في نقطة الالتقاء الآن.' } : { title: 'Your taxi is here', body: 'The driver is at the pickup point now.' };
    case 'taxi.cancelled':
      return ar ? { title: 'أُلغي طلب التكسي', body: 'أُلغيت الرحلة.' } : { title: 'Taxi cancelled', body: 'The taxi ride was cancelled.' };
    case 'taxi.expired':
      return ar ? { title: 'لم يقبل أي سائق', body: 'لا يوجد تكسي متاح الآن. حاول بعد قليل.' } : { title: 'No driver accepted', body: 'No taxi is free right now. Try again in a few minutes.' };
  }
}
