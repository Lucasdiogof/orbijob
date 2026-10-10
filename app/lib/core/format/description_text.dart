/// Display cleanup for job descriptions. The Worker applies the same rules when it stores a description
/// (worker/src/description.ts); doing it here too means records stored BEFORE that rule existed read correctly and do not show
/// personal e-mail addresses, without any change to the database. Both sides are checked against the same table of cases.
library;

const maskedEmail = '[e-mail]';

final _doubleEncoded = RegExp(
  r'&amp;(amp|quot|apos|nbsp|#0*39|#x0*27|#0*38|#x0*26);',
  caseSensitive: false,
);
final _punctEntity = RegExp(
  r'&(amp|quot|apos|nbsp|#0*39|#x0*27|#0*38|#x0*26);',
  caseSensitive: false,
);
final _invisible = RegExp('[​-‍⁠﻿]');

String _decodeEntities(String s) {
  // Only punctuation is decoded here (never "<" or ">"), and only what a double-encoding source leaves behind.
  final once = s.replaceAllMapped(_doubleEncoded, (m) => '&${m[1]};');
  return once.replaceAllMapped(_punctEntity, (m) {
    final b = m[1]!.toLowerCase();
    if (b == 'amp' || RegExp(r'^#0*38$|^#x0*26$').hasMatch(b)) return '&';
    if (b == 'quot') return '"';
    if (b == 'nbsp') return ' ';
    return "'";
  });
}

/// Markdown residue inside text that is otherwise plain: emphasis markers, rules, star bullets, headings, [label](url).
String tidyMarkdown(String text) {
  var t = text;
  t = t.replaceAllMapped(
    RegExp(r'\[([^\]\n]+)\]\((https?://[^)\s]+)\)'),
    (m) => m[1]!.trim() == m[2] ? m[2]! : '${m[1]} (${m[2]})',
  );
  // horizontal rules: 3+ of the same symbol alone on a line
  t = t.replaceAll(
    RegExp(r'^[ \t]*([_*=-])(?:[ \t]*\1){2,}[ \t]*$', multiLine: true),
    '',
  );
  // "* item" / "+ item" -> "- item"
  t = t.replaceAllMapped(
    RegExp(r'^([ \t]*)[*+][ \t]+(?=\S)', multiLine: true),
    (m) => '${m[1]}- ',
  );
  // ATX headings
  t = t.replaceAllMapped(
    RegExp(r'^[ \t]{0,3}#{1,6}[ \t]+(.+?)[ \t]*#*[ \t]*$', multiLine: true),
    (m) => m[1]!,
  );
  // paired emphasis, then orphan markers at a word edge
  t = t.replaceAllMapped(
    RegExp(r'(\*\*\*|\*\*|__)(?=\S)([^\n]*?\S)\1'),
    (m) => m[2]!,
  );
  t = t.replaceAllMapped(
    RegExp(r'(^|[\s(])(?:\*{2,3}|_{2,3})(?=\S)', multiLine: true),
    (m) => m[1]!,
  );
  t = t.replaceAllMapped(
    RegExp(r'(\S)(?:\*{2,3}|_{2,3})(?=[\s.,;:!?)]|$)', multiLine: true),
    (m) => m[1]!,
  );
  t = t.replaceAll(RegExp(r'[ \t]+$', multiLine: true), '');
  t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return t.trim();
}

const _freeMail = {
  'gmail.com',
  'googlemail.com',
  'outlook.com',
  'hotmail.com',
  'live.com',
  'msn.com',
  'yahoo.com',
  'ymail.com',
  'icloud.com',
  'me.com',
  'aol.com',
  'proton.me',
  'protonmail.com',
  'gmx.com',
  'gmx.net',
  'mail.com',
  'zoho.com',
  'yandex.com',
  'qq.com',
  '163.com',
  'uol.com.br',
  'bol.com.br',
  'terra.com.br',
  'hotmail.com.br',
  'outlook.com.br',
  'yahoo.com.br',
};
// Long, unambiguous role words are recognised anywhere in the local part; short ones only at the start of a token.
const _roleLong = [
  'career',
  'recruit',
  'talent',
  'candidate',
  'accommodat',
  'accessib',
  'applic', //
  'opportunit', 'staffing', 'employment', 'compliance', 'internship', 'benefit',
  'privacy', 'security', 'inclusion', 'diversity', 'belonging', 'workwithus',
];
const _roleShort = [
  'job', 'people', 'hiring', 'hire', 'apply', 'support', 'human', 'join', //
  'team', 'info', 'contact', 'hello', 'resume', 'campus', 'legal', 'ask',
];
final _email = RegExp(
  r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}',
);

/// A professional, role-based address (careers@, accommodations@, hr.support@ ...). Anything that cannot be shown to be
/// role-based (a person's name, digits, a free-mail provider) is treated as personal.
bool isRoleAddress(String address) {
  final parts = address.toLowerCase().split('@');
  final local = parts.first;
  final domain = parts.length > 1 ? parts[1] : '';
  if (local.isEmpty || _freeMail.contains(domain)) return false;
  if (RegExp(r'\d').hasMatch(local)) return false;
  final tokens = local.split(RegExp(r'[._+-]+')).where((t) => t.isNotEmpty);
  if (tokens.contains('hr')) return true;
  if (_roleLong.any(local.contains)) return true;
  return tokens.any((t) => _roleShort.any(t.startsWith));
}

String maskPersonalEmails(String text) => text.replaceAllMapped(
  _email,
  (m) => isRoleAddress(m[0]!) ? m[0]! : maskedEmail,
);

/// Everything the detail screen needs to show a stored description safely and legibly.
String cleanDescriptionText(String raw) {
  var t = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  t = t.replaceAll(_invisible, '');
  t = _decodeEntities(t);
  return maskPersonalEmails(tidyMarkdown(t));
}
