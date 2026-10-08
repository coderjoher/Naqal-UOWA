import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/history.dart';
import '../data/home.dart';
import '../data/rides.dart';
import '../data/subscription.dart';
import '../data/taxi.dart';
import '../data/track.dart';
import '../l10n/gen/app_localizations.dart';
import 'ride_cards.dart';
import 'taxi_widgets.dart';

enum HomeService { bus, taxi }

/// Map-first Home, the hub of the student app: a full-bleed map with the account, place and
/// notifications floating on top and quick destinations above a bottom sheet. The sheet answers
/// "where to today?" with two big service cards (university bus, taxi) and one call to action,
/// or — while a ride is going — shows that ride, live.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _map = MapController();
  var _service = HomeService.bus;

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  bool get _taxiOn => ref.read(taxiEnabledProvider).value ?? false;

  /// Opens the chosen service, optionally heading to campus (true) or home (false).
  void _open({bool? toCampus, RideSlot? slot}) {
    final taxi = _service == HomeService.taxi && _taxiOn;
    if (taxi) {
      context.push(toCampus == null ? '/taxi' : '/taxi?dir=${toCampus ? 'to' : 'from'}');
    } else {
      final q = <String, String>{
        if (toCampus != null) 'dir': toCampus ? 'morning' : 'return',
        if (slot != null) 'wave': slot.waveId,
        if (slot != null) 'date': slot.date,
      };
      context.push(Uri(path: '/bus', queryParameters: q.isEmpty ? null : q).toString());
    }
  }

  void _showPoint(LatLng? p) {
    if (p == null) {
      context.push('/profile/point');
      return;
    }
    try {
      _map.move(p, 15);
    } catch (_) {
      /* the map is not on screen yet */
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final user = ref.watch(authProvider).value;
    final point = ref.watch(pointLocationProvider).value;
    const overlap = 32.0;
    final pointName = user?.defaultPoint?.displayName(lang);
    final unread = ref.watch(unreadCountProvider);

    final map = Stack(children: [
      Positioned.fill(child: _HomeMap(controller: _map, overlap: overlap)),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(NaqlSpace.s4, NaqlSpace.s3, NaqlSpace.s4, 0),
            child: Row(children: [
              NaqlAvatarButton(name: user?.displayName(lang) ?? '', semanticLabel: t.tabProfile, onPressed: () => context.push('/profile')),
              const SizedBox(width: 10),
              Expanded(
                child: NaqlPlacePill(
                  label: pointName ?? t.notSet,
                  semanticLabel: '${t.yourPoint}: ${pointName ?? t.notSet}',
                  onTap: () => _showPoint(point),
                ),
              ),
              const SizedBox(width: 10),
              NaqlIconButton.floating(
                icon: LucideIcons.bell,
                badge: unread > 0,
                semanticLabel: unread > 0 ? t.notificationsUnread(unread) : t.notifications,
                onPressed: () => context.push('/alerts'),
              ),
            ]),
          ),
        ),
      ),
      // Quick destinations, just above the sheet.
      Positioned(
        left: 0,
        right: 0,
        bottom: overlap + NaqlSpace.s3,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
          child: Row(spacing: NaqlSpace.s2, children: [
            NaqlChip(key: const ValueKey('chip-home'), label: t.chipHome, icon: LucideIcons.house, floating: true, selected: false, iconColor: NaqlColors.text, onSelected: () => _open(toCampus: false)),
            NaqlChip(
              key: const ValueKey('chip-campus'),
              label: t.rideCampus,
              icon: LucideIcons.graduationCap,
              floating: true,
              selected: false,
              iconColor: naqlIsDark ? NaqlColors.accent : NaqlColors.primary,
              onSelected: () => _open(toCampus: true),
            ),
            if (pointName != null)
              NaqlChip(key: const ValueKey('chip-point'), label: pointName, icon: LucideIcons.mapPin, floating: true, selected: false, iconColor: NaqlColors.text, onSelected: () => _showPoint(point)),
          ]),
        ),
      ),
    ]);

    final sheet = NaqlMapSheet(
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const _Announcements(),
            _Greeting(name: user?.displayName(lang).split(' ').first, lang: lang),
            const SizedBox(height: 14),
            AnimatedSize(
              duration: naqlMotion(context, NaqlMotion.sheet),
              curve: naqlEaseOut,
              alignment: Alignment.topCenter,
              child: _SheetBody(
                service: _service,
                onService: (s) => setState(() => _service = s),
                onOpen: _open,
              ),
            ),
          ]),
        ),
      ),
    );
    return Scaffold(body: NaqlMapScaffold(map: map, sheet: sheet, overlap: overlap, maxSheetFraction: 0.68));
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.lang});
  final String? name;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final morning = baghdadMorning();
    final hello = name == null || name!.isEmpty
        ? (morning ? t.greetMorningPlain : t.greetEveningPlain)
        : (morning ? t.greetMorning(name!) : t.greetEvening(name!));
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: Semantics(header: true, child: Text(hello, style: NaqlText.title.copyWith(fontSize: 24, height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis))),
      const SizedBox(width: NaqlSpace.s2),
      Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(formatDayName(baghdadDay(), lang), style: NaqlText.caption.copyWith(fontSize: 13))),
    ]);
  }
}

