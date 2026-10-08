import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/history.dart';
import '../l10n/gen/app_localizations.dart';

/// Five stars; tappable when [onChanged] is given (48 dp targets).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.value, this.onChanged, this.size = 36});
  final int value;
  final ValueChanged<int>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        onChanged == null
            ? Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i <= value ? NaqlColors.accent : NaqlColors.border)
            : Semantics(
                button: true,
                selected: i <= value,
                label: '$i',
                child: InkResponse(
                  key: ValueKey('star-$i'),
                  onTap: () => onChanged!(i),
                  radius: 28,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: AnimatedScale(
                      scale: i <= value ? 1.1 : 1,
                      duration: NaqlMotion.fast,
                      child: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i <= value ? NaqlColors.accent : NaqlColors.textMuted),
                    ),
                  ),
                ),
              ),
    ]);
  }
}

/// ST-11: rate a finished ride once.
Future<void> showRateSheet(BuildContext context, RideHistoryItem ride) => showNaqlSheet<void>(context, builder: (_) => _RateSheet(ride: ride));

class _RateSheet extends ConsumerStatefulWidget {
  const _RateSheet({required this.ride});
  final RideHistoryItem ride;

  @override
  ConsumerState<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends ConsumerState<_RateSheet> {
  var _stars = 0;
  final _comment = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(rideHistoryProvider.notifier).rate(widget.ride.id, _stars, _comment.text.trim().isEmpty ? null : _comment.text.trim());
      if (mounted) {
        final t = AppLocalizations.of(context);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.rateThanks)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, AppLocalizations.of(context).loadFailed));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(t.rateTitle, style: NaqlText.title),
        const SizedBox(height: NaqlSpace.s1),
        Text(t.rateBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
        const SizedBox(height: NaqlSpace.s5),
        Center(child: StarRow(value: _stars, onChanged: (v) => setState(() => _stars = v))),
        const SizedBox(height: NaqlSpace.s5),
        NaqlField(label: t.rateComment, controller: _comment, maxLines: 3),
        if (_error != null) ...[
          const SizedBox(height: NaqlSpace.s3),
          Text(_error!, style: NaqlText.body.copyWith(color: NaqlColors.danger)),
        ],
        const SizedBox(height: NaqlSpace.s5),
        NaqlButton(label: t.rateSend, expand: true, loading: _sending, onPressed: _stars == 0 ? null : _send),
      ]),
    );
  }
}

/// ST-11: report a problem (optionally about one ride); it reaches the transport office.
Future<void> showProblemSheet(BuildContext context, {String? requestId}) => showNaqlSheet<void>(context, builder: (_) => _ProblemSheet(requestId: requestId));

class _ProblemSheet extends ConsumerStatefulWidget {
  const _ProblemSheet({this.requestId});
  final String? requestId;

  @override
  ConsumerState<_ProblemSheet> createState() => _ProblemSheetState();
}

class _ProblemSheetState extends ConsumerState<_ProblemSheet> {
  String? _category;
  final _text = TextEditingController();
  var _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).reportProblem(category: _category!, text: _text.text.trim(), requestId: widget.requestId);
      if (mounted) {
        final t = AppLocalizations.of(context);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.problemSent)));
      }
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorMessage(e, AppLocalizations.of(context).loadFailed));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final labels = {
      'late': t.problemLate,
      'driver': t.problemDriver,
      'vehicle': t.problemVehicle,
      'safety': t.problemSafety,
      'app': t.problemApp,
      'other': t.problemOther,
    };
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Text(t.problemTitle, style: NaqlText.title),
          const SizedBox(height: NaqlSpace.s1),
          Text(t.problemBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
          const SizedBox(height: NaqlSpace.s5),
          Wrap(spacing: NaqlSpace.s2, runSpacing: NaqlSpace.s2, children: [
            for (final c in problemCategories) NaqlChip(key: ValueKey('cat-$c'), label: labels[c]!, selected: _category == c, onSelected: () => setState(() => _category = c)),
          ]),
          const SizedBox(height: NaqlSpace.s4),
          NaqlField(label: t.problemText, controller: _text, maxLines: 4),
          if (_error != null) ...[
            const SizedBox(height: NaqlSpace.s3),
            Text(_error!, style: NaqlText.body.copyWith(color: NaqlColors.danger)),
          ],
          const SizedBox(height: NaqlSpace.s5),
          NaqlButton(label: t.problemSend, expand: true, loading: _sending, onPressed: _category == null || _text.text.trim().length < 5 ? null : _send),
        ]),
      ),
    );
  }
}
