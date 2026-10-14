import '../../preferences/domain/user_preferences.dart';
import '../../profile/domain/professional_profile.dart';
import '../../search/domain/entities/job_posting.dart';
import '../../search/domain/job_area.dart';
import '../../search/domain/search_alternatives.dart';
import 'match_text.dart';
import 'profession_groups.dart';
import 'recommendation.dart';

export 'match_text.dart' show normalizeForMatch;

/// What the recommender knows about the person, reduced to what matters for ranking. Anything missing simply is not evaluated.
class RecommendationProfile {
  const RecommendationProfile({
    this.professions = const [],
    this.skills = const [],
    this.interestCountries = const {},
    this.residence,
    this.city,
    this.workMode,
    this.languages = const {},
    this.mustHave = const {},
  });

  /// The headline and the titles of the last jobs, as the person wrote them.
  final List<String> professions;
  final List<String> skills;
  final Set<String> interestCountries;
  final String? residence;
  final String? city;

  /// `remote` | `hybrid` | `onsite`.
  final String? workMode;

  /// Primary language subtags (`pt`, `en`...).
  final Set<String> languages;
  final Set<MustHave> mustHave;

  factory RecommendationProfile.from(
    ProfessionalProfile? p,
    List<Experience> experiences,
    UserPreferences prefs,
  ) {
    String clean(String s) => s.trim();
    final titles = <String>[];
    void add(String? t) {
      final v = clean(t ?? '');
      if (v.length >= 3 &&
          !titles.any((e) => normalizeForMatch(e) == normalizeForMatch(v))) {
        titles.add(v);
      }
    }

    add(p?.headline);
    final sorted = [...experiences]
      ..sort(
        (a, b) => (b.startDate ?? DateTime(1900)).compareTo(
          a.startDate ?? DateTime(1900),
        ),
      );
    for (final e in sorted.take(3)) {
      add(e.title);
    }
    return RecommendationProfile(
      professions: titles,
      skills: [
        for (final s in p?.skills ?? const <String>[])
          if (clean(s).length >= 3) clean(s),
      ],
      interestCountries: {
        for (final c in prefs.countriesOfInterest)
          if (c.length == 2) c.toUpperCase(),
      },
      residence: p?.countryOfResidence?.toUpperCase(),
      city: p?.city,
      workMode: p?.workMode,
      languages: {
        for (final l in p?.languages ?? const <ProfileLanguage>[])
          l.code.toLowerCase().split(RegExp(r'[-_]')).first,
      },
      mustHave: p?.mustHave ?? const {},
    );
  }

  bool get hasProfession => professions.isNotEmpty;
  bool get hasPlace =>
      interestCountries.isNotEmpty ||
      residence != null ||
      (city ?? '').isNotEmpty;
  Set<String> get countries => {...interestCountries, ?residence};

  /// True when there is nothing to compare a listing with.
  bool get isEmpty =>
      !hasProfession &&
      skills.isEmpty &&
      !hasPlace &&
      workMode == null &&
      languages.isEmpty;
}

