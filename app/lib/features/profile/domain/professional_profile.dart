import 'package:equatable/equatable.dart';

class ProfileLanguage extends Equatable {
  const ProfileLanguage({required this.code, this.level});
  final String code;
  final String? level;
  @override
  List<Object?> get props => [code, level];
}

/// Work modes a professional can prefer (stored as text inside `preferences`).
const workModePreferences = ['remote', 'hybrid', 'onsite'];

/// A professional profile (a user can keep several, e.g. "Nurse" and "Developer"). Competencies are the
/// `skills` list. There are no columns for headline, summary, city or preferred work mode: they live inside the
/// existing JSON columns (`personal`: headline, summary, city; `preferences`: workMode), so the schema is
/// untouched. Unknown keys in those columns are preserved on save.
class ProfessionalProfile extends Equatable {
  const ProfessionalProfile({
    this.id,
    required this.name,
    this.countryOfResidence,
    this.languages = const [],
    this.occupations = const [],
    this.skills = const [],
    this.preferences = const {},
    this.personal = const {},
  });
  final String? id; // null until saved
  final String name;
  final String? countryOfResidence;
  final List<ProfileLanguage> languages;
  final List<String> occupations; // ISCO-08 codes
  final List<String> skills;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> personal;

  /// Role or profession as the person describes it ("Enfermeira", "Eletricista", "Backend developer").
  String? get headline => _text(personal['headline']);
  String? get summary => _text(personal['summary']);
  String? get city => _text(personal['city']);

  /// `remote` | `hybrid` | `onsite`, or null when not chosen.
  String? get workMode {
    final v = _text(preferences['workMode']);
    return workModePreferences.contains(v) ? v : null;
  }

  static String? _text(Object? v) {
    final t = v is String ? v.trim() : '';
    return t.isEmpty ? null : t;
  }

  ProfessionalProfile copyWith({
    String? name,
    String? countryOfResidence,
    bool clearCountry = false,
    List<String>? skills,
    String? headline,
    String? summary,
    String? city,
    String? workMode,
    bool clearWorkMode = false,
  }) {
    Map<String, dynamic> put(Map<String, dynamic> m, String k, String? v) {
      final next = Map<String, dynamic>.of(m);
      final t = _text(v);
      t == null ? next.remove(k) : next[k] = t;
      return next;
    }

    var nextPersonal = personal;
    if (headline != null) {
      nextPersonal = put(nextPersonal, 'headline', headline);
    }
    if (summary != null) nextPersonal = put(nextPersonal, 'summary', summary);
    if (city != null) nextPersonal = put(nextPersonal, 'city', city);
    var nextPrefs = preferences;
    if (clearWorkMode) nextPrefs = put(nextPrefs, 'workMode', null);
    if (workMode != null) nextPrefs = put(nextPrefs, 'workMode', workMode);
    return ProfessionalProfile(
      id: id,
      name: name ?? this.name,
      countryOfResidence: clearCountry
          ? null
          : (countryOfResidence ?? this.countryOfResidence),
      languages: languages,
      occupations: occupations,
      skills: skills ?? this.skills,
      preferences: nextPrefs,
      personal: nextPersonal,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    countryOfResidence,
    languages,
    occupations,
    skills,
    preferences,
    personal,
  ];
}

class Experience extends Equatable {
  const Experience({
    this.id,
    required this.profileId,
    required this.company,
    required this.title,
    this.startDate,
    this.endDate,
    this.description,
  });
  final String? id;
  final String profileId;
  final String company;
  final String title;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? description;

  /// There is no column for "current job": a start date without an end date means the person still works there.
  bool get isCurrent => startDate != null && endDate == null;
  @override
  List<Object?> get props => [
    id,
    profileId,
    company,
    title,
    startDate,
    endDate,
    description,
  ];
}

class Education extends Equatable {
  const Education({
    this.id,
    required this.profileId,
    required this.institution,
    this.degree,
    this.field,
    this.startDate,
    this.endDate,
  });
  final String? id;
  final String profileId;
  final String institution;
  final String? degree;
  final String? field;
  final DateTime? startDate;
  final DateTime? endDate;
  @override
  List<Object?> get props => [
    id,
    profileId,
    institution,
    degree,
    field,
    startDate,
    endDate,
  ];
}

abstract class ProfileRepository {
  Future<List<ProfessionalProfile>> profiles();
  Future<ProfessionalProfile> save(ProfessionalProfile profile);
  Future<void> delete(String profileId);

  Future<List<Experience>> experiences(String profileId);
  Future<Experience> addExperience(Experience e);
  Future<Experience> updateExperience(Experience e);
  Future<void> removeExperience(String id);

  Future<List<Education>> education(String profileId);
  Future<Education> addEducation(Education e);
  Future<Education> updateEducation(Education e);
  Future<void> removeEducation(String id);
}
