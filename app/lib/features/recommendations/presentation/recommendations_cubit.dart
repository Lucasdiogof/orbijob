import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../search/domain/entities/job_posting.dart';
import '../../search/domain/job_filters.dart';
import '../../search/domain/search_repository.dart';
import '../domain/recommendation.dart';
import '../domain/recommender.dart';

enum RecStatus {
  /// Nothing asked yet (signed out, or the profile has not loaded).
  idle,
  loading,
  ready,

  /// The profile has nothing to compare listings with.
  needsProfile,

  /// The profile is usable but no open job matches it right now.
  empty,
  notConfigured,
  failure,
}

class RecommendationsState extends Equatable {
  const RecommendationsState({
    this.status = RecStatus.idle,
    this.items = const [],
    this.thin = false,
  });
  final RecStatus status;
  final List<Recommendation> items;

  /// The profile gave few criteria, so the list is broad.
  final bool thin;
  @override
  List<Object?> get props => [status, items, thin];
}

/// Builds the recommendations: a pool of candidate jobs from the catalogue (the person's profession and skills as search terms, their countries,
/// remote jobs), ranked on this device by the [Recommender]. The catalogue only ever answers questions it answers for everyone; the profile
/// never leaves the device for this.
class RecommendationsCubit extends Cubit<RecommendationsState> {
  RecommendationsCubit(this._repo, {Recommender? recommender})
    : _recommender = recommender ?? Recommender(),
      super(const RecommendationsState());

  final SearchRepository? _repo;
  final Recommender _recommender;
  RecommendationProfile? _last;
  int _generation = 0;

  static const poolPerQuery = 30;
  static const maxResults = 30;

  /// Recomputes for [profile]. Called again only when the profile (or the countries of interest) actually changed, unless [force].
  Future<void> refresh(
    RecommendationProfile? profile, {
    bool force = false,
  }) async {
    final repo = _repo;
    if (repo == null) {
      return emit(const RecommendationsState(status: RecStatus.notConfigured));
    }
    if (profile == null || profile.isEmpty) {
      _last = null;
      return emit(const RecommendationsState(status: RecStatus.needsProfile));
    }
    if (!force && _same(profile, _last) && state.status == RecStatus.ready) {
      return;
    }
    _last = profile;
    final gen = ++_generation;
    emit(RecommendationsState(status: RecStatus.loading, items: state.items));
    final pool = <String, JobPosting>{};
    var answered = 0;
    var failed = 0;
    Future<void> ask(Future<SearchResult> Function() q) async {
      try {
        final r = await q();
        answered++;
        if (r.notConfigured) return;
        for (final s in r.jobs) {
          pool.putIfAbsent('${s.job.source}:${s.job.externalId}', () => s.job);
        }
      } catch (_) {
        failed++;
      }
    }

    final asks = <Future<void>>[
      for (final t in profile.professions.take(2))
        ask(() => repo.search(t, limit: poolPerQuery)),
      for (final s in profile.skills.take(2))
        ask(() => repo.search(s, limit: 20)),
      for (final c in profile.countries.take(3))
        ask(
          () => repo.search(
            '',
            filters: JobFilters(countryCode: c),
            limit: poolPerQuery,
          ),
        ),
      if (profile.workMode == 'remote')
        ask(
          () => repo.search(
            '',
            filters: const JobFilters(workModes: {WorkMode.remote}),
            limit: poolPerQuery,
          ),
        ),
    ];
    await Future.wait(asks);
    if (gen != _generation) return;
    if (answered == 0 && failed > 0) {
      return emit(const RecommendationsState(status: RecStatus.failure));
    }
    final ranked = _recommender.rank(profile, pool.values, limit: maxResults);
    emit(
      RecommendationsState(
        status: ranked.isEmpty ? RecStatus.empty : RecStatus.ready,
        items: ranked,
        thin: !profile.hasProfession,
      ),
    );
  }

  static bool _same(RecommendationProfile a, RecommendationProfile? b) =>
      b != null &&
      a.professions.join('|') == b.professions.join('|') &&
      a.skills.join('|') == b.skills.join('|') &&
      (a.interestCountries.toList()..sort()).join() ==
          (b.interestCountries.toList()..sort()).join() &&
      a.residence == b.residence &&
      a.city == b.city &&
      a.workMode == b.workMode &&
      (a.languages.toList()..sort()).join() ==
          (b.languages.toList()..sort()).join() &&
      (a.mustHave.map((e) => e.name).toList()..sort()).join() ==
          (b.mustHave.map((e) => e.name).toList()..sort()).join();
}
