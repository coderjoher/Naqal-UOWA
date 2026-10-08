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
  const TaxiScreen({super.key, this.rideId, this.direction});
  final String? rideId;

  /// Start planning in this direction (Home's quick destinations).
  final TaxiDirection? direction;

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

  /// The student's gathering point on the map, when the office has placed it.
  LatLng? _gathering;
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
    _direction = widget.direction ?? TaxiDirection.toCampus;
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
    _gathering = p;
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

  /// Quick destination chip: centre the map there and price it.
  void _goTo(LatLng p) {
    _map.move(p, _map.camera.zoom < 15 ? 15 : _map.camera.zoom);
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
    context.canPop() ? context.pop() : context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final back = MaterialLocalizations.of(context).backButtonTooltip;
    final Widget body = _booting
        ? TaxiBarFrame(
            key: const ValueKey('boot'),
            title: t.taxiTitle,
            onBack: _home,
            child: const Padding(padding: EdgeInsets.all(NaqlSpace.s5), child: NaqlSkeleton(height: 360, radius: NaqlRadius.lg)),
          )
        : _rideId != null
        ? TaxiRideView(key: ValueKey('ride-$_rideId'), rideId: _rideId!, onRetry: _retry, onHome: _home, title: t.taxiTitle, backLabel: back)
        : KeyedSubtree(key: const ValueKey('plan'), child: _plan(context, t, back));
    return Scaffold(
      body: AnimatedSwitcher(duration: motion(context, NaqlMotion.sheet), switchInCurve: Curves.easeOutCubic, switchOutCurve: Curves.easeInCubic, child: body),
    );
  }

  /// Map-first planning: a full-bleed map with the pin at its centre, floating controls and quick
  /// destinations on top, and a sheet with the direction options, the fare and the request button.
  Widget _plan(BuildContext context, AppLocalizations t, String backLabel) {
    final tiles = ref.watch(mapTilesProvider);
    final toCampus = _direction == TaxiDirection.toCampus;
    final campus = _campus;
    final gathering = _gathering;
    const overlap = 28.0;
    final map = Stack(
      children: [
        const Positioned.fill(child: NaqlMapBackdrop()),
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0x00000000),
            child: FlutterMap(
              key: const ValueKey('taxi-plan-map'),
              mapController: _map,
              options: MapOptions(
                backgroundColor: const Color(0x00000000),
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
                if (tiles) NaqlMapTint(child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student')),
                if (campus != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: campus,
                        width: 40,
                        height: 40,
                        child: TaxiMapPin(icon: LucideIcons.school, label: t.taxiCampus, color: NaqlColors.accent, onColor: NaqlColors.onAccent),
                      ),
                    ],
                  ),
                if (tiles) const TaxiAttribution(text: mapAttribution, bottom: overlap + 56),
              ],
            ),
          ),
        ),
        // The pin's tip sits on the map centre.
        Align(
          alignment: Alignment.center,
          child: Transform.translate(
            offset: const Offset(0, -36),
            child: TaxiCenterPin(lifted: _moving, label: toCampus ? t.taxiPickupPin : t.taxiDropoffPin),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: TaxiMapTop(
            title: t.taxiTitle,
            onBack: _home,
            backLabel: backLabel,
            below: TaxiMapHint(toCampus ? t.taxiPickupHint : t.taxiDropoffHint),
          ),
        ),
        // Quick destinations, just above the sheet.
        Positioned(
          left: 0,
          right: 0,
          bottom: overlap + NaqlSpace.s3,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4, vertical: NaqlSpace.s1),
            child: Row(
              spacing: NaqlSpace.s2,
              children: [
                NaqlChip(
                  key: const ValueKey('taxi-locate'),
                  label: t.taxiChipHere,
                  icon: _locating ? LucideIcons.loaderCircle : LucideIcons.locateFixed,
                  floating: true,
                  selected: false,
                  onSelected: _locating ? null : _useMyLocation,
                ),
                if (campus != null) NaqlChip(label: t.taxiCampus, icon: LucideIcons.school, floating: true, selected: false, onSelected: () => _goTo(campus)),
                if (gathering != null) NaqlChip(label: t.taxiChipPoint, icon: LucideIcons.mapPin, floating: true, selected: false, onSelected: () => _goTo(gathering)),
              ],
            ),
          ),
        ),
      ],
    );
    final quote = _quote;
    final busy = _quoting || _moving;
    String? badgeFor(TaxiDirection d) => d == _direction && quote != null ? formatIqd(quote.fare, ref.watch(localeProvider).languageCode) : null;
    String subFor(TaxiDirection d) => d == _direction && quote != null
        ? [t.taxiKm(formatKm(quote.distanceKm)), if (quote.durationMin != null) t.taxiMinutes(quote.durationMin!)].join(' · ')
        : (d == TaxiDirection.toCampus ? t.taxiToCampusSub : t.taxiFromCampusSub);
    final sheet = NaqlMapSheet(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                container: true,
                label: t.taxiDirection,
                child: AnimatedOpacity(
                  duration: motion(context, NaqlMotion.fast),
                  opacity: busy && quote != null ? 0.7 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: NaqlSpace.s2,
                    children: [
                      for (final (d, title, icon) in [(TaxiDirection.toCampus, t.taxiToCampus, LucideIcons.school), (TaxiDirection.fromCampus, t.taxiFromCampus, LucideIcons.house)])
                        NaqlOptionCard(
                          key: ValueKey('taxi-dir-$d'),
                          icon: icon,
                          title: title,
                          subtitle: subFor(d),
                          badge: badgeFor(d),
                          selected: d == _direction,
                          onTap: d == _direction ? () {} : () => _setDirection(d),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: NaqlSpace.s3),
              _QuoteCard(quote: _quote, error: _quoteError, loading: busy, onRetry: _loadQuote),
              const SizedBox(height: NaqlSpace.s3),
              NaqlField(key: const ValueKey('taxi-label'), label: t.taxiLabel, hint: t.taxiLabelHint, controller: _label, prefixIcon: LucideIcons.signpost),
              const SizedBox(height: NaqlSpace.s4),
              NaqlButton(
                key: const ValueKey('taxi-request'),
                label: t.taxiRequest,
                icon: LucideIcons.carTaxiFront,
                expand: true,
                loading: _sending,
                onPressed: quote == null || busy ? null : _request,
              ),
            ],
          ),
        ),
      ),
    );
    return NaqlMapScaffold(map: map, sheet: sheet, overlap: overlap);
  }
}

