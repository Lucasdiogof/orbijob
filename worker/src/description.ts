import { htmlToText } from './text';

/**
 * Job descriptions: HTML (or text with Markdown leftovers) -> clean plain text, with a privacy policy for e-mail addresses.
 * The same rules are mirrored in the Flutter app (app/lib/core/format/description_text.dart) so that records already stored
 * look right before any data correction; both are covered by the same table of cases.
 */

/** Residue of Markdown inside text that is otherwise plain: emphasis markers, rules, star bullets, headings, [text](url). */
export function tidyMarkdown(text: string): string {
  return text
    // [label](https://x) -> label (https://x); a bare "[label]" is left alone
    .replace(/\[([^\]\n]+)\]\((https?:\/\/[^)\s]+)\)/g, (_m, label: string, url: string) => (label.trim() === url ? url : `${label} (${url})`))
    // horizontal rules made of 3+ of the same symbol, alone on a line
    .replace(/^[ \t]*([_*=-])(?:[ \t]*\1){2,}[ \t]*$/gm, '')
    // "* item" / "+ item" bullets become the "- item" form used everywhere else
    .replace(/^([ \t]*)[*+][ \t]+(?=\S)/gm, '$1- ')
    // ATX headings: "## Title" -> "Title"
    .replace(/^[ \t]{0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$/gm, '$1')
    // paired emphasis, then orphan markers glued to a word edge (** or __ or *** at a line start / end of a word)
    .replace(/(\*\*\*|\*\*|__)(?=\S)([^\n]*?\S)\1/g, '$2')
    .replace(/(^|[\s(])(\*{2,3}|_{2,3})(?=\S)/gm, '$1')
    .replace(/(?<=\S)(\*{2,3}|_{2,3})(?=[\s.,;:!?)]|$)/gm, '')
    .replace(/[ \t]+$/gm, '')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/**
 * E-mail policy. A job text may legitimately name the employer's application or accommodation channel (careers@, recruiting@,
 * accommodations@ ...): that is a professional, role-based address and stays. Everything that cannot be shown to be role-based
 * is masked: a personal-looking address (name.surname@, any address on a free-mail provider, an address with digits) is personal
 * data of a recruiter or employee that the catalogue has no reason to republish. The original listing link is always kept.
 */
const FREE_MAIL = new Set([
  'gmail.com', 'googlemail.com', 'outlook.com', 'hotmail.com', 'live.com', 'msn.com', 'yahoo.com', 'ymail.com', 'icloud.com', 'me.com',
  'aol.com', 'proton.me', 'protonmail.com', 'gmx.com', 'gmx.net', 'mail.com', 'zoho.com', 'yandex.com', 'qq.com', '163.com',
  'uol.com.br', 'bol.com.br', 'terra.com.br', 'hotmail.com.br', 'outlook.com.br', 'yahoo.com.br',
]);
/** Long, unambiguous role words: recognised anywhere in the local part ("wwrecruitingteam", "candidate_accommodations"). */
const ROLE_LONG = [
  'career', 'recruit', 'talent', 'candidate', 'accommodat', 'accessib', 'applic', 'opportunit', 'staffing', 'employment', 'compliance',
  'internship', 'benefit', 'privacy', 'security', 'inclusion', 'diversity', 'belonging', 'workwithus',
];
/** Short words: only when they START a token of the local part (so "jane.doe" is never a role, "jobs" and "hr.support" are). */
const ROLE_SHORT = ['job', 'people', 'hiring', 'hire', 'apply', 'support', 'human', 'join', 'team', 'info', 'contact', 'hello', 'resume', 'campus', 'legal', 'ask'];
const ROLE_TOKENS = new Set(['hr']);
const EMAIL = /[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}/g;
export const MASKED_EMAIL = '[e-mail]';

export function isRoleAddress(address: string): boolean {
  const [local = '', domain = ''] = address.toLowerCase().split('@');
  if (!local || FREE_MAIL.has(domain)) return false;
  if (/\d/.test(local)) return false; // jane.doe84@ is a person
  const tokens = local.split(/[._+-]+/).filter(Boolean);
  if (tokens.some((t) => ROLE_TOKENS.has(t))) return true;
  if (ROLE_LONG.some((w) => local.includes(w))) return true;
  return tokens.some((t) => ROLE_SHORT.some((w) => t.startsWith(w)));
}

export function maskPersonalEmails(text: string): string {
  return text.replace(EMAIL, (a) => (isRoleAddress(a) ? a : MASKED_EMAIL));
}

/** Pipeline used for `jobs.description`. */
export function cleanDescription(html: string): string {
  return maskPersonalEmails(tidyMarkdown(htmlToText(html)));
}
