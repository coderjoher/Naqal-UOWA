import 'package:flutter/material.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../l10n/gen/app_localizations.dart';

/// ST-03: status, tier, price, expiry and how to pay.
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({super.key, required this.info, required this.lang});
  final SubscriptionInfo info;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final (label, tone, icon) = switch (info.status) {
      SubscriptionStatus.active => (t.subActive, NaqlTone.success, LucideIcons.circleCheck),
      SubscriptionStatus.expiring => (t.subExpiring(info.daysLeft), NaqlTone.warning, LucideIcons.clock),
      SubscriptionStatus.expired => (t.subExpired, NaqlTone.danger, LucideIcons.circleAlert),
      SubscriptionStatus.none => (t.subNone, NaqlTone.neutral, LucideIcons.creditCard),
    };
    final price = info.current?.price ?? info.price;
    final active = info.isActive;
    return NaqlCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: NaqlMotion.fast,
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
            child: Icon(LucideIcons.ticket, color: tone.fg, size: 22),
          ),
          const SizedBox(width: NaqlSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.subMonthly, style: NaqlText.caption)),
                AnimatedSwitcher(duration: NaqlMotion.fast, child: StatusPill(key: ValueKey(info.status), label: label, tone: tone, icon: icon)),
              ]),
              const SizedBox(height: NaqlSpace.s1),
              Text(
                active && info.current != null ? t.subUntil(formatDayMonth(info.current!.end, lang)) : t.subUnlimited,
                style: active ? NaqlText.headline : NaqlText.label,
              ),
            ]),
          ),
        ]),
        if (info.tierName != null && price != null) ...[
          const SizedBox(height: NaqlSpace.s3),
          Row(children: [
            NaqlLetterBadge(info.tierName!, active: active),
            const SizedBox(width: NaqlSpace.s2),
            Expanded(child: Text(t.subTier(info.tierName!), style: NaqlText.body)),
            Text(formatIqd(price, lang), style: NaqlText.headline, textDirection: TextDirection.ltr),
          ]),
        ],
        if (info.upcoming != null) ...[
          const SizedBox(height: NaqlSpace.s1),
          Text(t.subNext(formatMonth(info.upcoming!.month, lang)), style: NaqlText.caption.copyWith(color: NaqlColors.success)),
        ],
        if (info.status != SubscriptionStatus.active) ...[
          const SizedBox(height: NaqlSpace.s3),
          Container(
            padding: const EdgeInsets.all(NaqlSpace.s3),
            decoration: BoxDecoration(color: NaqlColors.surfaceMuted, borderRadius: BorderRadius.circular(NaqlRadius.md)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(LucideIcons.building2, size: 18, color: NaqlColors.textMuted),
              const SizedBox(width: NaqlSpace.s2),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(info.status == SubscriptionStatus.expiring ? t.subRenew : t.subPayAtOffice, style: NaqlText.caption.copyWith(color: NaqlColors.text)),
                  if (info.officeNote != null) Text(info.officeNote!, style: NaqlText.caption),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
