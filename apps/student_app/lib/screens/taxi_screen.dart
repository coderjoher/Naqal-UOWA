import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/taxi.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';
import 'taxi_ride_view.dart';
import 'taxi_widgets.dart';

/// Where the map opens when neither the gathering point nor the campus is known (Karbala).
const taxiFallbackCenter = LatLng(32.616, 44.025);

/// The map waits this long after the student stops moving it before asking for a new fare.
const taxiQuoteDebounce = Duration(milliseconds: 600);

/// P10: a taxi between the student's spot and campus. Plan (direction, spot, fare) → request →
/// follow the ride. Opens straight on the ride when one is already going.
class TaxiScreen extends ConsumerStatefulWidget {
  const TaxiScreen({super.key, this.rideId});
  final String? rideId;

  @override
  ConsumerState<TaxiScreen> createState() => _TaxiScreenState();
}

class _TaxiScreenState extends ConsumerState<TaxiScreen> {
  final _map = MapController();
  final _label = TextEditingController();
  String? _rideId;
  var _booting = true;

  var _direction = TaxiDirection.toCampus;
  LatLng? _start;
  LatLng? _point;
  LatLng? _campus;
  var _moving = false;
  var _locating = false;
  Timer? _debounce;

  TaxiQuote? _quote;
  Object? _quoteError;
  var _quoting = false;
  var _quoteSeq = 0;

