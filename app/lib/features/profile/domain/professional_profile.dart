import 'package:equatable/equatable.dart';

class ProfileLanguage extends Equatable {
  const ProfileLanguage({required this.code, this.level});
  final String code;
  final String? level;
  @override
  List<Object?> get props => [code, level];
}

/// A professional profile (a user can keep several, e.g. "Nurse" and "Developer"). Competencies are the
/// `skills` list; `preferences` holds free-form job preferences (salary, work mode, countries).
class ProfessionalProfile extends Equatable {
  const ProfessionalProfile({
    this.id,
    required this.name,
    this.countryOfResidence,
    this.languages = const [],
    this.occupations = const [],
    this.skills = const [],
    this.preferences = const {},
  });
  final String? id; // null until saved
  final String name;
  final String? countryOfResidence;
  final List<ProfileLanguage> languages;
  final List<String> occupations; // ISCO-08 codes
  final List<String> skills;
  final Map<String, dynamic> preferences;
  @override
  List<Object?> get props => [
    id,
    name,
    countryOfResidence,
    languages,
    occupations,
    skills,
    preferences,
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
  Future<void> removeExperience(String id);

  Future<List<Education>> education(String profileId);
  Future<Education> addEducation(Education e);
  Future<void> removeEducation(String id);
}
