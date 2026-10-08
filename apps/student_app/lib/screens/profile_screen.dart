import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/auth.dart';
import '../data/home.dart';
import '../data/subscription.dart';
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
    if (user == null) return const Scaffold(body: SizedBox.shrink());
    final unread = ref.watch(unreadCountProvider);
    final sub = ref.watch(subscriptionProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NaqlTopBar(title: t.profileTitle, onBack: () => context.canPop() ? context.pop() : context.go('/home'), backLabel: MaterialLocalizations.of(context).backButtonTooltip),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, NaqlSpace.s8),
                children: [
                  NaqlEntrance(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: NaqlSpace.s5),
                      child: Row(
                        children: [
                          NaqlAvatar(name: user.displayName(lang), size: 64, square: true),
                          const SizedBox(width: NaqlSpace.s4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.displayName(lang), style: NaqlText.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                                Text(user.studentId, style: NaqlText.caption, textDirection: TextDirection.ltr),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // The places most visits come for, as three big tiles.
                  NaqlEntrance(
                    child: Row(
                      spacing: NaqlSpace.s3,
                      children: [
                        Expanded(
                          child: _MenuTile(key: const ValueKey('menu-trips'), icon: LucideIcons.ticket, label: t.tabTrips, onTap: () => context.push('/trips')),
                        ),
                        Expanded(
                          child: _MenuTile(
                            key: const ValueKey('menu-subscription'),
                            icon: LucideIcons.creditCard,
                            label: t.mySubscription,
                            caption: sub == null ? null : (sub.isActive ? t.subActive : t.subNone),
                            onTap: () => context.push('/subscription'),
                          ),
                        ),
                        Expanded(
                          child: _MenuTile(key: const ValueKey('menu-alerts'), icon: LucideIcons.bell, label: t.notifications, dot: unread > 0, onTap: () => context.push('/alerts')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: NaqlSpace.s4),
                  NaqlEntrance(
                    child: NaqlCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(t.personalInfo, style: NaqlText.headline),
                          const SizedBox(height: NaqlSpace.s2),
                          NaqlInfoRow(label: t.name, value: user.displayName(lang), locked: true, lockedHint: t.fromUniversity),
                          NaqlInfoRow(label: t.studentNumber, value: user.studentId, locked: true, lockedHint: t.fromUniversity),
                          NaqlInfoRow(label: t.gender, value: user.gender == Gender.female ? t.female : t.male, locked: true, lockedHint: t.fromUniversity),
                          const SizedBox(height: NaqlSpace.s1),
                          Text(t.fromUniversity, style: NaqlText.caption),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: NaqlSpace.s4),
                  NaqlEntrance(
                    index: 1,
                    child: NaqlCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                          Row(
                            children: [
                              NaqlButton(label: t.save, variant: NaqlButtonVariant.secondary, loading: _saving, onPressed: _savePhone),
                              const SizedBox(width: NaqlSpace.s3),
                              if (_savedNote != null) StatusPill(label: _savedNote!, tone: NaqlTone.success),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: NaqlSpace.s4),
                  NaqlEntrance(
                    index: 2,
                    child: NaqlListRow(
                      title: t.defaultPoint,
                      subtitle: user.defaultPoint?.displayName(lang) ?? t.notSet,
                      leading: const NaqlIconTile(LucideIcons.mapPin, size: 40),
                      onTap: () => context.push('/profile/point'),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A big square entry on the account page: icon, label, optional caption or unread dot.
class _MenuTile extends StatelessWidget {
  const _MenuTile({super.key, required this.icon, required this.label, required this.onTap, this.caption, this.dot = false});
  final IconData icon;
  final String label;
  final String? caption;
  final bool dot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NaqlPanel(
    floating: true,
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Semantics(
      button: true,
      label: [label, caption].whereType<String>().join('، '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NaqlIconTile(icon, size: 40),
              if (dot)
                PositionedDirectional(
                  top: -2,
                  end: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: NaqlColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: NaqlColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: NaqlSpace.s3),
          Text(
            label,
            style: NaqlText.label.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(caption ?? ' ', style: NaqlText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}