/// Either the live rides (bus and/or taxi) or the "where to?" choice.
class _SheetBody extends ConsumerWidget {
  const _SheetBody({required this.service, required this.onService, required this.onOpen});
  final HomeService service;
  final ValueChanged<HomeService> onService;
  final void Function({bool? toCampus, RideSlot? slot}) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider).languageCode;
    final user = ref.watch(authProvider).value;
    final rides = ref.watch(ridesProvider);
    final taxiOn = ref.watch(taxiEnabledProvider).value ?? false;
    final taxi = taxiOn ? ref.watch(taxiMineProvider).value?.active : null;
    final ride = currentRide(rides.value ?? const []);

    final live = <Widget>[
      if (ride != null) _busCard(context, ref, ride, lang, user),
      if (taxi != null) TaxiLiveCard(key: ValueKey('taxi-live-${taxi.id}-${taxi.status.name}'), ride: taxi, onTap: () => context.push('/taxi?ride=${taxi.id}')),
    ];
    final Widget child = live.isNotEmpty
        ? Column(key: const ValueKey('live'), crossAxisAlignment: CrossAxisAlignment.stretch, spacing: NaqlSpace.s3, children: live)
        : _Choose(
            key: const ValueKey('choose'),
            service: taxiOn ? service : HomeService.bus,
            taxiOn: taxiOn,
            onService: onService,
            onOpen: onOpen,
            offline: rides.hasError && !rides.hasValue,
            expired: switch (lastExpired(rides.value ?? const [])) { final e? => AppLocalizations.of(context).rideExpired(e.waveTime), null => null },
          );
    return AnimatedSwitcher(
      duration: naqlMotion(context, NaqlMotion.sheet),
      reverseDuration: naqlMotion(context, NaqlMotion.fast),
      switchInCurve: naqlEaseOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topCenter, children: [...prev, ?cur]),
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: c)),
      child: KeyedSubtree(key: ValueKey('${ride?.id}-${ride?.status}-${taxi?.id}-${live.isEmpty}'), child: child),
    );
  }

  Widget _busCard(BuildContext context, WidgetRef ref, RideInfo ride, String lang, StudentProfile? user) {
    final today = ride.date == baghdadDay();
    void cancel() => _cancel(context, ref, ride);
    return switch (ride.status) {
      RideStatus.assigned when ride.assignment != null => AssignmentCard(
          ride: ride,
          lang: lang,
          today: today,
          femaleOnly: user?.gender == Gender.female,
          photo: ride.assignment!.vehiclePhotoUrl == null ? null : NetworkImage(ref.read(apiProvider).resolve(ride.assignment!.vehiclePhotoUrl!).toString()),
          onCancel: cancel,
          onTrack: ride.assignment!.trackable ? () => context.go('/home/track/${ride.id}') : null,
        ),
      RideStatus.waitlisted => WaitlistCard(ride: ride, today: today, onCancel: cancel),
      _ => PendingRideCard(ride: ride, lang: lang, today: today, onCancel: cancel),
    };
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, RideInfo ride) async {
    final t = AppLocalizations.of(context);
    final yes = await showNaqlSheet<bool>(
      context,
      builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(t.rideCancelTitle, style: NaqlText.title),
        const SizedBox(height: NaqlSpace.s2),
        Text(t.rideCancelBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
        const SizedBox(height: NaqlSpace.s5),
        NaqlButton(label: t.rideCancelYes, variant: NaqlButtonVariant.danger, expand: true, onPressed: () => Navigator.of(c).pop(true)),
        const SizedBox(height: NaqlSpace.s2),
        NaqlButton(label: t.rideKeep, variant: NaqlButtonVariant.secondary, expand: true, onPressed: () => Navigator.of(c).pop(false)),
      ]),
    );
    if (yes != true) return;
    try {
      await ref.read(apiProvider).cancelRide(ride.id);
    } catch (e) {
      if (context.mounted) {
        await showNaqlSheet<void>(context, builder: (_) => Text(apiErrorMessage(e, t.loadFailed), style: NaqlText.body));
      }
    }
    ref.invalidate(ridesProvider);
  }
}

