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
                  NaqlAvatar(name: (a.name?.trim().isNotEmpty ?? false) ? a.name!.trim() : '؟', size: 60),
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
                  Row(children: [
                    NaqlIconTile(a.vehicleType == 'taxi' ? LucideIcons.carTaxiFront : LucideIcons.busFront, size: 52),
                    const SizedBox(width: NaqlSpace.s3),
                    Expanded(child: Text(t.accountVehicle, style: NaqlText.headline)),
                  ]),
                  const SizedBox(height: NaqlSpace.s4),
                  // The plate as it looks on the vehicle.
                  Semantics(
                    label: '${t.plate}: ${a.plate ?? t.accountNotSet}. ${t.accountFromOffice}',
                    excludeSemantics: true,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: NaqlSpace.s2),
                      child: Row(children: [
                        Expanded(child: Text(t.plate, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
                        if (a.plate != null) NaqlPlateBadge(a.plate!, large: true) else Text(t.accountNotSet, style: NaqlText.body.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: NaqlSpace.s2),
                        Icon(LucideIcons.lock, size: 16, color: NaqlColors.textMuted),
                      ]),
                    ),
                  ),
                  NaqlInfoRow(label: t.vehicleType, value: vehicle(a.vehicleType), locked: true, lockedHint: t.accountFromOffice),
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
                leading: const NaqlIconTile(LucideIcons.fileCheck2, size: 40),
                onTap: () => showNaqlSheet<void>(context, builder: (_) => _DocumentsSheet(lang: lang)),
              ),
            ),
            const SizedBox(height: NaqlSpace.s2),
            NaqlEntrance(
              index: 3,
              child: NaqlListRow(
                title: t.accountLanguage,
                subtitle: lang == 'ar' ? t.arabic : t.english,
                leading: const NaqlIconTile(LucideIcons.languages, size: 40),
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

/// The documents the office asked for, and which of them this driver has uploaded.
class _DocumentsSheet extends ConsumerWidget {
  const _DocumentsSheet({required this.lang});
  final String lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final a = ref.watch(applicationProvider).value;
    if (a == null) return const SizedBox.shrink();
    final asked = [for (final f in a.form) if (f.isDocument) (key: f.key.replaceFirst('doc_', ''), label: lang == 'ar' ? (f.labelAr ?? f.label) : f.label, required: f.required)];
    // Uploaded documents the current form no longer asks for still count.
    final extra = [for (final k in a.documents) if (!asked.any((d) => d.key == k)) (key: k, label: k, required: false)];
    final docs = [...asked, ...extra];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(t.accountDocuments, style: NaqlText.title),
      const SizedBox(height: NaqlSpace.s1),
      Text(t.accountDocumentsHint, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
      const SizedBox(height: NaqlSpace.s4),
      if (docs.isEmpty) Text(t.accountDocumentsCount(0), style: NaqlText.body),
      for (final d in docs)
        Padding(
          padding: const EdgeInsets.only(bottom: NaqlSpace.s2),
          child: Row(children: [
            Icon(a.documents.contains(d.key) ? LucideIcons.circleCheck : LucideIcons.circleDashed,
                color: a.documents.contains(d.key) ? NaqlColors.success : NaqlColors.textMuted, size: 22),
            const SizedBox(width: NaqlSpace.s3),
            Expanded(child: Text(d.label, style: NaqlText.body)),
            StatusPill(
              label: a.documents.contains(d.key) ? t.accountDocUploaded : t.accountDocMissing,
              tone: a.documents.contains(d.key) ? NaqlTone.success : (d.required ? NaqlTone.warning : NaqlTone.neutral),
            ),
          ]),
        ),
      const SizedBox(height: NaqlSpace.s3),
      NaqlButton(label: t.accountClose, variant: NaqlButtonVariant.ghost, expand: true, onPressed: () => Navigator.of(context).pop()),
    ]);
  }
}
