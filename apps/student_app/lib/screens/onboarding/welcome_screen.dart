import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../l10n/gen/app_localizations.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, NaqlSpace.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: ServerSettingsButton()),
            const SizedBox(height: NaqlSpace.s2),
            // Brand hero: the university's blue with a gold route around campus.
            const Expanded(child: NaqlEntrance(child: NaqlHeroArt(icon: LucideIcons.busFront, height: double.infinity))),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 1, child: Semantics(header: true, child: Text(t.welcomeTitle, style: NaqlText.hero))),
            const SizedBox(height: NaqlSpace.s2),
            NaqlEntrance(index: 2, child: Text(t.welcomeBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
            const SizedBox(height: NaqlSpace.s5),
            NaqlEntrance(
              index: 3,
              child: Semantics(
                container: true,
                label: t.chooseLanguage,
                child: Row(children: [
                  Icon(LucideIcons.languages, size: 20, color: NaqlColors.textMuted),
                  const SizedBox(width: NaqlSpace.s2),
                  Expanded(child: Text(t.chooseLanguage, style: NaqlText.label.copyWith(color: NaqlColors.textMuted))),
                  NaqlChip(label: t.arabic, selected: lang == 'ar', onSelected: () => ref.read(localeProvider.notifier).set('ar')),
                  const SizedBox(width: NaqlSpace.s2),
                  NaqlChip(label: t.english, selected: lang == 'en', onSelected: () => ref.read(localeProvider.notifier).set('en')),
                ]),
              ),
            ),
            const SizedBox(height: NaqlSpace.s5),
            NaqlEntrance(index: 4, child: NaqlButton(label: t.continueLabel, expand: true, onPressed: () => context.go('/university'))),
          ]),
        ),
      ),
    );
  }
}
