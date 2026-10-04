import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naql_ui/naql_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('[T0-03] NaqlButton variants, sizes and states', (tester) async {
    await expectGoldens(tester, 'button', (d) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, spacing: NaqlSpace.s3, children: [
        NaqlButton(label: tr(d, 'Request ride', 'اطلب رحلة'), onPressed: () {}, icon: LucideIcons.busFront),
        NaqlButton(label: tr(d, 'Cancel', 'إلغاء'), onPressed: () {}, variant: NaqlButtonVariant.secondary),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          NaqlButton(label: tr(d, 'Details', 'التفاصيل'), onPressed: () {}, variant: NaqlButtonVariant.ghost),
          NaqlButton(label: tr(d, 'Delete', 'حذف'), onPressed: () {}, variant: NaqlButtonVariant.danger),
          NaqlButton(label: tr(d, 'Disabled', 'معطّل'), onPressed: null),
        ]),
        NaqlButton(label: tr(d, 'Start run', 'ابدأ الرحلة'), onPressed: () {}, size: NaqlButtonSize.large, expand: true),
      ]);
    }, size: const Size(420, 340));
  });

  testWidgets('[T0-03] NaqlCard top-level and nested', (tester) async {
    await expectGoldens(tester, 'card', (d) {
      return NaqlCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(tr(d, 'Subscription', 'الاشتراك'), style: NaqlText.headline),
          const SizedBox(height: NaqlSpace.s3),
          NaqlCard(nested: true, child: Text(tr(d, 'Tier B · expires 31 Oct', 'الفئة ب · ينتهي ٣١ تشرين الأول'), style: NaqlText.body)),
        ]),
      );
    }, size: const Size(420, 220));
  });

  testWidgets('[T0-03] NaqlField default and error', (tester) async {
    await expectGoldens(tester, 'field', (d) {
      return Column(mainAxisSize: MainAxisSize.min, spacing: NaqlSpace.s4, children: [
        NaqlField(label: tr(d, 'Phone', 'رقم الهاتف'), hint: '07XX XXX XXXX', textDirection: TextDirection.ltr, prefixIcon: LucideIcons.phone),
        NaqlField(label: tr(d, 'Student ID', 'الرقم الجامعي'), error: tr(d, 'Not found in university records', 'غير موجود في سجلات الجامعة')),
      ]);
    }, size: const Size(420, 300));
  });

  testWidgets('[T0-03] NaqlChip wave selector', (tester) async {
    await expectGoldens(tester, 'chip', (d) {
      return Wrap(spacing: NaqlSpace.s2, runSpacing: NaqlSpace.s2, children: [
        NaqlChip(label: tr(d, 'Arrive 8:00', 'الوصول ٨:٠٠'), selected: true, onSelected: () {}),
        NaqlChip(label: tr(d, 'Arrive 10:00', 'الوصول ١٠:٠٠'), selected: false, onSelected: () {}),
        NaqlChip(label: tr(d, 'Return 2:00', 'العودة ٢:٠٠'), selected: false, onSelected: () {}),
      ]);
    }, size: const Size(420, 200));
  });

  testWidgets('[T0-03] StatusPill tones', (tester) async {
    await expectGoldens(tester, 'status_pill', (d) {
      return Wrap(spacing: NaqlSpace.s2, runSpacing: NaqlSpace.s2, children: [
        StatusPill(label: tr(d, 'Assigned', 'تم التعيين'), tone: NaqlTone.success),
        StatusPill(label: tr(d, 'Waitlisted', 'قائمة الانتظار'), tone: NaqlTone.warning),
        StatusPill(label: tr(d, 'Cancelled', 'ملغاة'), tone: NaqlTone.danger),
        StatusPill(label: tr(d, 'On the way', 'في الطريق'), tone: NaqlTone.primary),
        StatusPill(label: tr(d, 'Female only', 'للطالبات'), tone: NaqlTone.femaleOnly, icon: LucideIcons.users),
        StatusPill(label: tr(d, 'No subscription', 'لا يوجد اشتراك')),
      ]);
    }, size: const Size(420, 200));
  });

  testWidgets('[T0-03] TripCard', (tester) async {
    await expectGoldens(tester, 'trip_card', (d) {
      return TripCard(
        departTime: '07:20',
        arriveTime: '07:55',
        from: tr(d, 'Al-Abbas Square', 'ساحة العباس'),
        to: tr(d, 'Campus', 'الحرم الجامعي'),
        duration: '35 min',
        driverName: tr(d, 'Ali Hassan', 'علي حسن'),
        busLabel: tr(d, 'Bus 12', 'باص ١٢'),
        plate: '45 K 12345',
        status: tr(d, 'Assigned', 'تم التعيين'),
        statusTone: NaqlTone.success,
        femaleOnly: true,
        femaleOnlyLabel: tr(d, 'Female only', 'للطالبات'),
      );
    }, size: const Size(420, 260));
  });

  testWidgets('[T0-03] NaqlTopBar and NaqlIconButton', (tester) async {
    await expectGoldens(tester, 'top_bar', (d) {
      return NaqlTopBar(
        title: tr(d, 'Karbala → Campus', 'كربلاء ← الجامعة'),
        subtitle: tr(d, 'Thu 9 Oct', 'الخميس ٩ تشرين الأول'),
        onBack: () {},
        trailing: NaqlIconButton(icon: LucideIcons.bell, onPressed: () {}, semanticLabel: 'alerts', badge: true),
      );
    }, size: const Size(420, 160));
  });

  testWidgets('[T0-03] NaqlBottomNav floating pill', (tester) async {
    await expectGoldens(tester, 'bottom_nav', (d) {
      return NaqlBottomNav(currentIndex: 0, onTap: (_) {}, items: const [
        NaqlNavItem(icon: LucideIcons.house, label: 'Home'),
        NaqlNavItem(icon: LucideIcons.ticket, label: 'Trips'),
        NaqlNavItem(icon: LucideIcons.bell, label: 'Alerts'),
        NaqlNavItem(icon: LucideIcons.circleUser, label: 'Account'),
      ]);
    }, size: const Size(420, 160));
  });

  testWidgets('[T0-03] NaqlEmptyState and NaqlSkeleton', (tester) async {
    await expectGoldens(tester, 'feedback', (d) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        NaqlEmptyState(
          icon: LucideIcons.busFront,
          title: tr(d, 'No ride today', 'لا توجد رحلة اليوم'),
          message: tr(d, 'Request a seat on a morning wave.', 'اطلب مقعداً في إحدى رحلات الصباح.'),
          action: NaqlButton(label: tr(d, 'Request ride', 'اطلب رحلة'), onPressed: () {}),
        ),
        const SizedBox(height: NaqlSpace.s6),
        const NaqlSkeleton(height: 20),
        const SizedBox(height: NaqlSpace.s2),
        const NaqlSkeleton(width: 200, height: 20),
      ]);
    }, size: const Size(420, 420));
  });
}
