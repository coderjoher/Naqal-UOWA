import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../../data/session.dart';
import '../../l10n/gen/app_localizations.dart';

final _iraqiMobile = RegExp(r'^(\+?964|0)?7\d{9}$');

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final t = AppLocalizations.of(context);
    final v = _phone.text.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!_iraqiMobile.hasMatch(v)) return setState(() => _error = t.invalidPhone);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await ref.read(apiProvider).driverRequestCode(v);
      ref.read(pendingPhoneProvider.notifier).set((phone: v, devCode: devCode));
      if (mounted) context.go('/code');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.statusCode == 429 ? t.waitMinute : t.loadFailed);
    } catch (_) {
      if (mounted) setState(() => _error = t.loadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.phoneTitle, onBack: () => context.go('/university')),
        Expanded(
          child: ListView(padding: const EdgeInsets.all(NaqlSpace.s5), children: [
            NaqlEntrance(child: Text(t.phoneBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted))),
            const SizedBox(height: NaqlSpace.s5),
            NaqlEntrance(
              index: 1,
              child: NaqlField(
                label: t.phone,
                hint: t.phoneHint,
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                prefixIcon: LucideIcons.smartphone,
                error: _error,
              ),
            ),
            const SizedBox(height: NaqlSpace.s6),
            NaqlEntrance(index: 2, child: NaqlButton(label: t.sendCode, size: NaqlButtonSize.large, expand: true, loading: _busy, onPressed: _send)),
          ]),
        ),
      ]),
    );
  }
}
