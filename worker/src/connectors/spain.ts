import { inlineText } from '../text';
import { placeName } from './bpce';

/** Helpers shared by the Spanish regional employment-service sources (Murcia, Catalonia, Castilla y León, Basque Country). */

/** Spanish telephone numbers: 6xx/7xx/8xx/9xx in any grouping, optionally +34 / 0034. */
export const ES_PHONE = /(?<![0-9])(?:(?:\+|00)34[\s.-]?)?[6-9][0-9](?:[\s.-]?[0-9]){7}(?![0-9])/g;

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
