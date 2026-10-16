/**
 * Telephone numbers in job descriptions (13.0 privacy standard, applied to EVERY source at the single storage point, `toJobRow`).
 *
 * Audit of the published catalogue (2026-10-16): the numbers left in the texts are overwhelmingly a named person's direct line or mobile ("reach out to Alina by
 * phone +49 89 …", "kontakta Frida Borg på 040-608 76 01", "Herr Becker, Tel.: 02238/808-190", "Mobil: +49 173 …"); a minority is an institution's public line
 * ("calling our school office on 01424 853521", "our HR team by phone at (858) 201-7832"). The rule:
 *   * a MOBILE number is always masked (it belongs to a person);
 *   * a number whose preceding words name a person (an honorific, or "contact/kontakta/reach out to" followed by a name) is masked;
 *   * a number whose preceding words name only an institutional line (school office, reception, switchboard, HR team, Zentrale, växel, centralita, accueil…) is KEPT:
 *     it is public business information and helps the applicant;
 *   * any other number is masked (the official listing, always linked, still carries it).
 * Dates, times, amounts, references and links are never touched: national numbers are only recognised next to a telephone word, international ones by their
 * country code, North-American ones by their fixed 3-3-4 shape. Masking is idempotent and never logs the number.
 */

export const MASKED_PHONE = '[tel.]';

/** +CC / 00CC followed by digit groups. */
const INTL = String.raw`(?<![\w+])(?:\+|\b00)[1-9]\d{0,2}(?:[ \t./-]{0,2}\(?\d{1,5}\)?){2,7}(?![\d])`;
/** North-American numbers: (212) 555-1234, 212-555-1234, 212.555.1234. */
const NANP = String.raw`(?<![\w(+-])(?:\(\d{3}\)[ \t]?|\d{3}[.-])\d{3}[.-]\d{4}(?![\d-])`;
/** National numbers with a trunk 0 (0179 / 12 92 419, 040-608 76 01, 02238/808-190, 01283 247800): only right after a telephone word (see TEL_WORD). */
const NATIONAL = String.raw`(?<![\w])0[1-9]\d{0,4}(?:[ \t]?[/-][ \t]?|[ \t]|\.)\d{2,8}(?:[ \t.-]\d{1,6}){0,4}(?![\w])`;
const CANDIDATE = new RegExp(`${INTL}|${NANP}|${NATIONAL}`, 'g');

/** Words that announce a telephone number, in the catalogue's languages. */
const TEL_WORD = /(?:tel|phone|telefon|téléphone|telèfon|teléfono|telefone|call|calling|ring|ruf|fon|mobil|mobile|cell|handy|contact|kontakt|ansprech|nå|nås|nummer|number|número|numero|nr|appel|llam|whatsapp|sms|bel|📞|☎|on|på|unter|at|au|al|zentrale|telefonzentrale|sekretariat|empfang|reception|switchboard|office|växel|växeln|centralita|recepción|secretaría|accueil|standard|hotline|helpline)\W{0,6}$/iu;
const WINDOW = 80;

/** A person named in the words before the number. */
const PERSON = [
  /\b(?:Herr|Frau|Mr|Mrs|Ms|Miss|Dr|Prof|Mme|M|Sr|Sra|Dña|Don|Fru|Pan|Paní)\.?\s+\p{Lu}\p{Ll}+/u,
  /\b(?:contact|kontakta|kontaktieren Sie|reach out to|speak to|talk to|ask for|wenden Sie sich an|melde dich bei|bel|app|ring|ruf|call|phone|contacte con|contactar con|appelez|joindre)\s+\p{Lu}\p{Ll}+(?:\s+\p{Lu}\p{Ll}+)?\b(?!\s+(?:School|Office|Team|Academy|College|Trust|Service|Department|Group|AB|GmbH|Ltd|Inc))/u,
  /\b(?:Ansprechperson|Ansprechpartner(?:in)?|contact person|kontaktperson|persona de contacto|personne à contacter)\b/iu,
];
/** A person's name written right before the number ("Elin Mingert: 072-…", "Maria Fundberg, 0150-…"): two capitalised words, then at most ": " or ", ". */
const NAME_RIGHT_BEFORE = /\p{Lu}\p{Ll}+(?:[ -]\p{Lu}\p{Ll}+)+\s*[,:]?\s*$/u;
/** Words that are capitalised in German or Swedish but are not names: a pair of them before a number is not a person. */
const NOT_A_NAME = /\b(?:Ihre|Ihr|Unsere|Unser|Telefon|Telefonnummer|Rufnummer|Mobil|Fax|Zentrale|Sekretariat|Kontakt|Ansprechperson|Ansprechpartner|Team|Abteilung|Personalabteilung|Recruiting|School|Office|Trust|Academy|College|Department|Service|Services|Group|GmbH|AB|Ltd|Inc|Stadt|Kreis|Gemeinde|Region|Kommun|Universität|University|Hospital|Klinik|Kontaktcenter|Kundtjänst|Växel)\b/u;
/** A person named this close to the number decides, even if an institutional word follows ("Frau Löffler (Bewerbermanagement): +49 …"). */
const PERSON_NEAR = 30;

