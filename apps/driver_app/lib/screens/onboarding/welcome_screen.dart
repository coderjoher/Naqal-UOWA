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
          padding: const EdgeInsets.all(NaqlSpace.s5),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Align(alignment: AlignmentDirectional.centerStart, child: ServerSettingsButton()),
            const Spacer(),
            NaqlEntrance(
              child: Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(color: NaqlColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.busFront, size: 56, color: NaqlColors.primary),
                ),
              ),
            ),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 1, child: Text(t.welcomeTitle, style: NaqlText.title.copyWith(fontSize: 26), textAlign: TextAlign.center)),
            const SizedBox(height: NaqlSpace.s3),
            NaqlEntrance(index: 2, child: Text(t.welcomeBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted), textAlign: TextAlign.center)),
            const Spacer(),
            NaqlEntrance(index: 3, child: Text(t.chooseLanguage, style: NaqlText.label)),
            const SizedBox(height: NaqlSpace.s2),
            NaqlEntrance(index: 4, child: NaqlListRow(title: t.arabic, selectable: true, selected: lang == 'ar', onTap: () => ref.read(localeProvider.notifier).set('ar'))),
            const SizedBox(height: NaqlSpace.s2),
            NaqlEntrance(index: 5, child: NaqlListRow(title: t.english, selectable: true, selected: lang == 'en', onTap: () => ref.read(localeProvider.notifier).set('en'))),
            const SizedBox(height: NaqlSpace.s5),
            NaqlEntrance(
              index: 6,
              child: NaqlButton(label: t.continueLabel, size: NaqlButtonSize.large, expand: true, onPressed: () => context.go('/university')),
            ),
          ]),
        ),
      ),
    );
  }
}
