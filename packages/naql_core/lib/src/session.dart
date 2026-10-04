enum Role { student, driver, office, superAdmin }

Role roleFromJson(String v) => switch (v) {
      'student' => Role.student,
      'driver' => Role.driver,
      'office' => Role.office,
      'super_admin' => Role.superAdmin,
      _ => throw FormatException('Unknown role $v'),
    };

class SessionUser {
  const SessionUser({required this.id, required this.name, required this.role, this.universityId});

  factory SessionUser.fromJson(Map<String, dynamic> j) => SessionUser(
        id: j['id'] as String,
        name: j['name'] as String,
        role: roleFromJson(j['role'] as String),
        universityId: j['universityId'] as String?,
      );

  final String id;
  final String name;
  final Role role;
  final String? universityId;
}

class Session {
  const Session({required this.accessToken, required this.user});

  factory Session.fromJson(Map<String, dynamic> j) =>
      Session(accessToken: j['accessToken'] as String, user: SessionUser.fromJson(j['user'] as Map<String, dynamic>));

  final String accessToken;
  final SessionUser user;
}

/// Where the access token lives. Apps use secure storage; tests use [MemoryTokenStore].
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String? token) async => _token = token;
}
