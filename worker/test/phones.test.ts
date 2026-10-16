import { describe, expect, it } from 'vitest';
import { MASKED_PHONE, maskPersonalPhones } from '../src/phones';

const mask = (t: string, country: string | null = null) => maskPersonalPhones(t, country);

// Cases taken from the published catalogue (2026-10-16 audit), names and numbers as they appear in public listings, plus synthetic edge cases.
const M = MASKED_PHONE;

describe('personal telephone numbers are masked, in every international format', () => {
  it.each([
    // Germany (Arbeitnow, Karriere.NRW)
    ['If you have any questions, you can reach out to Alina by phone +49 89 2441067714. Find Jobs', `reach out to Alina by phone ${M}. Find Jobs`],
    ['Habibe Hyusein Telefon: +49 421 43841 985 Mobil: +49 173 3277155 Mail:', `Telefon: ${M} Mobil: ${M} Mail:`],
    ['steht Ihnen Herr Marcus Heinrich, unter der Rufnummer 0179 / 12 92 419 gerne zur Verfügung', `Rufnummer ${M} gerne`],
    ['Fachamt: Herr Becker, Tel.: 02238/808-190 Personalabteilung', `Tel.: ${M} Personalabteilung`],
    ['Ihre Ansprechperson: Dr. Judith Dörrenbächer +49 271 740-5270 [e-mail]', `Dörrenbächer ${M} [e-mail]`],
    ['Herr Pollmann (Amtsleitung):+49 2206-602725 und', `(Amtsleitung):${M} und`],
    // Sweden (Platsbanken)
    ['Vid frågor är du välkommen att kontakta Frida Borg på 040-608 76 01. I rekryteringsprocessen', `Frida Borg på ${M}. I`],
    ['📧 E-post: [e-mail] 📞 Telefon: 073-444 54 77 Urval', `Telefon: ${M} Urval`],
    ['Ring Anna på +46 70 123 45 67', `Anna på ${M}`],
    // Netherlands
    ['App of bel Elize via +31 641186590 Een referentiecheck', `Elize via ${M} Een`],
    // United Kingdom (Teaching Vacancies)
    ['please contact the Principal’s PA, Zeenat Sparg, on 02476 392237 or email', `Sparg, on ${M} or email`],
    ['Call Sarah on 07700 900123.', `Sarah on ${M}.`],
    // United States (NYC Jobs)
    ['please contact Simone Campbell at [e-mail] or 212-676-6955. TO APPLY', `or ${M}. TO APPLY`],
    ['Questions? Call John Smith at (646) 555-0199.', `at ${M}.`],
    // France, Spain, Czechia, Ireland
    ['Contactez Mme Dupont au 06 12 34 56 78', `au ${M}`],
    ['Persona de contacto: Ana López, teléfono 612 34 56 78', `teléfono ${M}`.replace(M, '612 34 56 78')], // a Spanish national number without trunk 0 is left to the Spanish connectors' own mask
    ['Kontakt: +420 777 123 456', `Kontakt: ${M}`],
    ['Ring Mary on +353 87 123 4567', `on ${M}`],
  ])('%s', (input, expectedTail) => {
    expect(mask(input)).toContain(expectedTail);
  });
});

describe('institutional lines, and everything that is not a telephone number, are kept', () => {
  it.each([
    'Visits and school tours can be arranged by calling our school office on 01424 853521. Robsack Wood Primary School',
    'please contact our HR team by phone at (858) 201-7832 or via email at accommodation',
    'Bitte wenden Sie sich an unsere Zentrale unter 0221 123456-0',
    'Ring vår växel på 08-123 456 00',
    'Llame a la centralita al +34 91 123 45 67',
    // dates, times, amounts, references, postcodes, links
    'Sista ansökningsdag: 2026-10-22 Vi ser fram emot',
    'tillträde: 2026-09-13 , upphör: 2027-09-30 .',
    'Arbeitszeit 09.00-17.00 Uhr, Gehalt 3.500 EUR',
    'Salary £31,015 to £33,673 per annum',
    'Referenznummer 2026-2396500, Kennziffer 41/1344',
    'Postcode SW1A 1AA, 75004 Paris, 2026-10-16T12:00:00Z',
    'Apply at https://example.com/jobs/0123456789?ref=0049-123',
    'Kontonummer DE89 3704 0044 0532 0130 00',
    'ISBN 978-3-16-148410-0 and order 123-456-7890-12',
  ])('%s', (input) => {
    expect(mask(input)).toBe(input);
  });

  it('is idempotent and leaves the existing masks of other connectors alone', () => {
    const once = mask('Telefon: +49 421 43841 985 [teléfono] [telefon] [e-mail]');
    expect(mask(once)).toBe(once);
    expect(once).toContain('[teléfono] [telefon] [e-mail]');
  });

  it('a mobile number is masked even next to an institutional word', () => {
    expect(mask('Our office mobile: +49 171 2345678')).toContain(M);
    expect(mask('school office on 07700 900123', 'GB')).toContain(M);
    expect(mask('Zentrale: 0171 2345678', 'DE')).toContain(M);
  });
});

