import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/user_scope.dart';
import '../domain/professional_profile.dart';
import 'supabase_resume_repository.dart' show resumesBucket;

String? _date(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? _parseDate(Object? v) => v == null ? null : DateTime.tryParse('$v');

List<String> _strings(Object? v) => [
  for (final e in (v as List? ?? const [])) e.toString(),
];

ProfessionalProfile profileFromRow(Map<String, dynamic> r) =>
    ProfessionalProfile(
      id: r['id'] as String,
      name: r['name'] as String,
      countryOfResidence: (r['country_of_residence'] as String?)?.trim(),
      languages: [
        for (final l in (r['languages'] as List? ?? const []))
          if (l is Map && l['code'] is String)
            ProfileLanguage(
              code: l['code'] as String,
              level: l['level'] as String?,
            ),
      ],
      occupations: _strings(r['occupations']),
      skills: _strings(r['skills']),
      preferences: Map<String, dynamic>.from(
        r['preferences'] as Map? ?? const {},
      ),
    );

Map<String, dynamic> profileToRow(ProfessionalProfile p, String userId) => {
  'user_id': userId,
  'name': p.name,
  'country_of_residence': p.countryOfResidence,
  'languages': [
    for (final l in p.languages) {'code': l.code, 'level': ?l.level},
  ],
  'occupations': p.occupations,
  'skills': p.skills,
  'preferences': p.preferences,
};

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<List<ProfessionalProfile>> profiles() async {
    requireUserId(_client);
    final rows = await _client
        .from('professional_profiles')
        .select()
        .order('created_at', ascending: true);
    return [for (final r in rows) profileFromRow(r)];
  }

  @override
  Future<ProfessionalProfile> save(ProfessionalProfile p) async {
    final uid = requireUserId(_client);
    final row = p.id == null
        ? await _client
              .from('professional_profiles')
              .insert(profileToRow(p, uid))
              .select()
              .single()
        : await _client
              .from('professional_profiles')
              .update(profileToRow(p, uid)..remove('user_id'))
              .eq('id', p.id!)
              .select()
              .single();
    return profileFromRow(row);
  }

  @override
  Future<void> delete(String profileId) async {
    requireUserId(_client);
    // Deleting the profile cascades to its resume ROWS but not to the files in Storage, so the files go first.
    // If that fails the profile is kept, rather than leaving files nobody can reach any more.
    final rows = await _client
        .from('resumes')
        .select('storage_path')
        .eq('profile_id', profileId);
    final paths = [for (final r in rows) r['storage_path'] as String];
    if (paths.isNotEmpty) {
      await _client.storage.from(resumesBucket).remove(paths);
    }
    await _client.from('professional_profiles').delete().eq('id', profileId);
  }

  @override
  Future<List<Experience>> experiences(String profileId) async {
    requireUserId(_client);
    final rows = await _client
        .from('experiences')
        .select()
        .eq('profile_id', profileId)
        .order('start_date', ascending: false, nullsFirst: false);
    return [
      for (final r in rows)
        Experience(
          id: r['id'] as String,
          profileId: r['profile_id'] as String,
          company: r['company'] as String,
          title: r['title'] as String,
          startDate: _parseDate(r['start_date']),
          endDate: _parseDate(r['end_date']),
          description: r['description'] as String?,
        ),
    ];
  }

  @override
  Future<Experience> addExperience(Experience e) async {
    final uid = requireUserId(_client);
    final r = await _client
        .from('experiences')
        .insert({
          'profile_id': e.profileId,
          'user_id': uid,
          'company': e.company,
          'title': e.title,
          'start_date': _date(e.startDate),
          'end_date': _date(e.endDate),
          'description': e.description,
        })
        .select()
        .single();
    return Experience(
      id: r['id'] as String,
      profileId: e.profileId,
      company: e.company,
      title: e.title,
      startDate: e.startDate,
      endDate: e.endDate,
      description: e.description,
    );
  }

  @override
  Future<void> removeExperience(String id) async {
    requireUserId(_client);
    await _client.from('experiences').delete().eq('id', id);
  }

  @override
  Future<List<Education>> education(String profileId) async {
    requireUserId(_client);
    final rows = await _client
        .from('education')
        .select()
        .eq('profile_id', profileId)
        .order('start_date', ascending: false, nullsFirst: false);
    return [
      for (final r in rows)
        Education(
          id: r['id'] as String,
          profileId: r['profile_id'] as String,
          institution: r['institution'] as String,
          degree: r['degree'] as String?,
          field: r['field'] as String?,
          startDate: _parseDate(r['start_date']),
          endDate: _parseDate(r['end_date']),
        ),
    ];
  }

  @override
  Future<Education> addEducation(Education e) async {
    final uid = requireUserId(_client);
    final r = await _client
        .from('education')
        .insert({
          'profile_id': e.profileId,
          'user_id': uid,
          'institution': e.institution,
          'degree': e.degree,
          'field': e.field,
          'start_date': _date(e.startDate),
          'end_date': _date(e.endDate),
        })
        .select()
        .single();
    return Education(
      id: r['id'] as String,
      profileId: e.profileId,
      institution: e.institution,
      degree: e.degree,
      field: e.field,
      startDate: e.startDate,
      endDate: e.endDate,
    );
  }

  @override
  Future<void> removeEducation(String id) async {
    requireUserId(_client);
    await _client.from('education').delete().eq('id', id);
  }
}
