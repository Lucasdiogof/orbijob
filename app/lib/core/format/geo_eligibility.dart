import '../../features/search/domain/entities/job_posting.dart';
import 'country_names.dart';

/// Marker the Worker stores when the source says "Anywhere" in so many words (worker/src/geo.ts, GEO_ANYWHERE).
const geoAnywhere = 'Anywhere';

/// What the stored `geo_restrictions` list means. An EMPTY list is "the source said nothing usable": unknown, never global.
enum GeoKind { unknown, anywhere, country, countries, region, mixed }

class GeoEligibility {
  const GeoEligibility(this.kind, this.places, {required this.needsCheck});

  final GeoKind kind;

  /// Localized names for the known countries and regions; anything else exactly as the source wrote it.
  final List<String> places;

  /// True when the app cannot be sure who may apply (unknown, regions, mixed, unrecognised names, "Anywhere" with places):
  /// the screen then asks the reader to confirm on the original listing.
  final bool needsCheck;
}

GeoEligibility geoEligibility(JobPosting j, String languageCode) {
  var tokens = j.geoRestrictions
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  // Records written before the list existed may carry only the single country.
  if (tokens.isEmpty && (j.country ?? '').isNotEmpty) tokens = [j.country!];
  if (tokens.isEmpty) {
    return const GeoEligibility(GeoKind.unknown, [], needsCheck: true);
  }
  final anywhere = tokens.any((t) => t.toLowerCase() == 'anywhere');
  final rest = tokens.where((t) => t.toLowerCase() != 'anywhere').toList();
  if (rest.isEmpty) {
    return const GeoEligibility(GeoKind.anywhere, [], needsCheck: false);
  }
  var countries = 0;
  var regions = 0;
  var unrecognised = 0;
  final places = <String>[];
  for (final t in rest) {
    final c = countryName(t, languageCode);
    final r = regionName(t, languageCode);
    if (c != null) {
      countries++;
      places.add(c);
    } else if (r != null) {
      regions++;
      places.add(r);
    } else {
      unrecognised++;
      places.add(t);
    }
  }
  final GeoKind kind;
  if (anywhere || (regions > 0 && countries > 0)) {
    kind = GeoKind.mixed;
  } else if (regions > 0) {
    kind = GeoKind.region;
  } else if (countries == 1 && unrecognised == 0) {
    kind = GeoKind.country;
  } else {
    kind = GeoKind.countries;
  }
  return GeoEligibility(
    kind,
    places,
    needsCheck: anywhere || regions > 0 || unrecognised > 0,
  );
}