/// No ride going: where to, the two services, the subscription and one call to action.
class _Choose extends ConsumerWidget {
  const _Choose({super.key, required this.service, required this.taxiOn, required this.onService, required this.onOpen, this.offline = false, this.expired});
  final HomeService service;
  final bool taxiOn;
  final ValueChanged<HomeService> onService;
  final void Function({bool? toCampus, RideSlot? slot}) onOpen;
  final bool offline;
  final String? expired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final sub = ref.watch(subscriptionProvider).value;
    final options = ref.watch(rideOptionsProvider).value;
    final quote = taxiOn ? ref.watch(homeTaxiQuoteProvider).value : null;
    // The next wave with a free seat (a full one would only join the waitlist).
    final next = options?.slots.where((s) => !s.full).firstOrNull ?? options?.slots.firstOrNull;
    final bus = service == HomeService.bus;

    final busCard = NaqlServiceCard(
      key: const ValueKey('service-bus'),
      title: t.serviceBus,
      badge: sub == null ? null : (sub.isActive ? t.serviceIncluded : t.serviceCash),
      badgeStyle: sub?.isActive ?? false ? NaqlBadgeStyle.strong : NaqlBadgeStyle.neutral,
      subtitle: options == null ? null : (next == null ? t.serviceNoTimes : t.serviceNext(next.time)),
      watermark: t.watermarkBus,
      art: const NaqlVehicleArt.bus(width: 120),
      selected: bus,
      onTap: () => onService(HomeService.bus),
    );
    final taxiCard = NaqlServiceCard(
      key: const ValueKey('service-taxi'),
      title: t.serviceTaxi,
      badge: quote?.pickupMin == null || quote!.taxisNearby == 0 ? null : t.taxiMinutes(quote.pickupMin!),
      badgeStyle: NaqlBadgeStyle.success,
      subtitle: quote == null ? t.serviceTaxiSub : t.serviceFrom(formatIqd(quote.fare, lang)),
      watermark: t.watermarkTaxi,
      art: const NaqlVehicleArt.taxi(width: 120),
      selected: !bus,
      onTap: () => onService(HomeService.taxi),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _WhereTo(onTap: () => onOpen()),
      const SizedBox(height: 14),
      if (expired != null) ...[_Note(icon: LucideIcons.info, text: expired!), const SizedBox(height: NaqlSpace.s3)],
      Semantics(
        container: true,
        child: Row(children: [
          Expanded(child: busCard),
          if (taxiOn) ...[const SizedBox(width: NaqlSpace.s3), Expanded(child: taxiCard)],
        ]),
      ),
      const SizedBox(height: 14),
      if (sub != null) _SubscriptionRow(info: sub, lang: lang),
      if (offline) ...[const SizedBox(height: NaqlSpace.s3), _Note(icon: LucideIcons.wifiOff, text: t.loadFailed)],
      const SizedBox(height: NaqlSpace.s4),
      AnimatedSwitcher(
        duration: naqlMotion(context),
        child: NaqlButton(
          key: ValueKey('home-cta-$bus'),
          label: bus ? (next == null ? t.homeBookBusAny : t.homeBookBus(next.time)) : t.taxiRequest,
          icon: bus ? null : LucideIcons.carTaxiFront,
          expand: true,
          onPressed: () => onOpen(slot: bus ? next : null),
        ),
      ),
    ]);
  }
}

