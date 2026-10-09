import 'dart:async';
import 'dart:typed_data';

import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/user_scope.dart';
import 'package:orbijob/core/di/injector.dart';
import 'package:orbijob/features/auth/domain/auth_repository.dart';
import 'package:orbijob/features/auth/domain/auth_user.dart';
import 'package:orbijob/features/applications/domain/application_record.dart';
import 'package:orbijob/features/favorites/domain/favorites_repository.dart';
import 'package:orbijob/features/preferences/domain/user_preferences.dart';
import 'package:orbijob/features/profile/domain/pdf_picker.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/profile/domain/resume_repository.dart';
import 'package:orbijob/features/search/domain/entities/job_posting.dart';

/// In-memory repositories for tests. They behave like the real ones at the contract level (ids, ordering,
/// not-found) and can be told to fail with a given error to exercise error handling.
class Failing {
  Object? error;
  void check() {
    if (error != null) throw error!;
  }
}

class FakeApplications extends Failing implements ApplicationsRepository {
  FakeApplications({this.auth});

  /// When set, rows are per signed-in user and a signed-out call is refused (like RLS + the repository guard).
  final FakeAuth? auth;
  final _byUser = <String, List<ApplicationRecord>>{};
  List<ApplicationRecord> get rows =>
      _byUser.putIfAbsent(auth?.currentUser?.id ?? '-', () => []);
  final events = <String, List<ApplicationEvent>>{};
  var _n = 0;

  @override
  Future<List<ApplicationRecord>> list() async {
    check();
    if (auth != null && auth!.currentUser == null) throw NotSignedInException();
    return List.of(rows);
  }

  @override
  Future<ApplicationRecord> create(
    JobPosting job, {
    ApplicationStage stage = ApplicationStage.applied,
    String? channel,
    DateTime? appliedAt,
    String? note,
    String? profileId,
  }) async {
    check();
    if (auth != null && auth!.currentUser == null) throw NotSignedInException();
    final r = ApplicationRecord(
      id: 'app-${++_n}',
      job: job,
      stage: stage,
      channel: channel,
      appliedAt: appliedAt,
      note: note,
      profileId: profileId,
    );
    rows.insert(0, r);
    // Mirrors the database trigger that writes the first history row.
    events[r.id] = [ApplicationEvent(stage: stage, occurredAt: DateTime(2026))];
    return r;
  }

  @override
  Future<void> changeStage(String id, ApplicationStage stage) async {
    check();
    final i = rows.indexWhere((e) => e.id == id);
    if (i < 0) throw StateError('not found');
    final o = rows[i];
    rows[i] = ApplicationRecord(
      id: o.id,
      job: o.job,
      stage: stage,
      channel: o.channel,
      appliedAt: o.appliedAt,
      note: o.note,
      profileId: o.profileId,
    );
    events[id] = [
      ...?events[id],
      ApplicationEvent(stage: stage, occurredAt: DateTime(2026, 1, 2)),
    ];
  }

  @override
  Future<void> updateNote(String id, String? note) async {
    check();
    final i = rows.indexWhere((e) => e.id == id);
    final o = rows[i];
    rows[i] = ApplicationRecord(
      id: o.id,
      job: o.job,
      stage: o.stage,
      channel: o.channel,
      appliedAt: o.appliedAt,
      note: note,
      profileId: o.profileId,
    );
  }

  @override
  Future<void> delete(String id) async {
    check();
    rows.removeWhere((e) => e.id == id);
    events.remove(id);
  }

  @override
  Future<List<ApplicationEvent>> history(String id) async {
    check();
    return List.of(events[id] ?? const []);
  }
}

class FakeProfiles extends Failing implements ProfileRepository {
  final profileRows = <ProfessionalProfile>[];
  final expRows = <Experience>[];
  final eduRows = <Education>[];
  var _n = 0;

  @override
  Future<List<ProfessionalProfile>> profiles() async {
    check();
    return List.of(profileRows);
  }

  @override
  Future<ProfessionalProfile> save(ProfessionalProfile p) async {
    check();
    if (p.id == null) {
      final created = ProfessionalProfile(
        id: 'p-${++_n}',
        name: p.name,
        countryOfResidence: p.countryOfResidence,
        languages: p.languages,
        occupations: p.occupations,
        skills: p.skills,
        preferences: p.preferences,
        personal: p.personal,
      );
      profileRows.add(created);
      return created;
    }
    final i = profileRows.indexWhere((e) => e.id == p.id);
    profileRows[i] = p;
    return p;
  }

  @override
  Future<void> delete(String profileId) async {
    check();
    profileRows.removeWhere((e) => e.id == profileId);
  }

  @override
  Future<List<Experience>> experiences(String profileId) async {
    check();
    return expRows.where((e) => e.profileId == profileId).toList();
  }

  @override
  Future<Experience> addExperience(Experience e) async {
    check();
    final c = Experience(
      id: 'x-${++_n}',
      profileId: e.profileId,
      company: e.company,
      title: e.title,
      startDate: e.startDate,
      endDate: e.endDate,
      description: e.description,
    );
    expRows.add(c);
    return c;
  }

  @override
  Future<Experience> updateExperience(Experience e) async {
    check();
    expRows[expRows.indexWhere((x) => x.id == e.id)] = e;
    return e;
  }