/// What the fare depends on, under the options: cash, taxis around and pickup time; or why there
/// is no fare (outside the service area, offline). The fare itself sits on the selected option.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.error, required this.loading, required this.onRetry});
  final TaxiQuote? quote;
  final Object? error;
  final bool loading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final q = quote;
    final e = error;
    final Widget child;
    if (q == null && e == null) {
      child = const NaqlSkeleton(key: ValueKey('q-loading'), height: 36, radius: NaqlRadius.pill);
    } else if (q == null) {
      final outside = e is ApiException && e.statusCode == 422;
      child = Container(
        key: ValueKey('q-error-$outside'),
        padding: const EdgeInsetsDirectional.fromSTEB(NaqlSpace.s4, NaqlSpace.s1, NaqlSpace.s1, NaqlSpace.s1),
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(color: NaqlColors.warningSoft, borderRadius: BorderRadius.circular(NaqlRadius.md)),
        child: Row(
          children: [
            Icon(outside ? LucideIcons.mapPinOff : LucideIcons.wifiOff, color: NaqlColors.warning, size: 20),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(child: Text(outside ? t.taxiUnavailableHere : t.loadFailed, style: NaqlText.label.copyWith(color: NaqlColors.text))),
            if (!outside) NaqlButton(label: t.retry, variant: NaqlButtonVariant.ghost, onPressed: onRetry),
          ],
        ),
      );
    } else {
      child = AnimatedOpacity(
        key: const ValueKey('q-data'),
        duration: motion(context, NaqlMotion.fast),
        opacity: loading ? 0.55 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: NaqlSpace.s2,
              runSpacing: NaqlSpace.s2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(label: t.taxiCash, icon: LucideIcons.banknote),
                if (q.taxisNearby > 0) StatusPill(label: t.taxiNearby(q.taxisNearby), tone: NaqlTone.success, icon: LucideIcons.carTaxiFront),
                if (q.taxisNearby > 0 && q.pickupMin != null) StatusPill(label: t.taxiPickupIn(q.pickupMin!), tone: NaqlTone.primary, icon: LucideIcons.clock),
              ],
            ),
            if (q.taxisNearby == 0) ...[
              const SizedBox(height: NaqlSpace.s2),
              Text(t.taxiNoneNearby, style: NaqlText.label.copyWith(color: NaqlColors.warning)),
            ],
          ],
        ),
      );
    }
    return AnimatedSwitcher(duration: motion(context, NaqlMotion.fast), child: child);
  }
}
