import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/core/data/data_failure.dart';
import 'package:orbijob/core/data/load_status.dart';
import 'package:orbijob/features/profile/domain/professional_profile.dart';
import 'package:orbijob/features/profile/presentation/profile_cubit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../helpers/fakes.dart';

void main() {
  late FakeProfiles repo;
  late ProfileCubit c;
  setUp(() {
    repo = FakeProfiles();
    c = ProfileCubit(repo);
  });

  test('without a backend: not configured', () async {
    final n = ProfileCubit(null);
    await n.load();
    expect(n.state.failure, DataFailureKind.notConfigured);
    expect(await n.saveProfile(const ProfessionalProfile(name: 'A')), isFalse);
  });

  test('a new user has no profile: ready and empty, not an error', () async {
    await c.load();
    expect(c.state.status, LoadStatus.ready);
    expect(c.state.profile, isNull);
  });

  test('creates a profile for any profession; headline, summary, city and work mode live in the JSON columns', () async {
    await c.load();
    final p = const ProfessionalProfile(name: 'Maria Souza').copyWith(
      headline: 'Enfermeira',
      summary: 'UTI adulto',
      city: 'Goiânia',
      workMode: 'hybrid',
      countryOfResidence: 'BR',
      skills: ['Triagem', 'BLS'],
    );
    expect(await c.saveProfile(p), isTrue);
    final saved = repo.profileRows.single;
    expect(saved.id, isNotNull);
    expect(saved.personal, {
      'headline': 'Enfermeira',
      'summary': 'UTI adulto',
      'city': 'Goiânia',
    });
    expect(saved.preferences['workMode'], 'hybrid');
    expect(c.state.profile!.headline, 'Enfermeira');
    expect(c.state.profile!.skills, ['Triagem', 'BLS']);
  });

  test('blank optional fields are removed, unknown keys are kept', () {
    final p = const ProfessionalProfile(
      name: 'A',
      personal: {'headline': 'X', 'other': 1},
      preferences: {'workMode': 'remote', 'keep': true},
    ).copyWith(headline: ' ', clearWorkMode: true);
    expect(p.personal, {'other': 1});
    expect(p.preferences, {'keep': true});
    expect(p.workMode, isNull);
  });

  test('loads the profile with its experiences and education', () async {
    final p = await repo.save(const ProfessionalProfile(name: 'A'));
    await repo.addExperience(
      Experience(profileId: p.id!, company: 'C', title: 'T'),
    );
    await repo.addEducation(Education(profileId: p.id!, institution: 'U'));
    await c.load();
    expect(c.state.experiences, hasLength(1));
    expect(c.state.education, hasLength(1));
  });

  test(
    'experience: add, edit, current job, newest first, undated last, delete',
    () async {
      final p = await repo.save(const ProfessionalProfile(name: 'A'));
      await c.load();
      final id = p.id!;
      await c.saveExperience(
        Experience(
          profileId: id,
          company: 'Old',
          title: 'T',
          startDate: DateTime(2018),
          endDate: DateTime(2020),
        ),
      );
      await c.saveExperience(
        Experience(
          profileId: id,
          company: 'Now',
          title: 'T',
          startDate: DateTime(2022),
        ),
      );
      await c.saveExperience(
        Experience(profileId: id, company: 'Undated', title: 'T'),
      );
      expect(c.state.experiences.map((e) => e.company), [
        'Now',
        'Old',
        'Undated',
      ]);
      expect(c.state.experiences.first.isCurrent, isTrue);
      expect(c.state.experiences[1].isCurrent, isFalse);
      final now = c.state.experiences.first;
      await c.saveExperience(
        Experience(
          id: now.id,
          profileId: id,
          company: 'Now',
          title: 'Lead',
          startDate: DateTime(2022),
        ),
      );
      expect(c.state.experiences.first.title, 'Lead');
      expect(c.state.experiences, hasLength(3));
      await c.removeExperience(now.id!);
      expect(c.state.experiences.map((e) => e.company), ['Old', 'Undated']);
    },
  );

  test('education is optional and may be incomplete', () async {
    final p = await repo.save(const ProfessionalProfile(name: 'A'));
    await c.load();
    expect(
      await c.saveEducation(Education(profileId: p.id!, institution: 'SENAI')),
      isTrue,
    );
    final e = c.state.education.single;
    expect(e.degree, isNull);
    expect(e.startDate, isNull);
    await c.saveEducation(
      Education(
        id: e.id,
        profileId: p.id!,
        institution: 'SENAI',
        field: 'Eletricista',
      ),
    );
    expect(c.state.education.single.field, 'Eletricista');
    await c.removeEducation(e.id!);
    expect(c.state.education, isEmpty);
  });

  test(
    'a refused write leaves the screen as it was and reports the cause',
    () async {
      final p = await repo.save(const ProfessionalProfile(name: 'A'));
      await c.load();
      repo.error = const sb.PostgrestException(message: 'rls', code: '42501');
      expect(
        await c.saveExperience(
          Experience(profileId: p.id!, company: 'C', title: 'T'),
        ),
        isFalse,
      );
      expect(c.state.experiences, isEmpty);
      expect(c.state.actionFailure, DataFailureKind.denied);
      expect(c.state.saving, isFalse);
    },
  );

  test('a write that arrives while another is saving is ignored', () async {
    final p = await repo.save(const ProfessionalProfile(name: 'A'));
    await c.load();
    final a = c.saveExperience(
      Experience(profileId: p.id!, company: 'C', title: 'T'),
    );
    final b = c.saveExperience(
      Experience(profileId: p.id!, company: 'C2', title: 'T'),
    );
    expect(await b, isFalse);
    expect(await a, isTrue);
    expect(repo.expRows, hasLength(1));
  });

  test(
    'too-large profile JSON (32 KB constraint) is reported as invalid input',
    () async {
      await c.load();
      repo.error = const sb.PostgrestException(
        message: 'profiles_json_size',
        code: '23514',
      );
      expect(
        await c.saveProfile(const ProfessionalProfile(name: 'A')),
        isFalse,
      );
      expect(c.state.actionFailure, DataFailureKind.invalidInput);
    },
  );
}
