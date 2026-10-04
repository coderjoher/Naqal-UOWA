import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:naql_app/naql_app.dart';
import 'package:naql_core/naql_core.dart';

/// Signed-in student (null = signed out). Loading while the stored token is checked.
final authProvider = AsyncNotifierProvider<AuthNotifier, StudentProfile?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<StudentProfile?> {
  ApiClient get _api => ref.read(apiProvider);

  @override
  Future<StudentProfile?> build() async {
    if (await ref.read(tokenStoreProvider).read() == null) return null;
    try {
      return await _api.studentProfile();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<void> signIn(String studentId, String password) async {
    await _api.studentLogin(ref.read(universitySlugProvider)!, studentId.trim(), password);
    state = AsyncData(await _api.studentProfile());
  }

  Future<void> activate(String studentId, String code, String password) async {
    await _api.studentActivate(ref.read(universitySlugProvider)!, studentId.trim(), code, password);
    state = AsyncData(await _api.studentProfile());
  }

  Future<void> setDefaultPoint(String pointId) async => state = AsyncData(await _api.updateStudentProfile(defaultPointId: pointId));

  Future<void> setPhone(String phone) async => state = AsyncData(await _api.updateStudentProfile(phone: phone));

  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).write(null);
    state = const AsyncData(null);
  }
}

final pointsProvider = FutureProvider.autoDispose<List<GatheringPoint>>((ref) => ref.watch(apiProvider).gatheringPoints());
