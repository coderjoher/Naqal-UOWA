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
        NaqlButton(label: tr(d, 'Go online', 'ابدأ العمل'), onPressed: () {}, variant: NaqlButtonVariant.accent, icon: LucideIcons.power),
      ]);
    }, size: const Size(420, 420), dark: true);
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
    }, size: const Size(420, 220), dark: true);
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

  testWidgets('[T0-03] NaqlOtpField, NaqlListRow and NaqlInfoRow', (tester) async {
    await expectGoldens(tester, 'rows', (d) {
      return Column(mainAxisSize: MainAxisSize.min, spacing: NaqlSpace.s3, children: [
        NaqlOtpField(label: tr(d, 'Code from SMS', 'رمز الرسالة'), onCompleted: (_) {}, controller: TextEditingController(text: '482')),
        NaqlListRow(title: tr(d, 'Al-Abbas Square', 'ساحة العباس'), subtitle: tr(d, 'Tier B · 4.8 km', 'الفئة ب · ٤٫٨ كم'), leading: const NaqlLetterBadge('B'), selected: true, onTap: () {}),
        NaqlListRow(title: tr(d, 'Bab Baghdad', 'باب بغداد'), subtitle: tr(d, 'Tier A · 2.7 km', 'الفئة أ · ٢٫٧ كم'), leading: const NaqlLetterBadge('A', active: false), onTap: () {}),
        NaqlInfoRow(label: tr(d, 'Gender', 'الجنس'), value: tr(d, 'Female', 'أنثى'), locked: true),
      ]);
    }, size: const Size(420, 420));
  });

  testWidgets('[T0-03] NaqlOptionCard, NaqlBadge and quick chips', (tester) async {
    await expectGoldens(tester, 'option_card', (d) {
      return Column(mainAxisSize: MainAxisSize.min, spacing: NaqlSpace.s3, children: [
        NaqlOptionCard(icon: LucideIcons.carTaxiFront, title: tr(d, 'Taxi', 'تكسي'), subtitle: tr(d, 'Up to 4 · 6 min away', 'حتى ٤ ركاب · بعد ٦ دقائق'), badge: '3,000', selected: true, onTap: () {}),
        NaqlOptionCard(icon: LucideIcons.busFront, title: tr(d, 'Campus bus', 'باص الجامعة'), subtitle: tr(d, 'Next wave 8:00', 'الرحلة القادمة ٨:٠٠'), badge: tr(d, 'Included', 'مشمول'), selected: false, onTap: () {}),
        NaqlOptionCard(icon: LucideIcons.star, title: tr(d, 'Female only', 'للطالبات فقط'), selected: true, accent: true, onTap: () {}),
        Wrap(spacing: NaqlSpace.s2, runSpacing: NaqlSpace.s2, children: [
          NaqlChip(label: tr(d, 'Home', 'المنزل'), icon: LucideIcons.house, selected: false, onSelected: () {}),
          NaqlChip(label: tr(d, 'Campus', 'الجامعة'), icon: LucideIcons.school, selected: true, onSelected: () {}),
        ]),
      ]);
    }, size: const Size(420, 420), dark: true);
  });

  testWidgets('[T0-03] NaqlPersonCard, NaqlPlateBadge and NaqlLivePill', (tester) async {
    await expectGoldens(tester, 'person_card', (d) {
      return NaqlCard(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, spacing: NaqlSpace.s4, children: [
          Row(children: [
            Expanded(child: Text(tr(d, 'Arriving', 'في الطريق إليك'), style: NaqlText.title)),
            NaqlLivePill(label: tr(d, '17 min', '١٧ د')),
          ]),
          NaqlPersonCard(
            name: tr(d, 'Ali Hassan', 'علي حسن'),
            caption: tr(d, 'Your driver', 'سائقك'),
            rating: '4.9',
            below: const NaqlPlateBadge('12345 ب كربلاء'),
            actions: [
              NaqlPersonAction(icon: LucideIcons.messageCircle, label: tr(d, 'Message', 'رسالة'), onPressed: () {}),
              NaqlPersonAction(icon: LucideIcons.phone, label: tr(d, 'Call', 'اتصال'), onPressed: () {}, primary: true),
            ],
          ),
        ]),
      );
    }, size: const Size(420, 260), dark: true);
  });

  testWidgets('[T0-03] NaqlTripTimeline and NaqlSummaryRow', (tester) async {
    await expectGoldens(tester, 'timeline', (d) {
      return NaqlCard(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          NaqlTripTimeline(stops: [
            NaqlTimelineStop(subtitle: tr(d, 'Pickup', 'الانطلاق'), title: tr(d, 'Al-Abbas Square', 'ساحة العباس'), time: '7:20'),
            NaqlTimelineStop(subtitle: tr(d, 'Drop-off', 'الوصول'), title: tr(d, 'Main campus gate', 'بوابة الحرم الرئيسية'), time: '7:55'),
          ]),
          const SizedBox(height: NaqlSpace.s4),
          NaqlSummaryRow(label: tr(d, 'Distance', 'المسافة'), value: '6.2 km'),
          NaqlSummaryRow(label: tr(d, 'Fare', 'الأجرة'), value: '3,000'),
          NaqlSummaryRow(label: tr(d, 'Total', 'المجموع'), value: '3,000 IQD', total: true),
        ]),
      );
    }, size: const Size(420, 400), dark: true);
  });

  testWidgets('[T0-03] floating map overlays', (tester) async {
    await expectGoldens(tester, 'map_overlays', (d) {
      return Container(
        height: 220,
        padding: const EdgeInsets.all(NaqlSpace.s4),
        decoration: BoxDecoration(color: naqlIsDark ? const Color(0xFF20242C) : const Color(0xFFE8EEE4), borderRadius: BorderRadius.circular(NaqlRadius.lg)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            NaqlIconButton.floating(icon: d == TextDirection.rtl ? LucideIcons.arrowRight : LucideIcons.arrowLeft, onPressed: () {}, semanticLabel: 'back'),
            const Spacer(),
            const NaqlLivePill(label: '17 min', floating: true),
          ]),
          const Spacer(),
          Row(children: [
            Flexible(child: NaqlLocationPill(caption: tr(d, 'Pickup', 'الانطلاق'), label: tr(d, 'Al-Abbas Square', 'ساحة العباس'))),
            const Spacer(),
            const NaqlMapMarker(icon: LucideIcons.carTaxiFront, accent: true),
            const SizedBox(width: NaqlSpace.s3),
            NaqlIconButton.floating(icon: LucideIcons.locateFixed, onPressed: () {}, semanticLabel: 'locate'),
          ]),
        ]),
      );
    }, size: const Size(420, 280), dark: true);
  });

  testWidgets('vehicle illustrations, service cards and slot tiles', (tester) async {
    await expectGoldens(tester, 'service_cards', (d) {
      return Column(mainAxisSize: MainAxisSize.min, spacing: NaqlSpace.s3, children: [
        Row(children: [
          Expanded(child: NaqlServiceCard(title: tr(d, 'Campus bus', 'حافلة الجامعة'), badge: tr(d, 'Included', 'مشمول'), subtitle: tr(d, 'Next 07:30', 'القادمة 07:30'), watermark: 'BUS', art: const NaqlVehicleArt.bus(width: 120), selected: true, onTap: () {})),
          const SizedBox(width: NaqlSpace.s3),
          Expanded(child: NaqlServiceCard(title: tr(d, 'Taxi', 'تكسي'), badge: tr(d, '4 min', '4 د'), badgeStyle: NaqlBadgeStyle.success, subtitle: tr(d, 'From 3,000 IQD', 'من 3,000 د.ع'), watermark: 'TAXI', art: const NaqlVehicleArt.taxi(width: 120), selected: false, onTap: () {})),
        ]),
        Row(spacing: 10, children: [
          Expanded(child: NaqlSlotTile(time: '06:45', caption: tr(d, 'Full', 'ممتلئة'), state: NaqlSlotState.full, onTap: () {})),
          Expanded(child: NaqlSlotTile(time: '07:30', caption: tr(d, '6 seats left', '6 مقاعد متاحة'), state: NaqlSlotState.selected, onTap: () {})),
          Expanded(child: NaqlSlotTile(time: '08:15', caption: tr(d, 'Open', 'متاحة'), state: NaqlSlotState.available, onTap: () {})),
        ]),
        const Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [NaqlVehicleArt.bus(hero: true, width: 170), NaqlVehicleArt.taxi(hero: true, width: 170)]),
      ]);
    }, size: const Size(420, 520), dark: true);
  });

  testWidgets('driver pieces: toggle card, figures, offer ring, instruction card, step bar, tab bar', (tester) async {
    await expectGoldens(tester, 'driver_pieces', (d) {
      return Column(mainAxisSize: MainAxisSize.min, spacing: NaqlSpace.s3, children: [
        NaqlInstructionCard(headline: tr(d, '200 m', '200 م'), body: tr(d, 'Head to Al-Abbas Square', 'توجّه إلى ساحة العباس')),
        NaqlToggleCard(on: true, title: tr(d, 'You are online', 'أنت متصل'), subtitle: tr(d, 'Nearby requests reach you', 'تصلك طلبات التكسي القريبة'), watermark: 'ON', onTap: () {}),
        Row(spacing: 10, children: [
          Expanded(child: NaqlKpiTile(label: tr(d, 'Trips today', 'مشاوير اليوم'), value: '7')),
          Expanded(child: NaqlKpiTile(label: tr(d, 'Cash', 'نقداً'), value: '27,500', small: true)),
          Expanded(child: NaqlKpiTile(label: tr(d, 'Rating', 'التقييم'), value: '4.9', star: true)),
        ]),
        Row(children: [
          const NaqlCountdownRing(seconds: 42, fraction: 0.7),
          const SizedBox(width: NaqlSpace.s4),
          const Expanded(child: NaqlStepBar(total: 4, done: 2)),
          const SizedBox(width: NaqlSpace.s4),
          NaqlTag(tr(d, 'Subscriber', 'مشترك'), tone: NaqlTone.success),
        ]),
        NaqlTabBar(currentIndex: 0, onTap: (_) {}, items: [
          NaqlTabItem(icon: LucideIcons.house, label: tr(d, 'Home', 'الرئيسية')),
          NaqlTabItem(icon: LucideIcons.wallet, label: tr(d, 'Earnings', 'الأرباح')),
          NaqlTabItem(icon: LucideIcons.circleUser, label: tr(d, 'Account', 'حسابي')),
        ]),
      ]);
    }, size: const Size(420, 640), dark: true);
  });
}
