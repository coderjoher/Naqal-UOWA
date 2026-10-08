import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../l10n/gen/app_localizations.dart';
import 'feedback_sheets.dart';

final _iraqiMobile = RegExp(r'^(\+?964|0)?7\d{9}$');

/// ST-02: gender comes from the university record and is read-only; phone and default
/// gathering point are editable.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _phone = TextEditingController(text: _localPhone(ref.read(authProvider).value?.phone));
  bool _saving = false;
  String? _phoneError;
  String? _savedNote;

  static String _localPhone(String? e164) => e164 == null ? '' : e164.replaceFirst('+964', '0');

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _savePhone() async {
    final t = AppLocalizations.of(context);
    final v = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!_iraqiMobile.hasMatch(v)) return setState(() => _phoneError = t.invalidPhone);
    setState(() {
      _saving = true;
      _phoneError = null;
      _savedNote = null;
    });
    try {
      await ref.read(authProvider.notifier).setPhone(v);
      if (mounted) setState(() => _savedNote = t.saved);
    } catch (_) {
      if (mounted) setState(() => _phoneError = t.saveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final user = ref.watch(authProvider).value;
    if (user == null) return const SizedBox.shrink();
    return Column(children: [
      NaqlTopBar(title: t.profileTitle),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 120), children: [
          NaqlEntrance(
            child: Padding(
              padding: const EdgeInsets.only(bottom: NaqlSpace.s5),
              child: Row(children: [
                NaqlAvatar(name: user.displayName(lang), size: 64),
                const SizedBox(width: NaqlSpace.s4),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.displayName(lang), style: NaqlText.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(user.studentId, style: NaqlText.caption, textDirection: TextDirection.ltr),
                  ]),
                ),
              ]),
            ),
          ),
          NaqlEntrance(
            child: NaqlCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t.personalInfo, style: NaqlText.headline),
                const SizedBox(height: NaqlSpace.s2),
                NaqlInfoRow(label: t.name, value: user.displayName(lang), locked: true, lockedHint: t.fromUniversity),
                NaqlInfoRow(label: t.studentNumber, value: user.studentId, locked: true, lockedHint: t.fromUniversity),
                NaqlInfoRow(label: t.gender, value: user.gender == Gender.female ? t.female : t.male, locked: true, lockedHint: t.fromUniversity),
                const SizedBox(height: NaqlSpace.s1),
                Text(t.fromUniversity, style: NaqlText.caption),
              ]),
            ),
          ),
          const SizedBox(height: NaqlSpace.s4),
          NaqlEntrance(
            index: 1,
            child: NaqlCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                NaqlField(
                  label: t.phone,
                  hint: t.phoneHint,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  prefixIcon: LucideIcons.phone,
                  error: _phoneError,
                ),
                const SizedBox(height: NaqlSpace.s3),
                Row(children: [
                  NaqlButton(label: t.save, variant: NaqlButtonVariant.secondary, loading: _saving, onPressed: _savePhone),
                  const SizedBox(width: NaqlSpace.s3),
                  if (_savedNote != null) StatusPill(label: _savedNote!, tone: NaqlTone.success),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: NaqlSpace.s4),
          NaqlEntrance(
            index: 2,
            child: NaqlListRow(
              title: t.defaultPoint,
              subtitle: user.defaultPoint?.displayName(lang) ?? t.notSet,
              leading: const NaqlIconTile(LucideIcons.mapPin, size: 40),
              onTap: () => context.go('/profile/point'),
            ),
          ),
          const SizedBox(height: NaqlSpace.s2),
          NaqlEntrance(
            index: 3,
            child: NaqlListRow(
              title: t.language,
              subtitle: lang == 'ar' ? t.arabic : t.english,
              leading: const NaqlIconTile(LucideIcons.languages, size: 40),
              onTap: () => ref.read(localeProvider.notifier).toggle(),
            ),
          ),
          const SizedBox(height: NaqlSpace.s2),
          NaqlEntrance(
            index: 3,
            child: NaqlListRow(
              title: t.reportProblem,
              subtitle: t.reportProblemHint,
              leading: const NaqlIconTile(LucideIcons.messageSquareWarning, size: 40),
              onTap: () => showProblemSheet(context),
            ),
          ),
          const SizedBox(height: NaqlSpace.s6),
          NaqlEntrance(
            index: 4,
            child: NaqlButton(label: t.signOut, variant: NaqlButtonVariant.ghost, icon: LucideIcons.logOut, expand: true, onPressed: () => ref.read(authProvider.notifier).signOut()),
          ),
        ]),
      ),
    ]);
  }
}
