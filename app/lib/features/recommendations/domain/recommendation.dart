import 'package:equatable/equatable.dart';

import '../../search/domain/entities/job_posting.dart';

/// Why a job was recommended, as data the screen turns into a sentence in the person's language. Nothing here is a claim about the person's
/// eligibility: it only says which parts of the profile the listing's own text agrees with.
enum ReasonKind {
  /// The listing's title contains what the person calls their profession. [Reason.text] = that profession.
  professionExact,

  /// Same profession in other words or another gender/number ("Enfermeira" / "Enfermeiro"). [Reason.text] = the profession.
  professionClose,

  /// The same profession under its name in another language ("Fisioterapeuta" / "Physiotherapist"). [Reason.text] = the profession.
  professionSynonym,

  /// The title names an occupation of the same ISCO unit group as the person's profession, in other words ("Software Engineer" for "Software
  /// Developer"); the specialty or qualifier may differ. [Reason.text] = the profession.
  professionGroup,

  /// A neighbouring occupation (software and application developers), related and NOT the same. [Reason.text] = the profession.
  professionRelated,

  /// Only the general area agrees (both "health"): shown as an extra, never as a reason on its own. [Reason.text] = area name key.
  sameField,

  /// The listing mentions skills of the profile. [Reason.items] = the skills.
  skills,

  /// The job is in one of the countries the person is interested in. [Reason.text] = ISO code.
  countryOfInterest,

  /// The job is in the person's country of residence. [Reason.text] = ISO code.
  countryOfResidence,

  /// Remote job that lists a country of the person as eligible. [Reason.text] = ISO code.
  remoteEligible,

  /// Remote job the source marks open to anywhere.
  remoteAnywhere,

  /// Same city as in the profile. [Reason.text] = city.
  city,

  /// The listing's work mode is the one the person prefers. [Reason.text] = remote | hybrid | onsite.
  workMode,

  /// The listing is written in a language of the profile. [Reason.text] = language code.
  language,

  /// Published recently. [Reason.number] = days ago.
  recent,
}

class Reason extends Equatable {
  const Reason(this.kind, {this.text, this.items = const [], this.number});
  final ReasonKind kind;
  final String? text;
  final List<String> items;
  final int? number;
  @override
  List<Object?> get props => [kind, text, items, number];
}

/// Things to check before acting on a recommendation. They are not reasons against it.
enum CaveatKind {
  /// The listing states no place at all.
  locationUnknown,

  /// The listing is in a language the profile does not list. [Caveat.text] = language code.
  languageDiffers,

  /// The listing restricts who may apply to certain countries or regions. [Caveat.items] = as the source wrote them. Whether the person
  /// qualifies (residence, visa, work permit) is NOT evaluated.
  eligibilityRestricted,

  /// The listing does not say whether the job is remote, hybrid or on site.
  workModeUnstated,
}

class Caveat extends Equatable {
  const Caveat(this.kind, {this.text, this.items = const []});
  final CaveatKind kind;
  final String? text;
  final List<String> items;
  @override
  List<Object?> get props => [kind, text, items];
}

enum Fit { strong, good, possible }

class Recommendation extends Equatable {
  const Recommendation({
    required this.job,
    required this.score,
    required this.fit,
    required this.reasons,
    required this.caveats,
    required this.signals,
  });

  final JobPosting job;

  /// 0-100: the share of the evaluable criteria the listing meets. A criterion the profile does not provide cannot lower it.
  final int score;
  final Fit fit;
  final List<Reason> reasons;
  final List<Caveat> caveats;

  /// How many criteria could be evaluated for this person (profession, skills, place, work mode, language, recency). Few = a thin profile.
  final int signals;

  @override
  List<Object?> get props => [job, score, fit, reasons, caveats, signals];
}

/// The criteria a person may declare as must-haves (everything else is a nice-to-have).
enum MustHave { workMode, country, language }