class _WhereTo extends StatelessWidget {
  const _WhereTo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return NaqlPressable(
      key: const ValueKey('where-to'),
      onPressed: onTap,
      pressedScale: 0.99,
      semanticLabel: t.whereTo,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: NaqlSpace.s4),
        decoration: BoxDecoration(
          color: naqlIsDark ? NaqlColors.surface : NaqlColors.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: naqlIsDark ? Border.all(color: NaqlColors.border) : null,
        ),
        child: Row(children: [
          Icon(LucideIcons.mapPin, size: 20, color: NaqlColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(t.whereTo, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
        ]),
      ),
    );
  }
}

/// ST-03 at a glance: status and days left; opens the full subscription page.
class _SubscriptionRow extends StatelessWidget {
  const _SubscriptionRow({required this.info, required this.lang});
  final SubscriptionInfo info;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final (title, tone) = switch (info.status) {
      SubscriptionStatus.active => (t.subActive, NaqlTone.primary),
      SubscriptionStatus.expiring => (t.subExpiring(info.daysLeft), NaqlTone.warning),
      SubscriptionStatus.expired => (t.subExpired, NaqlTone.danger),
      SubscriptionStatus.none => (t.subNone, NaqlTone.accent),
    };
    final sub = info.isActive
        ? (info.tierName == null ? t.subUntil(formatDayMonth(info.current?.end ?? DateTime.now(), lang)) : t.subTierDaysLeft(info.tierName!, info.daysLeft))
        : t.subPayShort;
    return NaqlPanel(
      key: const ValueKey('subscription-row'),
      onTap: () => context.push('/subscription'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: NaqlSpace.s3),
      child: Row(children: [
        AnimatedContainer(
          duration: naqlMotion(context),
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(12)),
          child: Icon(LucideIcons.creditCard, size: 20, color: tone.fg),
        ),
        const SizedBox(width: NaqlSpace.s3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedSwitcher(duration: naqlMotion(context), child: Text(title, key: ValueKey(title), style: NaqlText.label.copyWith(fontWeight: FontWeight.w600))),
            Text(sub, style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        Icon(rtl ? LucideIcons.chevronLeft : LucideIcons.chevronRight, size: 18, color: NaqlColors.textMuted),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(NaqlSpace.s3),
        decoration: BoxDecoration(color: NaqlColors.warningSoft, borderRadius: BorderRadius.circular(NaqlRadius.md)),
        child: Row(children: [
          Icon(icon, color: NaqlColors.warning, size: 18),
          const SizedBox(width: NaqlSpace.s2),
          Expanded(child: Text(text, style: NaqlText.label.copyWith(color: NaqlColors.warning, fontWeight: FontWeight.w500))),
        ]),
      );
}

/// The map behind Home: where the student is (or their gathering point), the campus, and the
/// bus or taxi while one is coming. Stylised blocks show until tiles load (and offline).
class _HomeMap extends ConsumerWidget {
  const _HomeMap({required this.controller, required this.overlap});
  final MapController controller;
  final double overlap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final tiles = ref.watch(mapTilesProvider);
    final me = ref.watch(homeLocationProvider).value;
    final point = ref.watch(pointLocationProvider).value;
    final campus = ref.watch(homeTaxiQuoteProvider).value?.campus;
    final ride = currentRide(ref.watch(ridesProvider).value ?? const []);
    final trackable = ride?.assignment?.trackable ?? false;
    final busAt = trackable ? ref.watch(trackProvider(ride!.id)).value?.bus : null;
    final bus = busAt == null ? null : LatLng(busAt.lat, busAt.lng);
    final taxiOn = ref.watch(taxiEnabledProvider).value ?? false;
    final taxi = taxiOn ? ref.watch(taxiMineProvider).value?.active?.taxi : null;
    final origin = me ?? point;
    final pts = [?origin, ?campus];
    final strong = naqlIsDark ? NaqlColors.ink : NaqlColors.primary;
    return Stack(children: [
      const Positioned.fill(child: NaqlMapBackdrop()),
      if (pts.isNotEmpty || bus != null || taxi != null)
        Positioned.fill(
          child: FlutterMap(
            key: ValueKey('home-map-$origin-$campus'),
            mapController: controller,
            options: MapOptions(
              backgroundColor: const Color(0x00000000),
              initialCameraFit: pts.length > 1 ? CameraFit.coordinates(coordinates: pts, padding: EdgeInsets.fromLTRB(64, 150, 64, 110 + overlap), maxZoom: 16) : null,
              initialCenter: pts.firstOrNull ?? bus ?? taxi!,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            ),
            children: [
              if (tiles) NaqlMapTint(child: TileLayer(urlTemplate: mapTilesUrl, userAgentPackageName: 'iq.edu.uowa.naql.student')),
              if (origin != null && campus != null)
                PolylineLayer(polylines: [
                  Polyline(points: [origin, campus], strokeWidth: 4, color: NaqlColors.primary, pattern: const StrokePattern.dotted(spacingFactor: 2.5)),
                ]),
              MarkerLayer(markers: [
                if (origin != null)
                  Marker(
                    point: origin,
                    width: 22,
                    height: 22,
                    child: Semantics(
                      label: me != null ? t.taxiChipHere : t.yourPoint,
                      child: Container(
                        decoration: BoxDecoration(color: strong, shape: BoxShape.circle, boxShadow: naqlFloatShadow),
                        alignment: Alignment.center,
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: NaqlColors.bg, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                if (campus != null)
                  Marker(
                    point: campus,
                    width: 46,
                    height: 46,
                    child: Semantics(
                      label: t.rideCampus,
                      child: Container(
                        decoration: BoxDecoration(color: NaqlColors.accent.withValues(alpha: 0.22), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Container(width: 20, height: 20, decoration: BoxDecoration(color: NaqlColors.accent, shape: BoxShape.circle)),
                      ),
                    ),
                  ),
                if (bus != null) Marker(point: bus, width: 24, height: 38, child: _Vehicle(label: t.busLabel, color: naqlIsDark ? NaqlColors.ink : NaqlColors.primary)),
                if (taxi != null) Marker(point: taxi, width: 24, height: 38, child: _Vehicle(label: t.taxiCarPin, color: NaqlColors.accent)),
              ]),
              if (tiles) TaxiAttribution(text: mapAttribution, bottom: overlap + 56),
            ],
          ),
        ),
    ]);
  }
}

/// A vehicle seen from above, as on the mockups' maps.
class _Vehicle extends StatelessWidget {
  const _Vehicle({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Container(
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(7), boxShadow: naqlFloatShadow),
          padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
          alignment: Alignment.topCenter,
          child: Container(height: 8, decoration: BoxDecoration(color: naqlIsDark ? NaqlColors.border : NaqlColors.surface, borderRadius: BorderRadius.circular(2))),
        ),
      );
}

/// TO-11: office announcements on top of the sheet until the student dismisses them.
class _Announcements extends ConsumerWidget {
  const _Announcements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final list = ref.watch(announcementsProvider).value ?? const [];
    return AnimatedSize(
      duration: naqlMotion(context, NaqlMotion.sheet),
      curve: naqlEaseOut,
      child: Column(children: [
        for (final a in list)
          Padding(
            key: ValueKey('announcement-${a.id}'),
            padding: const EdgeInsets.only(bottom: NaqlSpace.s3),
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(NaqlSpace.s3, NaqlSpace.s3, NaqlSpace.s1, NaqlSpace.s3),
              decoration: BoxDecoration(
                color: NaqlColors.accentSoft,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: NaqlColors.accent.withValues(alpha: 0.5)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const NaqlIconTile(LucideIcons.megaphone, accent: true, size: 36),
                const SizedBox(width: NaqlSpace.s3),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: NaqlText.label.copyWith(fontWeight: FontWeight.w600)),
                    Text(a.body, style: NaqlText.label.copyWith(fontWeight: FontWeight.w400)),
                  ]),
                ),
                NaqlIconButton(
                  icon: LucideIcons.x,
                  semanticLabel: t.dismiss,
                  style: NaqlIconButtonStyle.soft,
                  onPressed: () async {
                    await ref.read(apiProvider).markNotificationsRead([a.id]).catchError((_) {});
                    ref.invalidate(announcementsProvider);
                  },
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
