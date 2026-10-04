import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../l10n/gen/app_localizations.dart';

class UniversityScreen extends ConsumerWidget {
  const UniversityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final list = ref.watch(universitiesProvider);
    final selected = ref.watch(universitySlugProvider);
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.chooseUniversity, onBack: () => context.go('/welcome')),
        Expanded(
          child: list.when(
            loading: () => ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
              for (var i = 0; i < 3; i++) const Padding(padding: EdgeInsets.only(bottom: NaqlSpace.s3), child: NaqlSkeleton(height: 64, radius: NaqlRadius.md)),
            ]),
            error: (_, _) => Center(
              child: NaqlEmptyState(
                icon: LucideIcons.wifiOff,
                title: t.loadFailed,
                action: NaqlButton(label: t.retry, variant: NaqlButtonVariant.secondary, onPressed: () => ref.invalidate(universitiesProvider)),
              ),
            ),
            data: (unis) => ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
              Text(t.chooseUniversityBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
              const SizedBox(height: NaqlSpace.s4),
              for (final (i, u) in unis.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
                  child: NaqlEntrance(
                    index: i,
                    child: NaqlListRow(
                      title: u.displayName(lang),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
                        child: const Icon(LucideIcons.graduationCap, size: 20, color: NaqlColors.primary),
                      ),
                      selected: selected == u.slug,
                      onTap: () {
                        ref.read(universitySlugProvider.notifier).set(u.slug);
                        context.go('/phone');
                      },
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
