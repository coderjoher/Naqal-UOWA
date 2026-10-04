import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_ui/naql_ui.dart';

import 'config.dart';
import 'providers.dart';

/// Small "server" button for demo builds; invisible in normal builds.
class ServerSettingsButton extends ConsumerWidget {
  const ServerSettingsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!demoBuild) return const SizedBox.shrink();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return NaqlIconButton(icon: LucideIcons.server, semanticLabel: ar ? 'عنوان الخادم' : 'Server address', onPressed: () => showNaqlSheet<void>(context, builder: (_) => const _ServerSheet()));
  }
}

class _ServerSheet extends ConsumerStatefulWidget {
  const _ServerSheet();

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  late final _c = TextEditingController(text: ref.read(serverUrlProvider) ?? '');
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    void save(String? v) {
      if (!ref.read(serverUrlProvider.notifier).set(v)) return setState(() => _error = ar ? 'عنوان غير صالح' : 'Not a valid address');
      Navigator.of(context).pop();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(ar ? 'عنوان الخادم' : 'Server address', style: NaqlText.title),
        const SizedBox(height: NaqlSpace.s1),
        Text(
          ar ? 'عنوان الحاسوب الذي يشغّل النظام على نفس الشبكة، مثل 192.168.1.20' : 'The computer running the system on the same network, e.g. 192.168.1.20',
          style: NaqlText.body.copyWith(color: NaqlColors.textMuted),
        ),
        const SizedBox(height: NaqlSpace.s4),
        NaqlField(label: ar ? 'العنوان' : 'Address', controller: _c, hint: 'http://192.168.1.20:3000', error: _error, keyboardType: TextInputType.url, textDirection: TextDirection.ltr),
        const SizedBox(height: NaqlSpace.s4),
        NaqlButton(label: ar ? 'حفظ' : 'Save', expand: true, onPressed: () => save(_c.text)),
        const SizedBox(height: NaqlSpace.s2),
        NaqlButton(label: ar ? 'العنوان الافتراضي' : 'Use default', variant: NaqlButtonVariant.ghost, expand: true, onPressed: () => save(null)),
      ]),
    );
  }
}
