import '../../../core/format/country_names.dart';
import '../../../core/format/job_format.dart';
import '../../../l10n/app_localizations.dart';
import '../../search/domain/entities/job_posting.dart';
import '../../search/domain/job_area.dart';
import '../../search/presentation/widgets/area_chips.dart';
import '../domain/recommendation.dart';

String _country(String code, String lang) => countryName(code, lang) ?? code;

WorkMode _mode(String? m) => WorkMode.values.firstWhere(
  (e) => e.name == m,
  orElse: () => WorkMode.unspecified,
);

/// A reason as a sentence in the interface language. Every sentence says what the LISTING agrees with; none says the person qualifies.
String reasonText(Reason r, AppLocalizations l, String lang, {DateTime? now}) =>
    switch (r.kind) {
      ReasonKind.professionExact => l.rcReasonProfessionExact(r.text ?? ''),
      ReasonKind.professionClose => l.rcReasonProfessionClose(r.text ?? ''),
      ReasonKind.professionSynonym => l.rcReasonProfessionSynonym(r.text ?? ''),
      ReasonKind.professionGroup => l.rcReasonProfessionGroup(r.text ?? ''),
      ReasonKind.professionRelated => l.rcReasonProfessionRelated(r.text ?? ''),
      ReasonKind.sameField => l.rcReasonSameField(
        areaLabel(
          JobArea.values.firstWhere(
            (a) => a.name == r.text,
            orElse: () => JobArea.services,
          ),
          l,
        ),
      ),
      ReasonKind.skills => l.rcReasonSkills(r.items.join(', ')),
      ReasonKind.countryOfInterest => l.rcReasonCountryInterest(
        _country(r.text ?? '', lang),
      ),
      ReasonKind.countryOfResidence => l.rcReasonCountryResidence(
        _country(r.text ?? '', lang),
      ),
      ReasonKind.remoteEligible => l.rcReasonRemoteEligible(
        _country(r.text ?? '', lang),
      ),
      ReasonKind.remoteAnywhere => l.rcReasonRemoteAnywhere,
      ReasonKind.city => l.rcReasonCity(r.text ?? ''),
      ReasonKind.workMode => l.rcReasonWorkMode(
        workModeLabel(_mode(r.text), l),
      ),
      ReasonKind.language => l.rcReasonLanguage(
        nativeLanguageName(r.text) ?? r.text ?? '',
      ),
      ReasonKind.recent => switch (r.number ?? 0) {
        <= 0 => l.publishedToday,
        1 => l.publishedYesterday,
        final d => l.publishedDaysAgo(d),
      },
    };

String caveatText(Caveat c, AppLocalizations l, String lang) =>
    switch (c.kind) {
      CaveatKind.locationUnknown => l.rcCaveatLocation,
      CaveatKind.languageDiffers => l.rcCaveatLanguage(
        nativeLanguageName(c.text) ?? c.text ?? '',
      ),
      CaveatKind.eligibilityRestricted => l.rcCaveatEligibility(
        [for (final g in c.items) countryName(g, lang) ?? g].join(', '),
      ),
      CaveatKind.workModeUnstated => l.rcCaveatMode,
    };

String fitLabel(Fit f, AppLocalizations l) => switch (f) {
  Fit.strong => l.rcFitStrong,
  Fit.good => l.rcFitGood,
  Fit.possible => l.rcFitPossible,
};