describe('the single storage point applies the guard to every source', () => {
  it('toJobRow masks a personal phone and e-mail from any connector, keeps the links and the institutional line', async () => {
    const { toJobRow } = await import('../src/sync');
    const row = toJobRow({
      source: 'arbeitnow', externalId: 'x1', company: 'ACME GmbH', title: 'Elektriker (m/w/d)', status: 'open', lastCheckedAt: '2026-10-16T00:00:00.000Z',
      description: 'Fragen? Herr Max Muster, Tel.: 0171 2345678, max.muster@gmail.com. Zentrale: 0221 123456-0. https://acme.example/jobs/1',
      country: 'DE', city: 'Köln', language: 'de', workMode: 'onsite', contractType: null, salaryMin: null, salaryMax: null, salaryCurrency: null, salaryPeriod: null,
      publishedAt: null, originalUrl: 'https://www.arbeitnow.com/jobs/x1', applyUrl: 'https://www.arbeitnow.com/jobs/x1', geoRestrictions: [], requirements: [], skills: [],
    });
    expect(row.description).not.toMatch(/2345678|max\.muster/);
    expect(row.description).toContain('Zentrale: 0221 123456-0');
    expect(row.description).toContain('https://acme.example/jobs/1');
    expect(row.original_url).toBe('https://www.arbeitnow.com/jobs/x1');
  });
});

describe('the words nearest to the number decide', () => {
  it('a switchboard named after a contact person is kept; a person named after the switchboard is masked', () => {
    expect(mask('Ansprechpartner Herr Max Muster. Zentrale: 0221 123456-0.')).toContain('Zentrale: 0221 123456-0');
    expect(mask('Zentrale oder direkt Herr Max Muster unter 0221 123456-12')).toContain(`unter ${M}`);
  });
});

describe('findings of the dry run over the stored catalogue (2026-10-16)', () => {
  it.each([
    'Pueden pasarse por la empresa del 28-09-2026 al 09-10-2026 en horario de mañana',
    'Ihr Kontakt Team-Recruiting Telefon: 0221 123456-0',
    'If you need assistance to fill out the online application, please let us know by calling 866-555-0100.',
    'please contact our Employee Relations team at candidateaccommodations@fastly.com or 415-555-0100.',
    'please reach out to accessibilityinfo@planning.nyc.gov or call 212-720-3300 at least',
    'Constant Contact Call toll free 1-877-293-2371',
    'Las personas interesadas: -Pueden pasarse por la empresa del 28-09-2026 al 02-10-20026 en horario de 9:00 a 14:00',
  ])('kept: %s', (input) => {
    expect(mask(input)).toBe(input);
  });

  it('the national mobile ranges follow the listing\'s country: 0161 is a Manchester landline, 0161 2345678 a German mobile', () => {
    const office = 'Please contact the school office directly to arrange an appointment on 0161 725 9750.';
    expect(mask(office, 'GB')).toBe(office);
    expect(mask('Zentrale unter 0161 2345678', 'DE')).toContain(M);
    expect(mask(office, null)).toBe(office); // unknown country: no national mobile rule, the institutional line stays
  });
});

describe('contacts that slipped through the first backfill (2026-10-16 audit of what was left)', () => {
  it.each([
    ['Vid frågor om tjänsten är du välkommen att kontakta: Elin Mingert: 072-225 95 06 Välkommen', 'SE', `Mingert: ${M} Välkommen`],
    ['Verksamhetschef Maria Fundberg, 0150-48 86 10. Fackliga', 'SE', `Fundberg, ${M}.`],
    ['Herr Pollmann (Amtsleitung): und Frau Löffler (Bewerbermanagement): +49 2206-602628 Ihre Aufgaben', 'DE', `(Bewerbermanagement): ${M} Ihre`],
  ])('%s', (input, country, tail) => {
    expect(mask(input, country)).toContain(tail);
  });

  it('institutional lines of the same audit stay', () => {
    for (const [t, c] of [
      ['Fackliga företrädare söks via kontaktcenter, 0155-24 50 00. Kom', 'SE'],
      ['Samtliga nås via vår växel, tel. 018-17 55 00. Sista', 'SE'],
      ['please don’t hesitate to contact our Recruitment Department at +31 (0) 20 488 9696. INDG', 'NL'],
      ['Gerne beantworten wir Ihre Fragen unter der Telefonnummer 0731 725660-87.', 'DE'],
      ['Please call us on 01283 247400 to arrange a visit', 'GB'],
    ] as const) expect(mask(t, c), t).toBe(t);
  });
});

describe('second dry run findings', () => {
  it('working hours and an institution named before the number stay; a person named after the institution is still masked', () => {
    for (const [t, c] of [
      ['Shifts Thursday and Saturday 1500-2300 Friday, Saturday, Sunday, Monday 0700-1530 Interested?', 'NZ'],
      ["Part of the Diocese of Norwich St Benet's MAT Tel: 01603 880853 Email", 'GB'],
    ] as const) expect(mask(t, c), t).toBe(t);
    expect(mask('Our school welcomes visits. Please contact Sasha Jamison on 01424 853521 to arrange', 'GB')).toContain(`Jamison on ${M}`);
    expect(mask('Vill du veta mer? Avdelningschef - Adrian Pourakbar 070-123 45 67, [e-mail]', 'SE')).toContain(`Pourakbar ${M}`);
    expect(mask('Fachliche*r Ansprechpartner*in: Christian Becker, 0214 406-1234 Rechtliche', 'DE')).toContain(`Becker, ${M}`);
  });
});
