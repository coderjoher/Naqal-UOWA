import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/auth.dart';
import '../../l10n/gen/app_localizations.dart';

/// Default gathering point (ST-02). Used in onboarding and from the profile.
class ChoosePointScreen extends ConsumerStatefulWidget {
  const ChoosePointScreen({super.key, this.changing = false});
  final bool changing;

  @override
  ConsumerState<ChoosePointScreen> createState() => _ChoosePointScreenState();
}

class _ChoosePointScreenState extends ConsumerState<ChoosePointScreen> {
  String? _selected;
  String _query = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(authProvider).value?.defaultPoint?.id;
  }

  Future<void> _save() async {
    if (_selected == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(authProvider.notifier).setDefaultPoint(_selected!);
      if (mounted && widget.changing) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final points = ref.watch(pointsProvider);
    String fmt(double km) => km.toStringAsFixed(1);
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.choosePointTitle, onBack: widget.changing ? () => context.pop() : null),
        Expanded(
          child: points.when(
            loading: () => ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
              for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: NaqlSpace.s3), child: NaqlSkeleton(height: 64, radius: NaqlRadius.md)),
            ]),
            error: (_, _) => Center(
              child: NaqlEmptyState(
                icon: LucideIcons.wifiOff,
                title: t.loadFailed,
                action: NaqlButton(label: t.retry, variant: NaqlButtonVariant.secondary, onPressed: () => ref.invalidate(pointsProvider)),
              ),
            ),
            data: (all) {
              final q = _query.trim();
              final list = [...all.where((p) => q.isEmpty || p.displayName(lang).contains(q) || p.name.toLowerCase().contains(q.toLowerCase()))]
                ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
              if (all.isEmpty) return Center(child: NaqlEmptyState(icon: LucideIcons.mapPin, title: t.noPoints, message: t.noPointsBody));
              return ListView(padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120), children: [
                Text(t.choosePointBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
                const SizedBox(height: NaqlSpace.s4),
                NaqlField(label: t.searchPoints, prefixIcon: LucideIcons.search, onChanged: (v) => setState(() => _query = v)),
                const SizedBox(height: NaqlSpace.s4),
                for (final (i, GatheringPoint p) in list.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: NaqlSpace.s2),
                    child: NaqlEntrance(
                      index: i,
                      child: NaqlListRow(
                        title: p.displayName(lang),
                        subtitle: [if (p.tierName != null) t.tierLabel(p.tierName!), if (p.distanceKm != null) t.kmAway(fmt(p.distanceKm!))].join(' · '),
                        leading: NaqlLetterBadge(p.tierName ?? '•', active: _selected == p.id),
                        selectable: true,
                        selected: _selected == p.id,
                        onTap: () => setState(() => _selected = p.id),
                      ),
                    ),
                  ),
              ]);
            },
          ),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(NaqlSpace.s5),
        child: NaqlButton(label: t.savePoint, expand: true, loading: _busy, onPressed: _selected == null ? null : _save),
      ),
    );
  }
}
