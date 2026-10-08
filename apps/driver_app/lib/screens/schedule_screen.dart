import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/runs.dart';
import '../l10n/gen/app_localizations.dart';
import 'runs/today_screen.dart';

/// DR-02: availability for the coming days. One big toggle per wave; planned waves are locked.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final days = ref.watch(availabilityProvider);
    return Column(children: [
      NaqlTopBar(title: t.tabSchedule),
      Expanded(
        child: days.when(
          loading: () => const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 200, radius: NaqlRadius.lg)),
          error: (e, _) => Center(
            child: NaqlEmptyState(
              icon: LucideIcons.wifiOff,
              title: t.loadFailed,
              action: NaqlButton(label: t.retry, size: NaqlButtonSize.large, onPressed: () => ref.invalidate(availabilityProvider)),
            ),
          ),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120),
            children: [
              Text(t.scheduleTitle, style: NaqlText.title),
              const SizedBox(height: NaqlSpace.s1),
              Text(t.scheduleBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
              const SizedBox(height: NaqlSpace.s5),
              for (final (i, d) in list.indexed) ...[
                NaqlEntrance(index: i, child: _DayCard(day: d, label: i == 0 ? t.dayToday : (i == 1 ? t.dayTomorrow : null), lang: lang)),
                const SizedBox(height: NaqlSpace.s3),
              ],
            ],
          ),
        ),
      ),
    ]);
  }
}

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.day, required this.lang, this.label});
  final AvailabilityDay day;
  final String lang;
  final String? label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return NaqlCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(formatDayName(day.date, lang), style: NaqlText.headline)),
          if (label != null) StatusPill(label: label!, tone: NaqlTone.primary),
        ]),
        const SizedBox(height: NaqlSpace.s3),
        if (day.waves.isEmpty) Text(t.noWavesDay, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
        for (final w in day.waves)
          _WaveToggle(
            key: ValueKey('wave-${day.date}-${w.waveId}'),
            wave: w,
            onTap: w.locked
                ? null
                : () async {
                    try {
                      await ref.read(availabilityProvider.notifier).toggle(day.date, w.waveId);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, t.availabilityFailed))));
                      }
                    }
                  },
          ),
      ]),
    );
  }
}

/// 56 dp row: wave name and time, a large check that animates on and off.
class _WaveToggle extends StatelessWidget {
  const _WaveToggle({super.key, required this.wave, this.onTap});
  final AvailabilityWave wave;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final on = wave.available;
    return Padding(
      padding: const EdgeInsets.only(top: NaqlSpace.s2),
      child: Semantics(
        toggled: on,
        enabled: onTap != null,
        child: NaqlPressable(
          onPressed: onTap,
          child: AnimatedContainer(
            duration: naqlMotion(context, NaqlMotion.fast),
            constraints: const BoxConstraints(minHeight: NaqlTouch.driver),
            padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
            decoration: BoxDecoration(
              color: on ? NaqlColors.primarySoft : NaqlColors.surfaceMuted,
              borderRadius: BorderRadius.circular(NaqlRadius.md),
              border: Border.all(color: on ? NaqlColors.primary : Colors.transparent, width: 1.5),
            ),
            child: Row(children: [
              Icon(wave.type == WaveType.morning ? LucideIcons.sunrise : LucideIcons.sunset, color: on ? NaqlColors.primary : NaqlColors.textMuted),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(waveName(t, wave.type, wave.time), style: NaqlText.label.copyWith(color: on ? NaqlColors.primary : NaqlColors.text)),
                  if (wave.locked) Text(t.lockedWave, style: NaqlText.caption),
                ]),
              ),
              AnimatedSwitcher(
                duration: naqlMotion(context, NaqlMotion.fast),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: wave.locked
                    ? Icon(LucideIcons.lock, key: ValueKey('lock'), color: NaqlColors.textMuted)
                    : Icon(on ? LucideIcons.circleCheck : LucideIcons.circle, key: ValueKey(on), color: on ? NaqlColors.primary : NaqlColors.border, size: 28),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
