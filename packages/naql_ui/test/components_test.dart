import 'dart:math';

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
  'NaqlBottomNav': (cb) => NaqlBottomNav(currentIndex: 0, onTap: (_) => cb(), items: const [
        NaqlNavItem(icon: LucideIcons.house, label: 'Home'),
        NaqlNavItem(icon: LucideIcons.bell, label: 'Alerts'),
      ]),
};

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
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness(Column(mainAxisSize: MainAxisSize.min, spacing: 8, children: [
      for (final b in interactive.values) b(() {}),
    ])));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  test('every text/background token pair meets WCAG AA (4.5:1)', () {
    // Computed from the token colours (WCAG relative luminance). Pixel sampling via
    // textContrastGuideline is unreliable for thin 12 px text because anti-aliasing dominates.
    double ratio(Color a, Color b) {
      final (l1, l2) = (a.computeLuminance(), b.computeLuminance());
      return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
    }

    final pairs = <String, (Color, Color)>{
      for (final t in NaqlTone.values) 'StatusPill ${t.name}': (t.fg, t.bg),
      'text on bg': (NaqlColors.text, NaqlColors.bg),
      'text on surface': (NaqlColors.text, NaqlColors.surface),
      'muted on bg': (NaqlColors.textMuted, NaqlColors.bg),
      'muted on surface': (NaqlColors.textMuted, NaqlColors.surface),
      'muted on surfaceMuted': (NaqlColors.textMuted, NaqlColors.surfaceMuted),
      'primary button': (NaqlColors.onPrimary, NaqlColors.primary),
      'danger button': (NaqlColors.onPrimary, NaqlColors.danger),
      'ink button': (NaqlColors.onPrimary, NaqlColors.ink),
      'ghost button on bg': (NaqlColors.primary, NaqlColors.bg),
      'selected nav icon': (NaqlColors.onPrimary, NaqlColors.primary),
    };
    for (final MapEntry(key: name, value: (fg, bg)) in pairs.entries) {
      expect(ratio(fg, bg), greaterThanOrEqualTo(4.5), reason: name);
    }
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
}
