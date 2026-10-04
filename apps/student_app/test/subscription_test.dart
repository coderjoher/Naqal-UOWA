import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';
import 'package:student_app/l10n/gen/app_localizations.dart';
import 'package:student_app/screens/subscription_card.dart';

import 'fakes.dart';

Widget _card(SubscriptionInfo info, {String lang = 'ar'}) => MaterialApp(
      theme: buildNaqlTheme(),
      locale: Locale(lang),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: SubscriptionCard(info: info, lang: lang))),
    );

void main() {
  testWidgets('[T3-07] subscription card renders active, expiring-soon, expired and none states', (tester) async {
    await tester.pumpWidget(_card(SubscriptionInfo.fromJson(FakeBackend.active())));
    await tester.pumpAndSettle();
    expect(find.text('اشتراك فعّال'), findsOneWidget);
    expect(find.text('حتى 31 تشرين الأول'), findsOneWidget);
    expect(find.text('الفئة B'), findsOneWidget);
    expect(find.text('60,000 د.ع'), findsOneWidget);
    expect(find.textContaining('ادفع نقداً'), findsNothing); // no payment hint when active

    await tester.pumpWidget(_card(SubscriptionInfo.fromJson(FakeBackend.active(daysLeft: 2, status: 'expiring'))));
    await tester.pumpAndSettle();
    expect(find.text('ينتهي خلال 2 أيام'), findsOneWidget);
    expect(find.text('جدّد اشتراكك في مكتب النقل قبل انتهائه.'), findsOneWidget);

    await tester.pumpWidget(_card(SubscriptionInfo.fromJson({...FakeBackend.noSubscription, 'status': 'expired'})));
    await tester.pumpAndSettle();
    expect(find.text('الاشتراك منتهي'), findsOneWidget);
    expect(find.text('ادفع نقداً في مكتب النقل وسيُفعّل اشتراكك فوراً.'), findsOneWidget);

    await tester.pumpWidget(_card(SubscriptionInfo.fromJson(FakeBackend.noSubscription), lang: 'en'));
    await tester.pumpAndSettle();
    expect(find.text('No subscription'), findsOneWidget);
    expect(find.text('Tier B'), findsOneWidget);
    expect(find.text('60,000 IQD'), findsOneWidget);
    expect(find.text('مكتب النقل — البناية ب، الطابق الأرضي'), findsOneWidget); // where to pay
  });

  testWidgets('[T3-08] the app shows the subscription as active within 5 s of the office recording the payment', (tester) async {
    usePhone(tester);
    final api = FakeBackend(signedIn: true, withPoint: true);
    await tester.pumpWidget(await api.app());
    await tester.pumpAndSettle();
    expect(find.text('لا يوجد اشتراك'), findsOneWidget);

    // The office records the payment (server state changes); no user action in the app.
    api.subscription = FakeBackend.active();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('اشتراك فعّال'), findsOneWidget);
    expect(find.text('لا يوجد اشتراك'), findsNothing);
  });
}
