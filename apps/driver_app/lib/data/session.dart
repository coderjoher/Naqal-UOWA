import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// The signed-in driver's application (null = signed out). Drives which screens are reachable.
final applicationProvider = AsyncNotifierProvider<ApplicationNotifier, DriverApplication?>(ApplicationNotifier.new);

class ApplicationNotifier extends AsyncNotifier<DriverApplication?> {
  ApiClient get _api => ref.read(apiProvider);

  @override
  Future<DriverApplication?> build() async {
    if (await ref.read(tokenStoreProvider).read() == null) return null;
    try {
      return await _api.driverApplication();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<void> verify(String phone, String code) async {
    await _api.driverVerify(phone, code, university: ref.read(universitySlugProvider));
    state = AsyncData(await _api.driverApplication());
  }

  Future<void> save(Map<String, Object?> fields) async => state = AsyncData(await _api.updateDriverApplication(fields));

  Future<void> upload(String key, PickedDocument doc) async =>
      state = AsyncData(await _api.uploadDriverDocument(key, doc.bytes, filename: doc.filename, mime: doc.mime));

  Future<void> submit() async => state = AsyncData(await _api.submitDriverApplication());

  Future<void> refresh() async => state = AsyncData(await _api.driverApplication());

  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).write(null);
    state = const AsyncData(null);
  }
}

/// Phone being verified (between the phone and code screens) and a dev code if the server echoes it.
final pendingPhoneProvider = NotifierProvider<PendingPhone, ({String phone, String? devCode})?>(PendingPhone.new);

class PendingPhone extends Notifier<({String phone, String? devCode})?> {
  @override
  ({String phone, String? devCode})? build() => null;
  void set(({String phone, String? devCode})? v) => state = v;
}

class PickedDocument {
  const PickedDocument({required this.bytes, required this.filename, required this.mime});
  final List<int> bytes;
  final String filename;
  final String mime;
}

enum DocumentSource { camera, gallery }

/// Camera / gallery access. Replaced by a fake in tests (T2-07 "mocked camera").
abstract interface class DocumentPicker {
  Future<PickedDocument?> pick(DocumentSource source);
}
