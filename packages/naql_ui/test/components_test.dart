import 'dart:math';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'helpers.dart';

/// Every interactive component, for behaviour checks.
Map<String, Widget Function(VoidCallback)> interactive = {
  'NaqlButton': (cb) => NaqlButton(label: 'Go', onPressed: cb),
  'NaqlButton.large': (cb) => NaqlButton(label: 'Start', onPressed: cb, size: NaqlButtonSize.large),
  'NaqlCard.onTap': (cb) => NaqlCard(onTap: cb, child: const Text('Card')),
  'NaqlChip': (cb) => NaqlChip(label: 'Wave', selected: false, onSelected: cb),
  'NaqlIconButton': (cb) => NaqlIconButton(icon: LucideIcons.bell, onPressed: cb, semanticLabel: 'bell'),
  'NaqlButton.accent': (cb) => NaqlButton(label: 'Online', onPressed: cb, variant: NaqlButtonVariant.accent),
  'NaqlChip.icon': (cb) => NaqlChip(label: 'Home', icon: LucideIcons.house, selected: false, onSelected: cb),
  'NaqlIconButton.floating': (cb) => NaqlIconButton.floating(icon: LucideIcons.locateFixed, onPressed: cb, semanticLabel: 'locate'),
  'NaqlOptionCard': (cb) => NaqlOptionCard(title: 'Taxi', subtitle: '4 seats', badge: '3,000', selected: true, onTap: cb),
  'NaqlLocationPill.onTap': (cb) => NaqlLocationPill(label: 'Campus', caption: 'Pickup', onTap: cb),
  'NaqlBottomNav': (cb) => NaqlBottomNav(currentIndex: 0, onTap: (_) => cb(), items: const [
        NaqlNavItem(icon: LucideIcons.house, label: 'Home'),
        NaqlNavItem(icon: LucideIcons.bell, label: 'Alerts'),
      ]),
};

