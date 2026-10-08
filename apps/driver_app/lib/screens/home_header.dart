import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/session.dart';
import '../l10n/gen/app_localizations.dart';

/// Top of the driver's Home: avatar, greeting and name, what they drive, and their plate.
class DriverHomeHeader extends ConsumerWidget {
  const DriverHomeHeader({super.key, required this.service});

  /// "Campus taxi", or the bus type.
  final String service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final a = ref.watch(applicationProvider).value;
    final name = (a?.name?.trim().isNotEmpty ?? false) ? a!.name!.trim() : (a?.phone?.replaceFirst('+964', '0') ?? '');
    final morning = clock.now().toUtc().add(const Duration(hours: 3)).hour < 12;
    return Row(children: [
      NaqlAvatar(name: name.isEmpty ? '؟' : name, size: 52, square: true),
      const SizedBox(width: NaqlSpace.s3),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(morning ? t.greetMorning : t.greetEvening, style: NaqlText.caption.copyWith(fontSize: 13)),
          Text(name, style: NaqlText.title.copyWith(fontSize: 20, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: a?.name == null ? TextDirection.ltr : null),
          Text(service, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
      if (a?.plate != null) NaqlPlateBadge(a!.plate!, semanticLabel: '${t.plate}: ${a.plate}'),
    ]);
  }
}

/// Three figure tiles side by side.
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final (i, tile) in tiles.indexed) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: tile)],
      ]);
}