/// A deterministic, explainable ranking: every job gets points for the parts of the profile its own text agrees with, and each point has a
/// reason the screen can show. No model, no network, no hidden weights: the same profile and the same jobs always give the same list.
///
/// Rules that keep it honest:
///  * A criterion the profile does not provide is not evaluated and cannot lower the score (a thin profile is not a reason to bury a job).
///  * A job is dropped only for what it positively says: a must-have the listing contradicts. A listing that is silent is kept, with a note.
///  * With a profession on the profile, a job needs a profession or skill match to be listed at all (place and work mode alone would
///    recommend any job in the right country).
///  * Visas, work permits, professional registration and certifications are never evaluated or implied; a listing that restricts who may apply
///    only carries a reminder to check.
class Recommender {
  Recommender({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;

  static const _pProfession = 50.0;
  static const _pSkills = 15.0;
  static const _pPlace = 20.0;
  static const _pMode = 10.0;
  static const _pLanguage = 10.0;
  static const _pRecent = 5.0;

  List<Recommendation> rank(
    RecommendationProfile profile,
    Iterable<JobPosting> jobs, {
    int limit = 30,
  }) {
    final out = <Recommendation>[];
    final seen = <String>{};
    for (final j in jobs) {
      if (!seen.add('${j.source}:${j.externalId}')) continue;
      final r = evaluate(profile, j);
      if (r != null) out.add(r);
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      final da = a.job.publishedAt, db = b.job.publishedAt;
      if (da != null && db != null && da != db) return db.compareTo(da);
      if (da == null && db != null) return 1;
      if (da != null && db == null) return -1;
      return '${a.job.source}:${a.job.externalId}'.compareTo(
        '${b.job.source}:${b.job.externalId}',
      );
    });
    return diversify(out, limit);
  }

  /// At most half of the list from one source while other sources still have relevant jobs; the order inside each source and the
  /// overall ranking are kept, and nothing relevant is dropped when there is not enough variety (the rest fills the list in rank order).
  static List<Recommendation> diversify(
    List<Recommendation> ranked,
    int limit,
  ) {
    final cap = (limit / 2).ceil();
    final perSource = <String, int>{};
    final picked = <Recommendation>[];
    final held = <Recommendation>[];
    for (final r in ranked) {
      if (picked.length >= limit) break;
      final n = perSource[r.job.source] ?? 0;
      if (n >= cap) {
        held.add(r);
        continue;
      }
      perSource[r.job.source] = n + 1;
      picked.add(r);
    }
    for (final r in held) {
      if (picked.length >= limit) break;
      picked.add(r);
    }
    return picked;
  }

  /// One job against one profile: null when a must-have is contradicted or the job is not relevant to the profession.
  Recommendation? evaluate(RecommendationProfile p, JobPosting j) {
    final reasons = <(double, Reason)>[];
    final caveats = <Caveat>[];
    var earned = 0.0;
    var available = 0.0;
    var signals = 0;
    var relevant = false; // a profession or skill match

    final title = normalizeForMatch(j.title);

    // ── profession
    if (p.hasProfession) {
      available += _pProfession;
      signals++;
      final m = _bestProfession(p.professions, title, j.title);
      if (m != null) {
        earned += m.$1;
        reasons.add((m.$1, m.$2));
        // the general area is a hint, not a match: it never makes a listing relevant on its own
        if (m.$2.kind != ReasonKind.sameField) relevant = true;
      }
    }

    // ── skills (title and description; whole words only)
    if (p.skills.isNotEmpty) {
      available += _pSkills;
      signals++;
      final text =
          ' ${normalizeForMatch('${j.title} ${j.description ?? ''}')} ';
      final hit = <String>[];
      for (final s in p.skills) {
        final n = normalizeForMatch(s);
        if (n.length >= 3 && text.contains(' $n ') && !hit.contains(s)) {
          hit.add(s);
        }
      }
      if (hit.isNotEmpty) {
        final pts = (hit.length.clamp(1, 4) * (_pSkills / 4));
        earned += pts;
        reasons.add((
          pts,
          Reason(ReasonKind.skills, items: hit.take(4).toList()),
        ));
        relevant = true;
      }
    }

    // ── place
    final countries = p.countries;
    final hasPlaceInfo =
        (j.country ?? '').isNotEmpty ||
        j.geoRestrictions.isNotEmpty ||
        (j.city ?? '').isNotEmpty;
    if (p.hasPlace) {
      available += _pPlace;
      signals++;
      var pts = 0.0;
      final jc = j.country?.toUpperCase();
      if (jc != null && p.interestCountries.contains(jc)) {
        pts = 20;
        reasons.add((pts, Reason(ReasonKind.countryOfInterest, text: jc)));
      } else if (jc != null && p.residence == jc) {
        pts = 18;
        reasons.add((pts, Reason(ReasonKind.countryOfResidence, text: jc)));
      } else if (j.workMode == WorkMode.remote) {
        final geo = j.geoRestrictions.map((g) => g.toUpperCase()).toList();
        final shared = [
          for (final c in countries)
            if (geo.contains(c)) c,
        ];
        if (shared.isNotEmpty) {
          pts = 16;
          reasons.add((
            pts,
            Reason(ReasonKind.remoteEligible, text: shared.first),
          ));
        } else if (geo.contains('ANYWHERE')) {
          pts = 14;
          reasons.add((pts, const Reason(ReasonKind.remoteAnywhere)));
        }
      }
      final pc = normalizeForMatch(p.city ?? '');
      if (pc.isNotEmpty && normalizeForMatch(j.city ?? '') == pc) {
        pts = (pts + 5).clamp(0, _pPlace);
        reasons.add((5, Reason(ReasonKind.city, text: p.city)));
      }
      earned += pts;
    }
    if (!hasPlaceInfo) caveats.add(const Caveat(CaveatKind.locationUnknown));

    // ── work mode
    if (p.workMode != null) {
      available += _pMode;
      signals++;
      if (j.workMode == WorkMode.unspecified) {
        caveats.add(const Caveat(CaveatKind.workModeUnstated));
      } else if (j.workMode.name == p.workMode) {
        earned += _pMode;
        reasons.add((_pMode, Reason(ReasonKind.workMode, text: p.workMode)));
      }
    }

    // ── language of the listing
    final jl = j.language?.toLowerCase().split(RegExp(r'[-_]')).first;
    if (p.languages.isNotEmpty) {
      available += _pLanguage;
      signals++;
      if (jl != null && jl.isNotEmpty) {
        if (p.languages.contains(jl)) {
          earned += _pLanguage;
          reasons.add((_pLanguage, Reason(ReasonKind.language, text: jl)));
        } else {
          caveats.add(Caveat(CaveatKind.languageDiffers, text: jl));
        }
      }
    }

    // ── recency
    available += _pRecent;
    signals++;
    final pub = j.publishedAt;
    if (pub != null) {
      final days = _now().toUtc().difference(pub.toUtc()).inDays;
      final pts = days <= 3
          ? 5.0
          : (days <= 14 ? 3.0 : (days <= 30 ? 1.0 : 0.0));
      if (pts > 0) {
        earned += pts;
        if (days <= 14) {
          reasons.add((
            pts,
            Reason(ReasonKind.recent, number: days < 0 ? 0 : days),
          ));
        }
      }
    }

    // ── must-haves: dropped only when the listing says the opposite
    if (p.mustHave.contains(MustHave.workMode) &&
        p.workMode != null &&
        j.workMode != WorkMode.unspecified &&
        j.workMode.name != p.workMode) {
      return null;
    }
    if (p.mustHave.contains(MustHave.country) && countries.isNotEmpty) {
      final jc = j.country?.toUpperCase();
      final geo = j.geoRestrictions.map((g) => g.toUpperCase()).toList();
      final reachable =
          (jc != null && countries.contains(jc)) ||
          (j.workMode == WorkMode.remote &&
              (geo.contains('ANYWHERE') || countries.any(geo.contains)));
      final silent = jc == null && geo.isEmpty;
      if (!reachable && !silent) return null;
    }
    if (p.mustHave.contains(MustHave.language) &&
        p.languages.isNotEmpty &&
        jl != null &&
        jl.isNotEmpty &&
        !p.languages.contains(jl)) {
      return null;
    }

    // ── relevance gate: a profession or skill agrees. The general area alone never makes a listing relevant (a physiotherapist is not
    // offered doctors' jobs because both are "health"); it is only shown as an extra reason when something real already agrees.
    if (p.isEmpty) return null;
    if (p.hasProfession || p.skills.isNotEmpty) {
      if (!relevant) return null;
    } else if (!reasons.any((r) => r.$2.kind != ReasonKind.recent)) {
      // nothing professional on the profile: something besides "published recently" must agree with the listing
      return null;
    }

    final restricted = j.geoRestrictions
        .where((g) => g.toLowerCase() != 'anywhere')
        .toList();
    if (restricted.isNotEmpty) {
      caveats.add(
        Caveat(
          CaveatKind.eligibilityRestricted,
          items: restricted.take(6).toList(),
        ),
      );
    }

    final score = available <= 0
        ? 0
        : (100 * earned / available).round().clamp(0, 100);
    reasons.sort((a, b) => b.$1.compareTo(a.$1));
    return Recommendation(
      job: j,
      score: score,
      fit: score >= 75 ? Fit.strong : (score >= 50 ? Fit.good : Fit.possible),
      reasons: [for (final r in reasons) r.$2],
      caveats: caveats,
      signals: signals,
    );
  }

  (double, Reason)? _bestProfession(
    List<String> phrases,
    String normalizedTitle,
    String rawTitle,
  ) {
    (double, Reason)? best;
    void offer(double pts, Reason r) {
      if (best == null || pts > best!.$1) best = (pts, r);
    }

    final titleTokens = normalizedTitle
        .split(' ')
        .where((t) => t.length >= 3)
        .toList();
    for (final phrase in phrases) {
      final n = normalizeForMatch(phrase);
      if (n.length < 3) continue;
      final person = occupationOf(phrase);

      // 1) the words of the profession are in the title (same wording, a close form, or the same name in another language)
      Reason? text;
      double textPts = 0;
      if (' $normalizedTitle '.contains(' $n ')) {
        text = Reason(ReasonKind.professionExact, text: phrase);
        textPts = _pProfession;
      } else {
        final tokens = n.split(' ').where((t) => t.length >= 4).toList();
        if (tokens.isNotEmpty) {
          var matched = 0;
          for (final t in tokens) {
            final stem = t.length > 6 ? t.substring(0, 6) : t;
            if (titleTokens.any(
              (x) =>
                  (x.length > 6 ? x.substring(0, 6) : x) == stem &&
                  (x.length >= 5 || x == t),
            )) {
              matched++;
            }
          }
          final share = matched / tokens.length;
          if (matched > 0 && (tokens.length == 1 || share >= 0.67)) {
            text = Reason(ReasonKind.professionClose, text: phrase);
            textPts = 42;
          }
        }
        if (text == null) {
          final syn = titleAlternatives(phrase);
          if (syn.isNotEmpty && titleHasAlternative(rawTitle, syn)) {
            text = Reason(ReasonKind.professionSynonym, text: phrase);
            textPts = 38;
          }
        }
      }
      if (text != null) {
        // ...unless the title names ANOTHER occupation in which those words are only a modifier ("Engenheiro Eletricista" is not an
        // "Eletricista", "Auxiliar de enfermagem" is not an "Enfermeiro"): only when ESCO/ISCO knows both sides
        if (titleNamesOtherOccupation(
          person,
          rawTitle,
          minWords: text.kind == ReasonKind.professionSynonym ? 2 : 1,
        )) {
          continue;
        }
        offer(textPts, text);
        continue;
      }

      // 2) no shared words, but the title names an occupation of the person's own group, or of a close neighbour
      if (person.known) {
        var rel = Relation.none;
        for (final m in mentionsIn(rawTitle)) {
          final r = relationOf(person.codes, m.codes);
          if (r == Relation.sameGroup) {
            rel = r;
            break;
          }
          if (r == Relation.related ||
              (r == Relation.areaOnly && rel == Relation.none)) {
            rel = r;
          }
        }
        if (rel == Relation.sameGroup) {
          offer(34, Reason(ReasonKind.professionGroup, text: phrase));
          continue;
        }
        if (rel == Relation.related) {
          offer(24, Reason(ReasonKind.professionRelated, text: phrase));
          continue;
        }
      }

      // 3) only the general area agrees: a hint at most, never a recommendation by itself
      final mine = JobArea.of(phrase);
      final theirs = JobArea.of(rawTitle);
      final shared = [
        for (final a in mine)
          if (theirs.contains(a)) a,
      ];
      if (shared.isNotEmpty && !titleNamesOtherOccupation(person, rawTitle)) {
        offer(6, Reason(ReasonKind.sameField, text: shared.first.name));
      }
    }
    return best;
  }
}

/// Used by tests and the pool builder: the countries the person asked for, as ISO codes.
Set<String> countriesOf(UserPreferences prefs) => {
  for (final c in prefs.countriesOfInterest)
    if (c.length == 2) c.toUpperCase(),
};