/// Room for every interactive component in one column.
void tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('[T0-04] theme disables Material ink and elevation tint', () {
    final theme = buildNaqlTheme();
    expect(theme.splashFactory, NoSplash.splashFactory);
    expect(theme.highlightColor, Colors.transparent);
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.scaffoldBackgroundColor, NaqlColors.bg);
  });

  for (final entry in interactive.entries) {
    testWidgets('[T0-04] ${entry.key} renders no ink splash or elevation shadow when pressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(harness(entry.value(() => taps++)));
      final subject = find.byType(Scaffold);

      final gesture = await tester.startGesture(tester.getCenter(find.byType(NaqlPressable).first));
      await tester.pump(const Duration(milliseconds: 100));
      // While pressed: no ink machinery anywhere inside the component.
      for (final type in [InkWell, InkResponse, Ink]) {
        expect(find.descendant(of: subject, matching: find.byType(type)), findsNothing, reason: '$type found in ${entry.key}');
      }
      final elevated = find.descendant(
        of: find.byType(Center),
        matching: find.byWidgetPredicate((w) => (w is Material && w.elevation > 0) || w is PhysicalModel),
      );
      expect(elevated, findsNothing, reason: 'Material elevation in ${entry.key}');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  }

  testWidgets('pressables are keyboard operable (Tab + Enter/Space)', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(NaqlButton(label: 'Go', onPressed: () => taps++)));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(taps, 2);
  });

  testWidgets('disabled and loading buttons do not fire', (tester) async {
    var taps = 0;
    await tester.pumpWidget(harness(Column(mainAxisSize: MainAxisSize.min, children: [
      const NaqlButton(label: 'Off', onPressed: null),
      NaqlButton(label: 'Busy', onPressed: () => taps++, loading: true),
    ])));
    await tester.tap(find.byType(NaqlButton).first, warnIfMissed: false);
    await tester.tap(find.byType(NaqlButton).last, warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('touch targets: 48 dp everywhere, 56 dp for driver-size buttons', (tester) async {
    tallView(tester);
    await tester.pumpWidget(harness(Column(mainAxisSize: MainAxisSize.min, children: [
      for (final b in interactive.values) b(() {}),
    ])));
    for (final e in find.byType(NaqlPressable).evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.width >= 48 && size.height >= 48, isTrue, reason: '${e.widget} is $size');
    }
    await tester.pumpWidget(harness(NaqlButton(label: 'Start', onPressed: () {}, size: NaqlButtonSize.large)));
    expect(tester.getSize(find.byType(NaqlPressable)).height, greaterThanOrEqualTo(56));
  });

  testWidgets('meets Flutter accessibility guidelines (tap targets, labels, contrast)', (tester) async {
    tallView(tester);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(Column(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
      for (final b in interactive.values) b(() {}),
    ])));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  test('every text/background token pair meets WCAG AA (4.5:1) in light and dark', () {
    // Computed from the token colours (WCAG relative luminance). Pixel sampling via
    // textContrastGuideline is unreliable for thin 12 px text because anti-aliasing dominates.
    double ratio(Color a, Color b) {
      final (l1, l2) = (a.computeLuminance(), b.computeLuminance());
      return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
    }

    for (final palette in [NaqlPalette.light, NaqlPalette.dark]) {
      NaqlColors.current = palette;
      final mode = identical(palette, NaqlPalette.dark) ? 'dark' : 'light';
      final pairs = <String, (Color, Color)>{
        for (final t in NaqlTone.values) 'StatusPill ${t.name}': (t.fg, t.bg),
        'text on bg': (NaqlColors.text, NaqlColors.bg),
        'text on surface': (NaqlColors.text, NaqlColors.surface),
        'muted on bg': (NaqlColors.textMuted, NaqlColors.bg),
        'muted on surface': (NaqlColors.textMuted, NaqlColors.surface),
        'muted on surfaceMuted': (NaqlColors.textMuted, NaqlColors.surfaceMuted),
        'primary button': (NaqlColors.onPrimary, NaqlColors.primary),
        'danger button': (NaqlColors.onPrimary, NaqlColors.danger),
        'ink button': (NaqlColors.onInk, NaqlColors.ink),
        'accent button': (NaqlColors.onAccent, NaqlColors.accent),
        'ghost button on bg': (NaqlColors.primary, NaqlColors.bg),
        'selected nav icon': (NaqlColors.onPrimary, NaqlColors.primary),
        'text on primarySoft (selected option)': (NaqlColors.text, NaqlColors.primarySoft),
        'text on accentSoft (selected gold option)': (NaqlColors.text, NaqlColors.accentSoft),
        'live pill': (NaqlColors.danger, NaqlColors.dangerSoft),
      };
      for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
        expect(ratio(fg, bg), greaterThanOrEqualTo(4.5), reason: '$name ($mode)');
      }
    }
    NaqlColors.current = NaqlPalette.light;
    // The plate is fixed dark-on-white in both modes.
    expect(ratio(const Color(0xFF0A1428), const Color(0xFFFFFFFF)), greaterThanOrEqualTo(4.5));
  });

  testWidgets('chip exposes selected state and nav exposes labels to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(Column(mainAxisSize: MainAxisSize.min, children: [
      NaqlChip(label: 'Arrive 8:00', selected: true, onSelected: () {}),
      interactive['NaqlBottomNav']!(() {}),
    ])));
    expect(tester.getSemantics(find.text('Arrive 8:00')), isNotNull);
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(find.bySemanticsLabel('Alerts'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('top bar back chevron mirrors in RTL', (tester) async {
    for (final (dir, icon) in [(TextDirection.ltr, LucideIcons.chevronLeft), (TextDirection.rtl, LucideIcons.chevronRight)]) {
      await tester.pumpWidget(harness(NaqlTopBar(title: 't', onBack: () {}), dir: dir));
      expect(find.byIcon(icon), findsOneWidget);
    }
  });

  testWidgets('[T9-01] NaqlOtpField stays reachable by screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(harness(NaqlOtpField(label: 'Code', onCompleted: (_) {})));
    await tester.pump();
    // The visible caption and the (invisible) text field both carry the label; the field must be there.
    final nodes = find.bySemanticsLabel('Code').evaluate().map((e) => tester.getSemantics(find.byWidget(e.widget)));
    expect(nodes.where((n) => n.flagsCollection.isTextField), isNotEmpty);
    semantics.dispose();
  });

  testWidgets('[T0-04] theme scope follows the platform brightness and repaints const widgets', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpWidget(NaqlThemeScope(
      child: MaterialApp(theme: buildNaqlTheme(), darkTheme: buildNaqlTheme(NaqlPalette.dark), home: const _Swatch()),
    ));
    expect(NaqlColors.current, same(NaqlPalette.light));
    expect(tester.widget<ColoredBox>(find.byKey(const ValueKey('swatch'))).color, NaqlPalette.light.surface);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pump();
    expect(NaqlColors.current, same(NaqlPalette.dark));
    // A const widget that reads NaqlColors in build was rebuilt with the dark palette.
    expect(tester.widget<ColoredBox>(find.byKey(const ValueKey('swatch'))).color, NaqlPalette.dark.surface);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(_Swatch))).brightness, Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pump();
    expect(tester.widget<ColoredBox>(find.byKey(const ValueKey('swatch'))).color, NaqlPalette.light.surface);
  });

  testWidgets('theme builders: light and dark schemes come from the palettes', (tester) async {
    final light = buildNaqlTheme();
    final dark = buildNaqlTheme(NaqlPalette.dark);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.scaffoldBackgroundColor, NaqlPalette.light.bg);
    expect(dark.scaffoldBackgroundColor, NaqlPalette.dark.bg);
    expect(dark.colorScheme.surfaceTint, Colors.transparent);
    expect(dark.splashFactory, NoSplash.splashFactory);
  });

  testWidgets('primary CTA is the blue pill in light mode and the ink pill in dark mode, 56 dp when full width', (tester) async {
    Color fill() => ((tester.widget<Container>(find.descendant(of: find.byType(NaqlButton), matching: find.byType(Container)).first).decoration!) as BoxDecoration).color!;
    await tester.pumpWidget(harness(NaqlButton(label: 'Continue', onPressed: () {}, expand: true)));
    expect(fill(), NaqlPalette.light.primary);
    expect(tester.getSize(find.byType(NaqlPressable)).height, greaterThanOrEqualTo(56));
    await tester.pumpWidget(harness(NaqlButton(label: 'Continue', onPressed: () {}, expand: true), brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(fill(), NaqlPalette.dark.ink);
    await tester.pumpWidget(harness(NaqlButton(label: 'Online', onPressed: () {}, variant: NaqlButtonVariant.accent)));
    await tester.pumpAndSettle();
    expect(fill(), NaqlPalette.light.accent);
  });

  testWidgets('option card exposes its selected state and full label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(NaqlOptionCard(title: 'Taxi', subtitle: '4 seats', badge: '3,000 IQD', selected: true, onTap: () {})));
    expect(find.bySemanticsLabel('Taxi, 4 seats, 3,000 IQD'), findsOneWidget);
    expect(tester.getSemantics(find.byType(NaqlOptionCard)).flagsCollection.isSelected, Tristate.isTrue);
    handle.dispose();
  });

  testWidgets('live pill pulses, then rests; no pulse with reduced motion', (tester) async {
    await tester.pumpWidget(harness(const NaqlLivePill(label: '17 min')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('17 min'), findsOneWidget);

    await tester.pumpWidget(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: harness(const NaqlLivePill(label: '16 min'))));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('plate badge and timeline times stay left-to-right in RTL', (tester) async {
    await tester.pumpWidget(harness(
      const Column(mainAxisSize: MainAxisSize.min, children: [
        NaqlPlateBadge('12345 ب كربلاء'),
        NaqlTripTimeline(stops: [NaqlTimelineStop(title: 'A', subtitle: 'Pickup', time: '7:20'), NaqlTimelineStop(title: 'B', subtitle: 'Drop-off', time: '7:55')]),
      ]),
      dir: TextDirection.rtl,
    ));
    expect(tester.widget<Text>(find.text('7:20')).textDirection, TextDirection.ltr);
    // Iraqi layout: the number on top, the province under it; the plate itself stays LTR.
    final plate = find.ancestor(of: find.text('12345'), matching: find.byType(Directionality)).first;
    expect(tester.widget<Directionality>(plate).textDirection, TextDirection.ltr);
    expect(find.text('ب كربلاء'), findsOneWidget);
    expect(find.bySemanticsLabel('12345 ب كربلاء'), findsOneWidget);
    // A plate without a province is shown as written, on one line.
    expect(NaqlPlateBadge.split('45 K 12345'), isNull);
    expect(NaqlPlateBadge.split('12340 كربلاء أجرة'), ('12340', 'كربلاء أجرة'));
  });

  testWidgets('service cards and slot tiles are selectable, labelled and at least 48 dp', (tester) async {
    var picked = 'bus';
    await tester.pumpWidget(harness(StatefulBuilder(
      builder: (_, set) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: NaqlServiceCard(key: const ValueKey('bus'), title: 'Bus', badge: 'Included', subtitle: 'Next 07:30', watermark: 'BUS', art: const NaqlVehicleArt.bus(), selected: picked == 'bus', onTap: () => set(() => picked = 'bus'))),
          const SizedBox(width: 12),
          Expanded(child: NaqlServiceCard(key: const ValueKey('taxi'), title: 'Taxi', badge: '4 min', badgeStyle: NaqlBadgeStyle.success, art: const NaqlVehicleArt.taxi(), selected: picked == 'taxi', onTap: () => set(() => picked = 'taxi'))),
        ]),
        SizedBox(width: 120, child: NaqlSlotTile(key: const ValueKey('slot'), time: '06:45', caption: 'Full', state: NaqlSlotState.full, onTap: () {})),
      ]),
    )));
    expect(find.bySemanticsLabel('Bus, Included, Next 07:30'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('taxi')));
    await tester.pumpAndSettle();
    expect(picked, 'taxi');
    expect(tester.getSemantics(find.bySemanticsLabel('Taxi, 4 min')), isSemantics(isSelected: true));
    expect(tester.getSize(find.byKey(const ValueKey('slot'))).height, greaterThanOrEqualTo(NaqlTouch.min));
  });

  testWidgets('toggle card is a switch; tab bar items are 56 dp and labelled; countdown ring reads its seconds', (tester) async {
    var on = false;
    var tab = 0;
    await tester.pumpWidget(harness(StatefulBuilder(
      builder: (_, set) => Column(mainAxisSize: MainAxisSize.min, children: [
        NaqlToggleCard(key: const ValueKey('toggle'), on: on, title: on ? 'Online' : 'Offline', subtitle: 'tap', cta: 'Go online', onTap: () => set(() => on = !on)),
        const NaqlCountdownRing(seconds: 42, fraction: 0.7, semanticLabel: '42 seconds left'),
        NaqlTabBar(currentIndex: tab, onTap: (i) => set(() => tab = i), items: const [NaqlTabItem(icon: LucideIcons.house, label: 'Home'), NaqlTabItem(icon: LucideIcons.wallet, label: 'Earnings')]),
      ]),
    )));
    expect(find.text('Go online'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Go online'), findsNothing);
    expect(find.bySemanticsLabel('42 seconds left'), findsOneWidget);
    expect(tester.getSize(find.bySemanticsLabel('Earnings')).height, greaterThanOrEqualTo(NaqlTouch.driver));
    await tester.tap(find.bySemanticsLabel('Earnings'));
    await tester.pumpAndSettle();
    expect(tab, 1);
  });

  testWidgets('new components settle instantly when the platform asks for reduced motion', (tester) async {
    var selected = false;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: harness(StatefulBuilder(
        builder: (_, set) => NaqlServiceCard(title: 'Bus', art: const NaqlVehicleArt.bus(), selected: selected, onTap: () => set(() => selected = true)),
      )),
    ));
    await tester.tap(find.text('Bus'));
    await tester.pump();
    // No frames left to animate: the selection shows at once.
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

class _Swatch extends StatelessWidget {
  const _Swatch();

  @override
  Widget build(BuildContext context) => ColoredBox(key: const ValueKey('swatch'), color: NaqlColors.surface, child: const SizedBox.expand());
}
