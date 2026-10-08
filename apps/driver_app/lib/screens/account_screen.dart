import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/session.dart';
import '../l10n/gen/app_localizations.dart';

/// The driver's account: who they are, the vehicle the office approved, language and sign-out.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final a = ref.watch(applicationProvider).value;
    final lang = ref.watch(localeProvider).languageCode;
    if (a == null) return const SizedBox.shrink();
    String vehicle(String? v) => switch (v) {
          'coaster' => t.coaster,
          'minibus' => t.minibus,
          'bus' => t.bus,
          'van' => t.van,
          'taxi' => t.taxi,
          null => t.accountNotSet,
          _ => v,
        };
    final phone = a.phone?.replaceFirst('+964', '0');

    return Column(children: [
      NaqlTopBar(title: t.tabProfile, trailing: const ServerSettingsButton()),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => ref.read(applicationProvider.notifier).refresh(),
          child: ListView(padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120), children: [
            NaqlEntrance(
              child: NaqlCard(
                child: Row(children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: NaqlColors.primarySoft,
                    child: Text(
                      (a.name?.trim().isNotEmpty ?? false) ? a.name!.trim().characters.first : '؟',
                      style: NaqlText.title.copyWith(color: NaqlColors.primary),
                    ),
                  ),
                  const SizedBox(width: NaqlSpace.s4),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(a.name ?? t.accountNotSet, style: NaqlText.title),
                      const SizedBox(height: NaqlSpace.s1),
                      if (phone != null) Text(phone, style: NaqlText.body.copyWith(color: NaqlColors.textMuted), textDirection: TextDirection.ltr),
                    ]),
                  ),
                  StatusPill(label: t.accountApproved, tone: NaqlTone.success, icon: LucideIcons.badgeCheck),
                ]),
              ),
            ),
            const SizedBox(height: NaqlSpace.s4),
            NaqlEntrance(
              index: 1,
              child: NaqlCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(t.accountVehicle, style: NaqlText.headline),
                  const SizedBox(height: NaqlSpace.s2),
                  NaqlInfoRow(label: t.vehicleType, value: vehicle(a.vehicleType), locked: true, lockedHint: t.accountFromOffice),
                  NaqlInfoRow(label: t.plate, value: a.plate ?? t.accountNotSet, locked: true, lockedHint: t.accountFromOffice),
                  NaqlInfoRow(label: t.seats, value: a.seats?.toString() ?? t.accountNotSet, locked: true, lockedHint: t.accountFromOffice),
                  NaqlInfoRow(label: t.modelYear, value: a.modelYear?.toString() ?? t.accountNotSet, locked: true, lockedHint: t.accountFromOffice),
                  const SizedBox(height: NaqlSpace.s1),
                  Text(t.accountChangeHint, style: NaqlText.caption),
                ]),
              ),
            ),
            const SizedBox(height: NaqlSpace.s4),
            NaqlEntrance(
              index: 2,
              child: NaqlListRow(
                title: t.accountDocuments,
                subtitle: t.accountDocumentsCount(a.documents.length),
                leading: const Icon(LucideIcons.fileCheck2, color: NaqlColors.primary),
              ),
            ),
            const SizedBox(height: NaqlSpace.s2),
            NaqlEntrance(
              index: 3,
              child: NaqlListRow(
                title: t.accountLanguage,
                subtitle: lang == 'ar' ? t.arabic : t.english,
                leading: const Icon(LucideIcons.languages, color: NaqlColors.primary),
                onTap: () => ref.read(localeProvider.notifier).toggle(),
              ),
            ),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(
              index: 4,
              child: NaqlButton(
                label: t.signOut,
                variant: NaqlButtonVariant.ghost,
                icon: LucideIcons.logOut,
                expand: true,
                onPressed: () async {
                  final ok = await showNaqlSheet<bool>(
                    context,
                    builder: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                      Text(t.accountSignOutTitle, style: NaqlText.title),
                      const SizedBox(height: NaqlSpace.s2),
                      Text(t.accountSignOutBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
                      const SizedBox(height: NaqlSpace.s5),
                      NaqlButton(label: t.signOut, expand: true, onPressed: () => Navigator.of(c).pop(true)),
                      const SizedBox(height: NaqlSpace.s2),
                      NaqlButton(label: t.accountStay, variant: NaqlButtonVariant.ghost, expand: true, onPressed: () => Navigator.of(c).pop(false)),
                    ]),
                  );
                  if (ok == true) await ref.read(applicationProvider.notifier).signOut();
                },
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}
