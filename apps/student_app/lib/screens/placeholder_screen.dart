import 'package:flutter/material.dart';
import 'package:naql_ui/naql_ui.dart';

import '../l10n/gen/app_localizations.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Column(children: [
      NaqlTopBar(title: title),
      Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(NaqlSpace.s6),
            child: NaqlEmptyState(icon: LucideIcons.hammer, title: t.comingSoon, message: t.comingSoonBody),
          ),
        ),
      ),
    ]);
  }
}