  @override
  Future<void> removeExperience(String id) async {
    check();
    expRows.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<Education>> education(String profileId) async {
    check();
    return eduRows.where((e) => e.profileId == profileId).toList();
  }

  @override
  Future<Education> addEducation(Education e) async {
    check();
    final c = Education(
      id: 'e-${++_n}',
      profileId: e.profileId,
      institution: e.institution,
      degree: e.degree,
      field: e.field,
      startDate: e.startDate,
      endDate: e.endDate,
    );
    eduRows.add(c);
    return c;
  }

  @override
  Future<Education> updateEducation(Education e) async {
    check();
    eduRows[eduRows.indexWhere((x) => x.id == e.id)] = e;
    return e;
  }

  @override
  Future<void> removeEducation(String id) async {
    check();
    eduRows.removeWhere((e) => e.id == id);
  }
}

class FakePreferences extends Failing implements PreferencesRepository {
  UserPreferences stored = const UserPreferences();
  int saves = 0;

  @override
  Future<UserPreferences> load() async {
    check();
    return stored;
  }

  @override
  Future<void> save(UserPreferences p) async {
    check();
    saves++;
    stored = p;
  }
}

class FakeSavedSearches extends Failing implements SavedSearchesRepository {
  final rows = <SavedSearch>[];
  var _n = 0;

  @override
  Future<List<SavedSearch>> list() async {
    check();
    return List.of(rows);
  }

  @override
  Future<SavedSearch> add(Map<String, dynamic> query) async {
    check();
    final s = SavedSearch(id: 's-${++_n}', query: query);
    rows.insert(0, s);
    return s;
  }

  @override
  Future<void> remove(String id) async {
    check();
    rows.removeWhere((e) => e.id == id);
  }
}

class FakeResumes extends Failing implements ResumeRepository {
  final rows = <ResumeFile>[];
  var _n = 0;
  int deleted = 0;

  @override
  Future<List<ResumeFile>> list(String profileId) async {
    check();
    return rows.where((e) => e.profileId == profileId).toList();
  }

  @override
  Future<ResumeFile> upload(String profileId, Uint8List pdfBytes) async {
    check();
    final f = ResumeFile(
      id: 'r-${++_n}',
      profileId: profileId,
      path: 'u/$_n.pdf',
      createdAt: DateTime(2026, 1, 1),
    );
    rows.insert(0, f);
    return f;
  }

  @override
  Future<String> signedUrl(
    ResumeFile file, {
    Duration validFor = const Duration(seconds: 60),
  }) async {
    check();
    return 'https://example.invalid/${file.path}';
  }

  @override
  Future<void> delete(ResumeFile file) async {
    check();
    deleted++;
    rows.removeWhere((e) => e.id == file.id);
  }
}

class FakePdfPicker implements PdfPicker {
  FakePdfPicker(this.result);
  PickedPdf? result;
  @override
  Future<PickedPdf?> pick() async => result;
}

/// A valid-looking PDF payload (starts with the %PDF signature).
Uint8List tinyPdf([int extra = 0]) => Uint8List.fromList([
  ...'%PDF-1.4\n%%EOF'.codeUnits,
  ...List.filled(extra, 0),
]);

/// Registers [FavoritesRepository] and the other fakes in the service locator, as the real start-up would with
/// Supabase. Call after `configureDependencies`.
class Fakes {
  Fakes({FakeAuth? auth}) : applications = FakeApplications(auth: auth);
  final FakeApplications applications;
  final profiles = FakeProfiles();
  final preferences = FakePreferences();
  final savedSearches = FakeSavedSearches();
  final resumes = FakeResumes();

  void register() {
    sl
      ..registerLazySingleton<ApplicationsRepository>(() => applications)
      ..registerLazySingleton<ProfileRepository>(() => profiles)
      ..registerLazySingleton<PreferencesRepository>(() => preferences)
      ..registerLazySingleton<SavedSearchesRepository>(() => savedSearches)
      ..registerLazySingleton<ResumeRepository>(() => resumes);
  }
}

/// Convenience for tests that need a `DataFailureKind` from a thrown error.
DataFailureKind kindOf(Object e) => mapDataError(e);

/// A favourites repository that fails on demand.
class FailingFavorites extends Failing implements FavoritesRepository {
  final inner = <String, JobPosting>{};
  @override
  Future<List<JobPosting>> list() async {
    check();
    return inner.values.toList();
  }

  @override
  Future<void> add(JobPosting job) async {
    check();
    inner['${job.source}:${job.externalId}'] = job;
  }

  @override
  Future<void> remove(JobPosting job) async {
    check();
    inner.remove('${job.source}:${job.externalId}');
  }
}

/// A controllable account service: [emit] simulates sign-in / sign-out / token loss from outside the app.
class FakeAuth implements AuthRepository {
  final _c = StreamController<AuthUser?>.broadcast();
  final _r = StreamController<void>.broadcast();
  Object? error;
  int passwordUpdates = 0;

  @override
  bool get isAvailable => true;
  @override
  AuthUser? currentUser;
  @override
  Stream<AuthUser?> get userChanges => _c.stream;
  @override
  Stream<void> get recoveryLinks => _r.stream;

  void emit(AuthUser? u) {
    currentUser = u;
    _c.add(u);
  }

  void emitError(Object e) => _c.addError(e);

  void recoveryLink(AuthUser u) {
    emit(u);
    _r.add(null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (error != null) throw error!;
    emit(AuthUser(id: 'user-${email.split('@').first}', email: email));
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    if (error != null) throw error!;
    return SignUpOutcome.confirmationRequired;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (error != null) throw error!;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    if (error != null) throw error!;
    passwordUpdates++;
  }

  @override
  Future<void> signOut() async => emit(null);
}
