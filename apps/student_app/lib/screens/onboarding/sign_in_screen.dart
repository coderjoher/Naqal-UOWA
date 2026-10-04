import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/auth.dart';
import '../../l10n/gen/app_localizations.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signIn(_id.text, _password.text);
    } catch (e) {
      // 401 → wrong credentials; anything else (503 university system down, no network) → connection problem.
      final wrong = e is ApiException && (e.statusCode == 401 || e.statusCode == 400);
      if (mounted) setState(() => _error = wrong ? t.signInFailed : t.loadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final slug = ref.watch(universitySlugProvider);
    final uni = ref.watch(universitiesProvider).value?.where((u) => u.slug == slug).firstOrNull;
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.signInTitle, subtitle: uni?.displayName(lang), onBack: () => context.go('/university')),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
            NaqlEntrance(child: NaqlField(label: t.studentNumber, controller: _id, textDirection: TextDirection.ltr, prefixIcon: LucideIcons.idCard)),
            const SizedBox(height: NaqlSpace.s4),
            NaqlEntrance(
              index: 1,
              child: NaqlField(label: t.password, controller: _password, obscureText: true, textDirection: TextDirection.ltr, prefixIcon: LucideIcons.lock, error: _error),
            ),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 2, child: NaqlButton(label: t.signIn, expand: true, loading: _busy, onPressed: _submit)),
            if (uni == null || uni.studentSignIn == 'manual') ...[
              const SizedBox(height: NaqlSpace.s3),
              NaqlEntrance(index: 3, child: NaqlButton(label: t.firstTime, variant: NaqlButtonVariant.ghost, expand: true, onPressed: () => context.go('/activate'))),
            ],
          ]),
        ),
      ]),
    );
  }
}
