import 'package:flutter/material.dart';
import 'package:naql_ui/naql_ui.dart';

import '../l10n/gen/app_localizations.dart';

/// Today's runs (DR-03 arrives in P4). Driver UI uses the large 56 dp targets.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      NaqlTopBar(title: t.todayRuns),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(NaqlSpace.s6),
            child: NaqlEmptyState(icon: LucideIcons.route, title: t.noRunsToday, message: t.noRunsTodayBody),
          ),
        ),
      ),
    ]);
  }
}
