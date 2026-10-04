import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';
import 'package:naql_ui/naql_ui.dart';

import '../data/image_document_picker.dart';
import '../data/session.dart';
import '../l10n/gen/app_localizations.dart';

/// DR-01: the registration form is generated from what the transport office requires (TO-01).
class ApplicationScreen extends ConsumerStatefulWidget {
  const ApplicationScreen({super.key});

  @override
  ConsumerState<ApplicationScreen> createState() => _ApplicationScreenState();
}

class _ApplicationScreenState extends ConsumerState<ApplicationScreen> {
  final _text = <String, TextEditingController>{};
  String? _vehicleType;
  bool _saving = false;
  bool _submitting = false;
  String? _uploadingKey;
  String? _message;

  @override
  void initState() {
    super.initState();
    final a = ref.read(applicationProvider).value!;
    for (final f in a.form.where((f) => !f.isDocument && f.kind != 'select' && f.key != 'phone')) {
      _text[f.key] = TextEditingController(text: a.valueOf(f.key)?.toString() ?? '');
    }
    _vehicleType = a.vehicleType;
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _fields() {
    int? n(String k) => int.tryParse(_text[k]?.text.trim() ?? '');
    return {
      'name': _text['name']?.text.trim(),
      'vehicleType': _vehicleType,
      'plate': _text['plate']?.text.trim(),
      'seats': n('seats'),
      'modelYear': n('model_year'),
    }..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      await ref.read(applicationProvider.notifier).save(_fields());
      if (mounted) setState(() => _message = t.saved);
    } catch (e) {
      if (mounted) setState(() => _message = apiErrorMessage(e, t.saveFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upload(FormFieldSpec f, DocumentSource source) async {
    final t = AppLocalizations.of(context);
    final picked = await ref.read(documentPickerProvider).pick(source);
    if (picked == null) return;
    setState(() => _uploadingKey = f.documentKey);
    try {
      await ref.read(applicationProvider.notifier).upload(f.documentKey, picked);
    } catch (e) {
      if (mounted) setState(() => _message = apiErrorMessage(e, t.uploadFailed));
    } finally {
      if (mounted) setState(() => _uploadingKey = null);
    }
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await ref.read(applicationProvider.notifier).save(_fields());
      await ref.read(applicationProvider.notifier).submit();
    } catch (e) {
      if (mounted) setState(() => _message = e is ApiException && e.statusCode == 422 ? t.incomplete : apiErrorMessage(e, t.saveFailed));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final lang = ref.watch(localeProvider).languageCode;
    final a = ref.watch(applicationProvider).value;
    if (a == null) return const SizedBox.shrink();
    final required = a.form.where((f) => f.required).length;
    final done = required - a.missing.length;
    String vehicleLabel(String v) => switch (v) { 'coaster' => t.coaster, 'minibus' => t.minibus, 'bus' => t.bus, 'van' => t.van, _ => v };

    Widget field(FormFieldSpec f, int i) {
      if (f.key == 'phone') return const SizedBox.shrink();
      if (f.kind == 'select') {
        return NaqlEntrance(
          index: i,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(f.displayLabel(lang), style: NaqlText.label),
            const SizedBox(height: NaqlSpace.s2),
            Wrap(spacing: NaqlSpace.s2, runSpacing: NaqlSpace.s2, children: [
              for (final o in f.options) NaqlChip(label: vehicleLabel(o), selected: _vehicleType == o, onSelected: () => setState(() => _vehicleType = o)),
            ]),
          ]),
        );
      }
      final numeric = f.kind == 'number' || f.kind == 'year';
      return NaqlEntrance(
        index: i,
        child: NaqlField(
          label: f.displayLabel(lang),
          controller: _text[f.key],
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
          textDirection: numeric || f.key == 'plate' ? TextDirection.ltr : null,
          hint: f.min != null && f.max != null ? '${f.min} – ${f.max}' : null,
          error: a.missing.contains(f.key) && (_text[f.key]?.text.isNotEmpty ?? false) ? '${f.min ?? ''}–${f.max ?? ''}' : null,
        ),
      );
    }

    Widget document(FormFieldSpec f, int i) {
      final uploaded = a.documents.contains(f.documentKey);
      final busy = _uploadingKey == f.documentKey;
      return NaqlEntrance(
        index: i,
        child: NaqlCard(
          nested: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(uploaded ? LucideIcons.circleCheck : LucideIcons.fileText, color: uploaded ? NaqlColors.success : NaqlColors.textMuted),
              const SizedBox(width: NaqlSpace.s3),
              Expanded(child: Text(f.displayLabel(lang), style: NaqlText.label.copyWith(fontWeight: FontWeight.w600))),
              StatusPill(
                label: busy ? t.uploading : (uploaded ? t.uploaded : (f.required ? t.notUploaded : t.optional)),
                tone: uploaded ? NaqlTone.success : (f.required ? NaqlTone.warning : NaqlTone.neutral),
              ),
            ]),
            const SizedBox(height: NaqlSpace.s3),
            Row(children: [
              Expanded(
                child: NaqlButton(
                  label: t.takePhoto,
                  icon: LucideIcons.camera,
                  variant: NaqlButtonVariant.secondary,
                  expand: true,
                  onPressed: busy ? null : () => _upload(f, DocumentSource.camera),
                ),
              ),
              const SizedBox(width: NaqlSpace.s2),
              Expanded(
                child: NaqlButton(
                  label: t.fromGallery,
                  icon: LucideIcons.image,
                  variant: NaqlButtonVariant.ghost,
                  expand: true,
                  onPressed: busy ? null : () => _upload(f, DocumentSource.gallery),
                ),
              ),
            ]),
          ]),
        ),
      );
    }

    final info = a.form.where((f) => !f.isDocument).toList();
    final docs = a.form.where((f) => f.isDocument).toList();
    return Scaffold(
      body: Column(children: [
        NaqlTopBar(title: t.applyTitle, trailing: NaqlIconButton(icon: LucideIcons.logOut, semanticLabel: t.signOut, onPressed: () => ref.read(applicationProvider.notifier).signOut())),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(NaqlSpace.s5, NaqlSpace.s2, NaqlSpace.s5, 140), children: [
            if (a.status == DriverStatus.rejected && a.reviewNote != null) ...[
              NaqlCard(nested: true, child: Text('${t.reason}: ${a.reviewNote}', style: NaqlText.body.copyWith(color: NaqlColors.danger))),
              const SizedBox(height: NaqlSpace.s4),
            ],
            Text(t.applyBody, style: NaqlText.body.copyWith(color: NaqlColors.textMuted)),
            const SizedBox(height: NaqlSpace.s4),
            // Progress: completed required items out of all required items.
            Semantics(
              label: t.progress(done, required),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(t.progress(done, required), style: NaqlText.label),
                const SizedBox(height: NaqlSpace.s2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(NaqlRadius.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: required == 0 ? 1 : done / required),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: NaqlColors.primary, backgroundColor: NaqlColors.surfaceMuted),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: NaqlSpace.s6),
            Text(t.sectionVehicle, style: NaqlText.headline),
            const SizedBox(height: NaqlSpace.s3),
            for (final (i, f) in info.indexed) Padding(padding: const EdgeInsets.only(bottom: NaqlSpace.s4), child: field(f, i)),
            Row(children: [
              NaqlButton(label: t.saveInfo, variant: NaqlButtonVariant.secondary, loading: _saving, onPressed: _save),
              const SizedBox(width: NaqlSpace.s3),
              if (_message != null) Flexible(child: Text(_message!, style: NaqlText.caption)),
            ]),
            const SizedBox(height: NaqlSpace.s6),
            Text(t.sectionDocuments, style: NaqlText.headline),
            const SizedBox(height: NaqlSpace.s3),
            for (final (i, f) in docs.indexed) Padding(padding: const EdgeInsets.only(bottom: NaqlSpace.s3), child: document(f, i)),
          ]),
        ),
      ]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(NaqlSpace.s5),
        child: NaqlButton(label: t.submit, size: NaqlButtonSize.large, expand: true, loading: _submitting, icon: LucideIcons.send, onPressed: _submit),
      ),
    );
  }
}