/** Institutional lines: public business information, kept when no person is named. */
const INSTITUTION = /(?:[\w.+-]+@[\w-]+(?:\.[\w-]+)+|\b(?:wir|uns|we|us|vi|oss|nosotros|nous|let us know|contact us|call us|reach us|ring us|kontaktieren Sie uns|ruf uns an|ring oss|kontakta oss|contacta con nosotros|llámanos|contactez-nous|appelez-nous|toll[ -]free|(?:relations|accommodations?|recruiting|recruitment|talent|people|support|service|help|candidate) (?:team|desk|line|department|office)|team[ -]recruiting|recruiting[ -]team|personalservice|bewerbermanagement|school office|the office|our office|main office|front desk|reception|switchboard|main line|HR team|HR department|human resources|recruitment team|recruitment office|admissions|helpline|hotline|customer service|Zentrale|Telefonzentrale|Empfang|Sekretariat|Servicecenter|växel|växeln|kundtjänst|kundservice|reception|centralita|recepción|secretaría|accueil|standard|ústředna|sekretariát|kontaktcenter|kontaktcentret|school|academy|trust|MAT|college|university|council|kommun|kommunen|region|regionen|gemeinde|stadt|landkreis|hospital|klinik|sjukhus|ayuntamiento|mairie)\b)/iu;

/** National mobile prefixes (trunk 0) by the listing's country: the same digits are a landline elsewhere (0161 is Manchester, 016x a German mobile). */
const NATIONAL_MOBILE: Record<string, RegExp> = {
  DE: /^01[5-7]/, AT: /^06[5-9]/, CH: /^07[5-9]/, GB: /^07/, IE: /^08[3-9]/, SE: /^07/, NO: /^0?[49]/, NL: /^06/, BE: /^04[5-9]/, FR: /^0[67]/,
  NZ: /^02/, AU: /^04/,
};

/** Mobile ranges of the catalogue's countries: always a person's line. International numbers carry their country; national ones use the listing's. */
function isMobile(raw: string, country: string | null): boolean {
  const d = raw.replace(/[^\d+]/g, '').replace(/^00/, '+');
  if (d.startsWith('+')) {
    return /^\+49(?:15|16|17)|^\+46(?:7[02369])|^\+447|^\+316|^\+33[67]|^\+34[67]|^\+420[67]|^\+43(?:6[5-9])|^\+417[5-9]|^\+353(?:8[3-9])|^\+32(?:4[5-9])|^\+64(?:2)|^\+61(?:4)/.test(d);
  }
  const rule = country ? NATIONAL_MOBILE[country] : undefined;
  return !!rule && rule.test(d);
}

const digits = (s: string) => s.replace(/\D/g, '').length;

/** Start (or end) of the last match of `re` in `s`, or -1. */
function lastIndex(re: RegExp, s: string, end = false): number {
  const g = new RegExp(re.source, re.flags.includes('g') ? re.flags : `${re.flags}g`);
  let last = -1;
  for (const m of s.matchAll(g)) last = (m.index ?? 0) + (end ? m[0].length : 0);
  return last;
}

/** A name right before the number that is not a pair of ordinary capitalised nouns. */
function nameRightBefore(before: string): boolean {
  const m = NAME_RIGHT_BEFORE.exec(before);
  return !!m && !NOT_A_NAME.test(m[0]);
}

/** Replaces the telephone numbers that may identify a person by [MASKED_PHONE]; keeps institutional lines. `country`: the listing's (ISO alpha-2), for national mobile ranges. */
export function maskPersonalPhones(text: string, country: string | null = null): string {
  if (!text || !/\d\D?\d/.test(text)) return text;
  return text.replace(CANDIDATE, (m: string, offset: number) => {
    const raw = m.trim();
    const n = digits(raw);
    const intl = /^(?:\+|00)/.test(raw);
    const nanp = !intl && !raw.startsWith('0');
    if (n < 7 || n > 15 || (intl && n < 8)) return m;
    if (/^\d{1,2}[./-]\d{1,2}[./-]\d{2,5}\b/.test(raw)) return m; // a date (09-10-2026, 01.11.2026, even the typo 02-10-20026), never a number
    if (/^(?:[01]\d|2[0-3])[.:]?[0-5]\d\s?[-–]\s?(?:[01]\d|2[0-3])[.:]?[0-5]\d$/.test(raw)) return m; // working hours (0700-1530, 08.00-16.30)
    const before = text.slice(Math.max(0, offset - WINDOW), offset);
    const line = before.split('\n').pop() ?? before; // the same line (not cut at "." : "Dr. Müller" must stay whole)
    const named = nameRightBefore(before);
    const mobile = isMobile(raw, country);
    // a national-looking run, or a "00" prefix (also the start of IBAN groups: DE89 3704 0044 ...), counts only after a telephone word, right after a
    // person's name, or when it is a mobile number of the listing's country
    if ((!intl || raw.startsWith('00')) && !nanp && !TEL_WORD.test(before.trimEnd()) && !named && !mobile) return m;
    if (mobile || named) return MASKED_PHONE;
    // the words nearest to the number decide: an institutional line named AFTER the last person ("… Herr Muster. Zentrale: 0221 …") is kept
    const lastPerson = Math.max(-1, ...PERSON.map((r) => lastIndex(r, line)));
    const personEnd = Math.max(-1, ...PERSON.map((r) => lastIndex(r, line, true)));
    // an institutional word inside parentheses is a person's role ("Frau Löffler (Bewerbermanagement)"), not a line of its own
    const outsideParens = line.replace(/\([^()]*\)/g, (x) => ' '.repeat(x.length));
    const lastInstitution = lastIndex(INSTITUTION, outsideParens);
    if (personEnd >= 0 && line.length - personEnd <= PERSON_NEAR && lastInstitution < personEnd) return MASKED_PHONE;
    if (lastInstitution > lastPerson) return m;
    return MASKED_PHONE;
  });
}