  /// One key per booking attempt: a retry after a lost response sends the same key, so the
  /// server returns the ride it already made instead of a second one.
  String? _clientId;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _rideId = widget.rideId;
    _boot();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _label.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final api = ref.read(apiProvider);
    if (_rideId == null) {
      try {
        _rideId = (await api.myTaxiRides()).active?.id;
      } catch (_) {}
    }
    if (_rideId == null) await _resolveStart();
    if (mounted) setState(() => _booting = false);
  }

  /// The gathering point if we know where it is, else the campus.
  Future<void> _resolveStart() async {
    final api = ref.read(apiProvider);
    final pointId = ref.read(authProvider).value?.defaultPoint?.id;
    LatLng? p;
    if (pointId != null) {
      try {
        p = await api.pointLocation(pointId);
      } catch (_) {}
    }
    if (p == null && _campus == null) {
      // The quote carries the campus position.
      try {
        _campus = (await api.taxiQuote(_direction, taxiFallbackCenter)).campus;
      } catch (_) {}
    }
    _start = p ?? _campus ?? taxiFallbackCenter;
    _point = _start;
    unawaited(_loadQuote());
  }

  Future<void> _loadQuote() async {
    final p = _point;
    if (p == null) return;
    final seq = ++_quoteSeq;
    if (mounted) setState(() => _quoting = true);
    try {
      final q = await ref.read(apiProvider).taxiQuote(_direction, p);
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = q;
        _quoteError = null;
        _quoting = false;
        _campus ??= q.campus;
      });
    } catch (e) {
      if (!mounted || seq != _quoteSeq) return;
      setState(() {
        _quote = null;
        _quoteError = e;
        _quoting = false;
      });
    }
  }

  void _pointChanged(LatLng p, {required bool gesture}) {
    _point = p;
    _clientId = null;
    if (gesture && !_moving) setState(() => _moving = true);
    _debounce?.cancel();
    _debounce = Timer(taxiQuoteDebounce, () {
      if (!mounted) return;
      setState(() => _moving = false);
      _loadQuote();
    });
  }

  void _setDirection(TaxiDirection d) {
    setState(() {
      _direction = d;
      _clientId = null;
    });
    _loadQuote();
  }

  Future<void> _useMyLocation() async {
    final t = AppLocalizations.of(context);
    setState(() => _locating = true);
    final p = await ref.read(taxiLocatorProvider)();
    if (!mounted) return;
    setState(() => _locating = false);
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.taxiLocationFailed)));
      return;
    }
    _map.move(p, 16);
    _pointChanged(p, gesture: false);
  }

  Future<void> _request() async {
    final p = _point;
    if (p == null || _sending) return;
    final t = AppLocalizations.of(context);
    final api = ref.read(apiProvider);
    _clientId ??= newTaxiClientId();
    setState(() => _sending = true);
    try {
      final label = _label.text.trim();
      final ride = await api.requestTaxi(direction: _direction, point: p, label: label.isEmpty ? null : label, clientId: _clientId!);
      if (!mounted) return;
      setState(() {
        _clientId = null;
        _rideId = ride.id;
      });
      ref.invalidate(taxiMineProvider);
    } catch (e) {
      // 409: a ride is already going (perhaps this one, sent before a lost response). Show it.
      String? active;
      if (e is ApiException && e.statusCode == 409) {
        try {
          active = (await api.myTaxiRides()).active?.id;
        } catch (_) {}
      }
      if (!mounted) return;
      if (active != null) {
        setState(() {
          _clientId = null;
          _rideId = active;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, t.loadFailed))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _retry() {
    setState(() {
      _rideId = null;
      _clientId = null;
      _booting = _point == null;
    });
    if (_point == null) {
      _boot();
    } else {
      _loadQuote();
    }
  }

  void _home() {
    ref.invalidate(taxiMineProvider);
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final Widget body = _booting
        ? const Padding(
            key: ValueKey('boot'),
            padding: EdgeInsets.all(NaqlSpace.s5),
            child: NaqlSkeleton(height: 360, radius: NaqlRadius.lg),
          )
        : _rideId != null
        ? TaxiRideView(key: ValueKey('ride-$_rideId'), rideId: _rideId!, onRetry: _retry, onHome: _home)
        : KeyedSubtree(key: const ValueKey('plan'), child: _plan(context, t));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NaqlTopBar(title: t.taxiTitle, onBack: _home, backLabel: MaterialLocalizations.of(context).backButtonTooltip),
            Expanded(
              child: AnimatedSwitcher(duration: motion(context, NaqlMotion.sheet), switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic, child: body),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plan(BuildContext context, AppLocalizations t) {
    final tiles = ref.watch(mapTilesProvider);
    final toCampus = _direction == TaxiDirection.toCampus;
    final campus = _campus;
    return LayoutBuilder(
      builder: (context, box) => Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(NaqlRadius.lg),
                child: ColoredBox(
                  color: NaqlColors.surfaceMuted,
                  child: Stack(
                    children: [
                      FlutterMap(
                        key: const ValueKey('taxi-plan-map'),
                        mapController: _map,
                        options: MapOptions(
                          initialCenter: _start ?? taxiFallbackCenter,
                          initialZoom: 15,
                          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                          onPositionChanged: (camera, gesture) => _pointChanged(camera.center, gesture: gesture),
                          onTap: (_, p) {
                            _map.move(p, _map.camera.zoom);
                            _pointChanged(p, gesture: false);
                          },
                        ),
                        children: [
                          if (tiles) TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student'),
                          if (campus != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: campus,
                                  width: 40,
                                  height: 40,
                                  child: TaxiMapPin(icon: LucideIcons.school, label: t.taxiCampus, color: NaqlColors.ink),
                                ),
                              ],
                            ),
                          if (tiles) const SimpleAttributionWidget(source: Text(mapAttribution)),
                        ],
                      ),
                      // The pin's tip sits on the map centre.
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(0, -36),
                          child: TaxiCenterPin(lifted: _moving, label: toCampus ? t.taxiPickupPin : t.taxiDropoffPin),
                        ),
                      ),
                      PositionedDirectional(
                        top: NaqlSpace.s3,
                        start: NaqlSpace.s3,
                        end: NaqlSpace.s3,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s3, vertical: NaqlSpace.s2),
                            decoration: BoxDecoration(color: NaqlColors.surface, borderRadius: BorderRadius.circular(NaqlRadius.pill), boxShadow: naqlCardShadow),
                            child: Text(
                              toCampus ? t.taxiPickupHint : t.taxiDropoffHint,
                              style: NaqlText.caption.copyWith(color: NaqlColors.text),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        bottom: NaqlSpace.s3,
                        end: NaqlSpace.s3,
                        child: NaqlIconButton(
                          key: const ValueKey('taxi-locate'),
                          icon: _locating ? LucideIcons.loaderCircle : LucideIcons.locateFixed,
                          semanticLabel: t.taxiMyLocation,
                          onPressed: _locating ? null : _useMyLocation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.66),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s4, NaqlSpace.s5, NaqlSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaxiSegmented<TaxiDirection>(
                    label: t.taxiDirection,
                    value: _direction,
                    onChanged: _setDirection,
                    options: [(TaxiDirection.toCampus, t.taxiToCampus, LucideIcons.school), (TaxiDirection.fromCampus, t.taxiFromCampus, LucideIcons.house)],
                  ),
                  const SizedBox(height: NaqlSpace.s4),
                  NaqlField(key: const ValueKey('taxi-label'), label: t.taxiLabel, hint: t.taxiLabelHint, controller: _label, prefixIcon: LucideIcons.signpost),
                  const SizedBox(height: NaqlSpace.s4),
                  _QuoteCard(quote: _quote, error: _quoteError, loading: _quoting || _moving, onRetry: _loadQuote),
                  const SizedBox(height: NaqlSpace.s4),
                  NaqlButton(
                    key: const ValueKey('taxi-request'),
                    label: t.taxiRequest,
                    icon: LucideIcons.carTaxiFront,
                    expand: true,
                    loading: _sending,
                    onPressed: _quote == null || _quoting || _moving ? null : _request,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The fare before booking: price first, then distance, time and how many taxis are around.
class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({required this.quote, required this.error, required this.loading, required this.onRetry});
  final TaxiQuote? quote;
  final Object? error;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final q = quote;
    final e = error;
    final Widget child;
    if (q == null && e == null) {
      child = const NaqlSkeleton(key: ValueKey('q-loading'), height: 112, radius: NaqlRadius.lg);
    } else if (q == null) {
      final outside = e is ApiException && e.statusCode == 422;
      child = NaqlCard(
        key: ValueKey('q-error-$outside'),
        child: Row(
          children: [
            Icon(outside ? LucideIcons.mapPinOff : LucideIcons.wifiOff, color: NaqlColors.warning),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(child: Text(outside ? t.taxiUnavailableHere : t.loadFailed, style: NaqlText.body)),
            if (!outside) NaqlButton(label: t.retry, variant: NaqlButtonVariant.ghost, onPressed: onRetry),
          ],
        ),
      );
    } else {
      final facts = [t.taxiKm(formatKm(q.distanceKm)), if (q.durationMin != null) t.taxiMinutes(q.durationMin!)].join(' · ');
      child = NaqlCard(
        key: const ValueKey('q-data'),
        child: AnimatedOpacity(
          duration: motion(context, NaqlMotion.fast),
          opacity: loading ? 0.55 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.taxiFare, style: NaqlText.caption),
                        Text(formatIqd(q.fare, lang), key: const ValueKey('taxi-fare'), style: NaqlText.display.copyWith(fontSize: 28, height: 1.2)),
                      ],
                    ),
                  ),
                  Text(facts, style: NaqlText.label.copyWith(color: NaqlColors.textMuted)),
                ],
              ),
              const SizedBox(height: NaqlSpace.s1),
              Row(
                children: [
                  const Icon(LucideIcons.banknote, size: 16, color: NaqlColors.textMuted),
                  const SizedBox(width: NaqlSpace.s1),
                  Text(t.taxiCash, style: NaqlText.caption),
                ],
              ),
              const SizedBox(height: NaqlSpace.s3),
              if (q.taxisNearby == 0)
                Text(t.taxiNoneNearby, style: NaqlText.label.copyWith(color: NaqlColors.warning))
              else
                Wrap(
                  spacing: NaqlSpace.s2,
                  runSpacing: NaqlSpace.s2,
                  children: [
                    StatusPill(label: t.taxiNearby(q.taxisNearby), tone: NaqlTone.success, icon: LucideIcons.carTaxiFront),
                    if (q.pickupMin != null) StatusPill(label: t.taxiPickupIn(q.pickupMin!), tone: NaqlTone.primary, icon: LucideIcons.clock),
                  ],
                ),
            ],
          ),
        ),
      );
    }
    return AnimatedSwitcher(duration: motion(context, NaqlMotion.fast), child: child);
  }
}
