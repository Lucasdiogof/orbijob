import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/search/domain/country_portals.dart';

void main() {
  test(
    'every entry is an https link on a public-sector address of its country, never a private board',
    () {
      // the official services of the listed countries (a ministry, a public agency or a national job bank); a private board would fail here
      const officialHosts = {
        'empregabrasil.mte.gov.br',
        'www.iefp.pt',
        'www.sepe.es',
        'www.empleo.gob.mx',
        'www.argentina.gob.ar',
        'www.bne.cl',
        'www.serviciodeempleo.gov.co',
        'www.uruguayconcursa.gub.uy',
        'www.jobbank.gc.ca',
        'www.usajobs.gov',
        'www.workforceaustralia.gov.au',
        'www.jobs.govt.nz',
        'www.jobsireland.ie',
        'www.arbeitsagentur.de',
        'candidat.francetravail.fr',
        'arbeidsplassen.nav.no',
        'www.jobnet.dk',
        'tyomarkkinatori.fi',
        'www.hellowork.mhlw.go.jp',
        'www.work24.go.kr',
        'www.mycareersfuture.gov.sg',
        'www.ncs.gov.in',
        'essa.labour.gov.za',
      };
      final seen = <String>{};
      for (final code in countriesWithOfficialPortal) {
        expect(code, matches(RegExp(r'^[A-Z]{2}$')));
        final p = officialPortalFor(code)!;
        final u = Uri.parse(p.url);
        expect(u.scheme, 'https', reason: code);
        expect(officialHosts, contains(u.host), reason: '$code ${p.url}');
        expect(
          seen.add(u.host),
          isTrue,
          reason: 'two countries share ${u.host}',
        );
        expect(p.name.trim(), isNotEmpty);
      }
      expect(officialHosts.length, countriesWithOfficialPortal.length);
    },
  );

  test(
    'Brazil and the rest of Latin America that the catalogue barely covers have one; lookups are case-insensitive and null-safe',
    () {
      for (final c in ['BR', 'MX', 'AR', 'CL', 'CO', 'UY']) {
        expect(officialPortalFor(c), isNotNull, reason: c);
      }
      expect(officialPortalFor('br'), same(officialPortalFor('BR')));
      expect(officialPortalFor(null), isNull);
      expect(officialPortalFor('XX'), isNull);
    },
  );
}
