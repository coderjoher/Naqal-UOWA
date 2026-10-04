import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/auth.dart';
import '../../l10n/gen/app_localizations.dart';

class ActivateScreen extends ConsumerStatefulWidget {
  const ActivateScreen({super.key});

  @override
  ConsumerState<ActivateScreen> createState() => _ActivateScreenState();
}

class _ActivateScreenState extends ConsumerState<ActivateScreen> {
  final _id = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _id.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    if (_password.text.length < 8) return setState(() => _error = t.passwordHint);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).activate(_id.text, _code.text, _password.text);
    } catch (_) {
      if (mounted) setState(() => _error = t.activateFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.activateTitle, onBack: () => context.go('/sign-in')),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
            NaqlEntrance(child: Text(t.activateBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
            const SizedBox(height: NaqlSpace.s5),
            NaqlEntrance(index: 1, child: NaqlField(label: t.studentNumber, controller: _id, textDirection: TextDirection.ltr, prefixIcon: LucideIcons.idCard)),
            const SizedBox(height: NaqlSpace.s4),
            NaqlEntrance(index: 2, child: NaqlOtpField(label: t.activationCode, controller: _code, onCompleted: (_) {})),
            const SizedBox(height: NaqlSpace.s4),
            NaqlEntrance(
              index: 3,
              child: NaqlField(label: t.newPassword, hint: t.passwordHint, controller: _password, obscureText: true, textDirection: TextDirection.ltr, prefixIcon: LucideIcons.lock, error: _error),
            ),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 4, child: NaqlButton(label: t.activate, expand: true, loading: _busy, onPressed: _submit)),
          ]),
        ),
      ]),
    );
  }
}
