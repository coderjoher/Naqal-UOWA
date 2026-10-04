import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/session.dart';
import '../l10n/gen/app_localizations.dart';

/// Pending / rejected / suspended applications (TO-02 outcome as the driver sees it).
class StatusScreen extends ConsumerWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final a = ref.watch(applicationProvider).value;
    if (a == null) return const SizedBox.shrink();
    final (icon, title, body, tone) = switch (a.status) {
      DriverStatus.rejected => (LucideIcons.circleX, t.statusRejectedTitle, t.statusRejectedBody, NaqlTone.danger),
      DriverStatus.suspended => (LucideIcons.ban, t.statusSuspendedTitle, t.statusSuspendedBody, NaqlTone.danger),
      _ => (LucideIcons.hourglass, t.statusPendingTitle, t.statusPendingBody, NaqlTone.warning),
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(NaqlSpace.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            NaqlEntrance(
              child: Center(
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
                  child: Icon(icon, size: 52, color: tone.fg),
                ),
              ),
            ),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 1, child: Text(title, style: NaqlText.title, textAlign: TextAlign.center)),
            const SizedBox(height: NaqlSpace.s3),
            NaqlEntrance(index: 2, child: Text(body, style: NaqlText.body.copyWith(color: NaqlColors.textMuted), textAlign: TextAlign.center)),
            if (a.reviewNote != null && a.status != DriverStatus.pending) ...[
              const SizedBox(height: NaqlSpace.s5),
              NaqlEntrance(
                index: 3,
                child: NaqlCard(nested: true, child: Text('${t.reason}: ${a.reviewNote}', style: NaqlText.body, textAlign: TextAlign.center)),
              ),
            ],
            const Spacer(),
            if (a.status == DriverStatus.rejected)
              NaqlButton(label: t.editApplication, size: NaqlButtonSize.large, expand: true, onPressed: () => context.go('/apply'))
            else
              NaqlButton(label: t.refresh, size: NaqlButtonSize.large, variant: NaqlButtonVariant.secondary, expand: true, onPressed: () => ref.read(applicationProvider.notifier).refresh()),
            const SizedBox(height: NaqlSpace.s2),
            NaqlButton(label: t.signOut, variant: NaqlButtonVariant.ghost, expand: true, onPressed: () => ref.read(applicationProvider.notifier).signOut()),
          ]),
        ),
      ),
    );
  }
}
