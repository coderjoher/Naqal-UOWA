import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/session.dart';
import '../../l10n/gen/app_localizations.dart';

class CodeScreen extends ConsumerStatefulWidget {
  const CodeScreen({super.key});

  @override
  ConsumerState<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends ConsumerState<CodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final t = AppLocalizations.of(context);
    final pending = ref.read(pendingPhoneProvider);
    if (pending == null || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(applicationProvider.notifier).verify(pending.phone, _code.text);
    } catch (_) {
      if (mounted) setState(() => _error = t.wrongCode);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final pending = ref.watch(pendingPhoneProvider);
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.codeTitle, onBack: () => context.go('/phone')),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
            NaqlEntrance(child: Text(t.codeBody(pending?.phone ?? ''), style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
            const SizedBox(height: NaqlSpace.s5),
            NaqlEntrance(index: 1, child: NaqlOtpField(label: t.code, controller: _code, error: _error, onCompleted: (_) => _verify())),
            if (pending?.devCode != null) ...[
              const SizedBox(height: NaqlSpace.s3),
              StatusPill(label: t.testCode(pending!.devCode!), tone: NaqlTone.warning, icon: LucideIcons.flaskConical),
            ],
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 2, child: NaqlButton(label: t.verify, size: NaqlButtonSize.large, expand: true, loading: _busy, onPressed: _verify)),
          ]),
        ),
      ]),
    );
  }
}
