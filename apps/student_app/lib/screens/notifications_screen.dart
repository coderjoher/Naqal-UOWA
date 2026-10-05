import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';

/// ST-09: everything the app told the student, newest first. Opening the list marks it read.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) ref.read(apiProvider).markNotificationsRead().catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final list = ref.watch(notificationsProvider);
    return Column(children: [
      NaqlTopBar(title: t.notificationsTitle),
      Expanded(
        child: list.when(
          loading: () => const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 72, radius: NaqlRadius.md)),
          error: (_, _) => Center(child: NaqlEmptyState(icon: LucideIcons.wifiOff, title: t.loadFailed)),
          data: (items) => items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(NaqlSpace.s6),
                    child: NaqlEmptyState(icon: LucideIcons.bell, title: t.noNotifications, message: t.noNotificationsBody),
                  ),
                )
              : RefreshIndicator(
                  color: NaqlColors.primary,
                  onRefresh: () async => ref.invalidate(notificationsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: NaqlSpace.s3),
                    itemBuilder: (_, i) => NaqlEntrance(index: i, child: _Item(n: items[i])),
                  ),
                ),
        ),
      ),
    ]);
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.n});
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final minutes = (n.data['minutes'] as num?)?.toInt() ?? 5;
    final (IconData icon, NaqlTone tone, String title, String body) = switch (n.kind) {
      'ride.assigned' => (LucideIcons.ticketCheck, NaqlTone.success, t.nAssignedTitle, t.nAssignedBody),
      'ride.waitlisted' => (LucideIcons.hourglass, NaqlTone.warning, t.nWaitlistedTitle, t.nWaitlistedBody),
      'ride.bumped' => (LucideIcons.hourglass, NaqlTone.warning, t.nBumpedTitle, t.nBumpedBody),
      'ride.approaching' => (LucideIcons.busFront, NaqlTone.primary, t.nApproachingTitle, t.nApproachingBody(minutes)),
      'ride.arrived' => (LucideIcons.mapPinCheck, NaqlTone.success, t.nArrivedTitle, t.nArrivedBody),
      'ride.expired' => (LucideIcons.circleX, NaqlTone.danger, t.nExpiredTitle, t.nExpiredBody),
      'ride.moved' => (LucideIcons.arrowLeftRight, NaqlTone.primary, t.nMovedTitle, t.nMovedBody),
      'announcement' => (LucideIcons.megaphone, NaqlTone.primary, '${n.data['title'] ?? ''}', '${n.data['body'] ?? ''}'),
      'problem.answered' => (LucideIcons.messageSquareReply, NaqlTone.success, t.nAnsweredTitle, '${n.data['reply'] ?? ''}'),
      _ => (LucideIcons.circleX, NaqlTone.neutral, t.nCancelledTitle, t.nCancelledBody),
    };
    final ago = clock.now().difference(n.createdAt);
    return NaqlCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle), child: Icon(icon, color: tone.fg, size: 22)),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: NaqlText.label)),
              Text(ago.inMinutes < 60 ? t.agoMinutes(ago.inMinutes) : formatClock(n.createdAt), style: NaqlText.caption, textDirection: TextDirection.ltr),
            ]),
            const SizedBox(height: 2),
            Text(body, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
          ]),
        ),
        if (n.readAt == null) ...[
          const SizedBox(width: NaqlSpace.s2),
          Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 6), decoration: const BoxDecoration(color: NaqlColors.primary, shape: BoxShape.circle)),
        ],
      ]),
    );
  }
}
