import { inlineText } from '../text';
import { placeName } from './bpce';

/** Helpers shared by the Spanish regional employment-service sources (Murcia, Catalonia, Castilla y León, Basque Country). */

/** Spanish telephone numbers: 6xx/7xx/8xx/9xx in any grouping, optionally +34 / 0034. */
export const ES_PHONE = /(?<![0-9])(?:(?:\+|00)34[\s.-]?)?[6-9][0-9](?:[\s.-]?[0-9]){7}(?![0-9])/g;

/**
 * Telephone numbers of other countries written with their country code (`+45 93 57 62 51`, `+43 555263380`, `0049 89 4378031`), as the EURES offers abroad
 * carry them: 8 to 15 digits after `+`/`00` and the code. Amounts ("17.000 - 18.000") and references have no `+`/`00` prefix and are untouched.
 */
export const INTL_PHONE = /(?<![\w+])(?:\+|\b00)[1-9][0-9]{0,2}(?:[\s.-]?\(?[0-9]{1,5}\)?){2,6}(?![0-9])/g;

/** Every telephone number of a Spanish offer's text, Spanish or foreign, replaced by `label`. */
export function maskPhones(text: string, label: string): string {
  return text.replace(INTL_PHONE, (m) => (m.replace(/\D/g, '').length >= 8 ? label : m)).replace(ES_PHONE, label);
}

const SMALL_WORDS = /(?<=\S)\s(De|Del|Dels|Della|La|Las|Les|Los|El|Els|I|Y)(?=\s|$)/g;

/**
 * Towns come upper-case and, for names that start with an article, inverted by the INE or Catalan style ("ALCAZARES, LOS", "HOSPITALET DE LLOBREGAT, L'"): they are put
 * back in reading order ("Los Alcazares", "L'Hospitalet de Llobregat") and the small words are lower-cased ("Cornellà del Terri"). A name already in mixed case is untouched.
 */
export function townName(raw: string): string {
  const text = inlineText(raw);
  const m = /^(.+?),\s*(l['’]|el|la|els|les|los|las)$/i.exec(text);
  const upper = (s: string) => (s === s.toUpperCase() ? s : s.toUpperCase());
  const base = m ? (m[2]!.endsWith("'") || m[2]!.endsWith('’') ? `${m[2]!}${m[1]!}` : `${m[2]!} ${m[1]!}`) : text;
  const cased = placeName(m ? upper(base) : base);
  return cased
    .replace(SMALL_WORDS, (_x, w: string) => ` ${w.toLowerCase()}`)
    .replace(/\b(L)(['’])([a-zà-ÿ])/g, (_x, l: string, q: string, c: string) => `${l}${q}${c.toUpperCase()}`);
}

/** dd/mm/yyyy -> yyyy-mm-dd, or '' when it is not a real date. */
export function isoDay(s: string): string {
  const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(s.trim());
  if (!m) return '';
  const iso = `${m[3]}-${m[2]}-${m[1]}`;
  const d = new Date(`${iso}T00:00:00Z`);
  return Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === iso ? iso : '';
}
