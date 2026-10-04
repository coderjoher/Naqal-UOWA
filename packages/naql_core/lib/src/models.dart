/// Plain models for the Naql API (hand-written until the OpenAPI generator replaces them).
library;

enum Gender { male, female }

Gender genderFromJson(String v) => v == 'female' ? Gender.female : Gender.male;

class UniversityInfo {
  const UniversityInfo({required this.slug, required this.name, this.nameAr, required this.studentSignIn});

  factory UniversityInfo.fromJson(Map<String, dynamic> j) => UniversityInfo(
        slug: j['slug'] as String,
        name: j['name'] as String,
        nameAr: j['nameAr'] as String?,
        studentSignIn: j['studentSignIn'] as String? ?? 'manual',
      );

  final String slug;
  final String name;
  final String? nameAr;

  /// `manual` (roster + activation code), `http` (university password) or `oidc` (SSO page).
  final String studentSignIn;

  String displayName(String lang) => lang == 'ar' && nameAr != null ? nameAr! : name;
}

class GatheringPoint {
  const GatheringPoint({required this.id, required this.name, this.nameAr, required this.tierId, this.tierName, this.distanceKm, required this.active});

  factory GatheringPoint.fromJson(Map<String, dynamic> j) => GatheringPoint(
        id: j['id'] as String,
        name: j['name'] as String,
        nameAr: j['nameAr'] as String?,
        tierId: j['tierId'] as String,
        tierName: (j['tier'] as Map<String, dynamic>?)?['name'] as String?,
        distanceKm: (j['distanceKm'] as num?)?.toDouble(),
        active: j['active'] as bool? ?? true,
      );

  final String id;
  final String name;
  final String? nameAr;
  final String tierId;
  final String? tierName;
  final double? distanceKm;
  final bool active;

  String displayName(String lang) => lang == 'ar' && nameAr != null && nameAr!.isNotEmpty ? nameAr! : name;
}

class StudentProfile {
  const StudentProfile({required this.id, required this.studentId, required this.name, this.nameAr, required this.gender, this.phone, this.defaultPoint});

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        id: j['id'] as String,
        studentId: j['studentId'] as String? ?? '',
        name: j['name'] as String,
        nameAr: j['nameAr'] as String?,
        gender: genderFromJson(j['gender'] as String? ?? 'male'),
        phone: j['phone'] as String?,
        defaultPoint: j['defaultPoint'] == null
            ? null
            : GatheringPoint.fromJson({...(j['defaultPoint'] as Map<String, dynamic>), 'tierId': (j['defaultPoint'] as Map<String, dynamic>)['tierId'] ?? ''}),
      );

  final String id;
  final String studentId;
  final String name;
  final String? nameAr;
  final Gender gender;
  final String? phone;
  final GatheringPoint? defaultPoint;

  String displayName(String lang) => lang == 'ar' && nameAr != null && nameAr!.isNotEmpty ? nameAr! : name;
}

enum DriverStatus { draft, pending, approved, rejected, suspended }

DriverStatus driverStatusFromJson(String v) => DriverStatus.values.firstWhere((s) => s.name == v, orElse: () => DriverStatus.draft);

/// One field of the registration form the transport office defined (TO-01 → DR-01).
class FormFieldSpec {
  const FormFieldSpec({required this.key, required this.kind, required this.label, this.labelAr, required this.required, this.options = const [], this.min, this.max});

  factory FormFieldSpec.fromJson(Map<String, dynamic> j) => FormFieldSpec(
        key: j['key'] as String,
        kind: j['kind'] as String,
        label: j['label'] as String,
        labelAr: j['labelAr'] as String?,
        required: j['required'] as bool? ?? false,
        options: ((j['options'] as List?) ?? const []).cast<String>(),
        min: j['min'] as int?,
        max: j['max'] as int?,
      );

  final String key;

  /// text | phone | select | number | year | document
  final String kind;
  final String label;
  final String? labelAr;
  final bool required;
  final List<String> options;
  final int? min;
  final int? max;

  bool get isDocument => kind == 'document';
  String get documentKey => key.startsWith('doc_') ? key.substring(4) : key;
  String displayLabel(String lang) => lang == 'ar' && labelAr != null ? labelAr! : label;
}

class DriverApplication {
  const DriverApplication({
    required this.status,
    this.reviewNote,
    this.name,
    this.phone,
    this.vehicleType,
    this.plate,
    this.seats,
    this.modelYear,
    required this.documents,
    required this.missing,
    required this.form,
  });

  factory DriverApplication.fromJson(Map<String, dynamic> j) {
    final app = j['application'] as Map<String, dynamic>;
    return DriverApplication(
      status: driverStatusFromJson(j['status'] as String),
      reviewNote: j['reviewNote'] as String?,
      name: app['name'] as String?,
      phone: app['phone'] as String?,
      vehicleType: app['vehicleType'] as String?,
      plate: app['plate'] as String?,
      seats: app['seats'] as int?,
      modelYear: app['modelYear'] as int?,
      documents: ((j['documents'] as List?) ?? const []).map((d) => (d as Map<String, dynamic>)['key'] as String).toSet(),
      missing: ((j['missing'] as List?) ?? const []).cast<String>(),
      form: ((j['form'] as List?) ?? const []).map((f) => FormFieldSpec.fromJson(f as Map<String, dynamic>)).toList(),
    );
  }

  final DriverStatus status;
  final String? reviewNote;
  final String? name;
  final String? phone;
  final String? vehicleType;
  final String? plate;
  final int? seats;
  final int? modelYear;
  final Set<String> documents;
  final List<String> missing;
  final List<FormFieldSpec> form;

  bool get complete => missing.isEmpty;
  bool get editable => status == DriverStatus.draft || status == DriverStatus.rejected;

  /// Current value of a non-document field by form key.
  Object? valueOf(String key) => switch (key) {
        'name' => name,
        'phone' => phone,
        'vehicle_type' => vehicleType,
        'plate' => plate,
        'seats' => seats,
        'model_year' => modelYear,
        _ => null,
      };
}
