/** HTML from job sources is never stored or rendered as HTML: it is reduced to plain text here. */

const NAMED: Record<string, string> = {
  amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', ndash: '–', mdash: '—', hellip: '…',
  lsquo: '‘', rsquo: '’', ldquo: '“', rdquo: '”', bull: '•', middot: '·', copy: '©', reg: '®', trade: '™',
};

/** Decodes numeric and the common named entities, exactly once (`&amp;lt;` becomes the text `&lt;`). */
export function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#[0-9]+|[a-z][a-z0-9]*);/gi, (m, body: string) => {
    if (body[0] === '#') {
      const code = body[1]?.toLowerCase() === 'x' ? parseInt(body.slice(2), 16) : parseInt(body.slice(1), 10);
      return Number.isFinite(code) && code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : m;
    }
    return NAMED[body.toLowerCase()] ?? m;
  });
}

/** Removes markup (including script/style bodies and comments), keeps line breaks of block elements, decodes entities. */
export function htmlToText(html: string): string {
  const noCtl = (s: string) => s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '');
  const text = html
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<(script|style|iframe|object|embed|noscript)\b[\s\S]*?<\/\1\s*>/gi, ' ')
    .replace(/<li\b[^>]*>/gi, '\n- ')
    .replace(/<br\s*\/?>|<\/(p|div|ul|ol|h[1-6]|tr|table|section|article)\s*>/gi, '\n')
    .replace(/<[^>]*>/g, ' ');
  return noCtl(decodeEntities(text))
    .replace(/[ \t\f\v ]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** Single-line text for titles and names: entities decoded, tags dropped, whitespace collapsed. */
export function inlineText(s: string): string {
  return htmlToText(s).replace(/\s+/g, ' ').trim();
}
