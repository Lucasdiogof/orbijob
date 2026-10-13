import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Why a PDF yielded (or did not yield) text. The caller must be honest with the user about everything except [ok].
enum PdfTextStatus {
  /// Text was read.
  ok,

  /// Valid PDF without a text layer: typically a scan or a photo. Needs OCR, which this app does not do.
  noTextLayer,

  /// Password-protected: the content cannot be read without the password.
  encrypted,

  /// Text exists but cannot be decoded (unusual fonts/filters) or the file is damaged.
  unreadable,
}

class PdfTextResult {
  const PdfTextResult(this.status, [this.text = '', this.pages = 0]);
  final PdfTextStatus status;

  /// Lines separated by `\n`; empty unless [status] is [PdfTextStatus.ok].
  final String text;
  final int pages;
}

/// Reads the text of a PDF on the device, in pure Dart (no network, no service). It understands the structures that
/// word processors, Google Docs, LibreOffice and browsers produce: classic and compressed (object stream) files,
/// Flate/ASCIIHex/ASCII85 filters, simple fonts and Type0 fonts with a ToUnicode map, and form XObjects.
/// It does not do OCR, so scanned documents report [PdfTextStatus.noTextLayer].
PdfTextResult extractPdfText(Uint8List bytes) {
  try {
    return _Extractor(bytes).run();
  } catch (_) {
    return const PdfTextResult(PdfTextStatus.unreadable);
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Object model

class _Name {
  const _Name(this.v);
  final String v;
  @override
  bool operator ==(Object o) => o is _Name && o.v == v;
  @override
  int get hashCode => v.hashCode;
}

class _Ref {
  const _Ref(this.n);
  final int n;
}

class _Op {
  const _Op(this.v);
  final String v;
}

class _Str {
  const _Str(this.bytes);
  final List<int> bytes;
}

class _Obj {
  _Obj(this.value, [this.stream]);
  final Object? value;
  final Uint8List? stream;
}

bool _isWs(int c) =>
    c == 0 || c == 9 || c == 10 || c == 12 || c == 13 || c == 32;
bool _isDelim(int c) =>
    c == 0x28 || // (
    c == 0x29 || // )
    c == 0x3C || // <
    c == 0x3E || // >
    c == 0x5B || // [
    c == 0x5D || // ]
    c == 0x7B || // {
    c == 0x7D || // }
    c == 0x2F || // /
    c == 0x25; // %

/// Tokenises both object syntax and content streams (operators come back as [_Op]).
class _Lexer {
  _Lexer(this.b, [this.pos = 0]);
  final Uint8List b;
  int pos;

  bool get atEnd {
    _skipWs();
    return pos >= b.length;
  }

  void _skipWs() {
    while (pos < b.length) {
      final c = b[pos];
      if (_isWs(c)) {
        pos++;
      } else if (c == 0x25) {
        while (pos < b.length && b[pos] != 10 && b[pos] != 13) {
          pos++;
        }
      } else {
        break;
      }
    }
  }

  /// Next value: number, name, string, array, dict, or [_Op] for a bare keyword. Null at the end.
  Object? next() {
    _skipWs();
    if (pos >= b.length) return null;
    final c = b[pos];
    if (c == 0x2F) return _name();
    if (c == 0x28) return _literal();
    if (c == 0x3C) {
      if (pos + 1 < b.length && b[pos + 1] == 0x3C) {
        pos += 2;
        return _dict();
      }
      return _hex();
    }
    if (c == 0x5B) {
      pos++;
      return _array();
    }
    if (c == 0x5D || c == 0x3E || c == 0x29 || c == 0x7B || c == 0x7D) {
      pos++;
      return _Op(String.fromCharCode(c));
    }
    final start = pos;
    while (pos < b.length && !_isWs(b[pos]) && !_isDelim(b[pos])) {
      pos++;
    }
    final word = latin1.decode(b.sublist(start, pos));
    final n = num.tryParse(word);
    if (n != null) return n;
    return _Op(word);
  }

  _Name _name() {
    pos++;
    final out = StringBuffer();
    while (pos < b.length && !_isWs(b[pos]) && !_isDelim(b[pos])) {
      var c = b[pos];
      if (c == 0x23 && pos + 2 < b.length) {
        final h = int.tryParse(
          latin1.decode(b.sublist(pos + 1, pos + 3)),
          radix: 16,
        );
        if (h != null) {
          c = h;
          pos += 2;
        }
      }
      out.writeCharCode(c);
      pos++;
    }
    return _Name(out.toString());
  }

  _Str _literal() {
    pos++;
    final out = <int>[];
    var depth = 1;
    while (pos < b.length) {
      final c = b[pos++];
      if (c == 0x5C) {
        if (pos >= b.length) break;
        final e = b[pos++];
        switch (e) {
          case 0x6E:
            out.add(10);
          case 0x72:
            out.add(13);
          case 0x74:
            out.add(9);
          case 0x62:
            out.add(8);
          case 0x66:
            out.add(12);
          case 0x0D:
            if (pos < b.length && b[pos] == 0x0A) pos++;
          case 0x0A:
            break;
          default:
            if (e >= 0x30 && e <= 0x37) {
              var v = e - 0x30;
              for (var i = 0; i < 2; i++) {
                if (pos < b.length && b[pos] >= 0x30 && b[pos] <= 0x37) {
                  v = v * 8 + (b[pos++] - 0x30);
                } else {
                  break;
                }
              }
              out.add(v & 0xFF);
            } else {
              out.add(e);
            }
        }
      } else if (c == 0x28) {
        depth++;
        out.add(c);
      } else if (c == 0x29) {
        depth--;
        if (depth == 0) break;
        out.add(c);
      } else {
        out.add(c);
      }
    }
    return _Str(out);
  }

  _Str _hex() {
    pos++;
    final digits = <int>[];
    while (pos < b.length && b[pos] != 0x3E) {
      final h = int.tryParse(String.fromCharCode(b[pos]), radix: 16);
      if (h != null) digits.add(h);
      pos++;
    }
    pos++;
    if (digits.length.isOdd) digits.add(0);
    return _Str([
      for (var i = 0; i < digits.length; i += 2) digits[i] * 16 + digits[i + 1],
    ]);
  }

  List<Object?> _array() {
    final out = <Object?>[];
    while (true) {
      final v = next();
      if (v == null || (v is _Op && v.v == ']')) break;
      _push(out, v);
    }
    return out;
  }

  Map<String, Object?> _dict() {
    final out = <String, Object?>{};
    final items = <Object?>[];
    while (true) {
      final v = next();
      if (v == null) break;
      if (v is _Op && v.v == '>') {
        // the second '>' of '>>'
        _skipWs();
        if (pos < b.length && b[pos] == 0x3E) pos++;
        break;
      }
      _push(items, v);
    }
    for (var i = 0; i + 1 < items.length; i += 2) {
      final k = items[i];
      if (k is _Name) out[k.v] = items[i + 1];
    }
    return out;
  }

  /// Adds [v] to [list], folding "n g R" into a [_Ref].
  void _push(List<Object?> list, Object? v) {
    if (v is _Op && v.v == 'R' && list.length >= 2) {
      final g = list[list.length - 1];
      final n = list[list.length - 2];
      if (n is num && g is num) {
        list.removeLast();
        list.removeLast();
        list.add(_Ref(n.toInt()));
        return;
      }
    }
    list.add(v);
  }

  /// Reads one object value starting at [pos] (folds references).
  Object? value() {
    final tmp = <Object?>[];
    final v = next();
    if (v == null) return null;
    _push(tmp, v);
    // possible "n g R": peek two more tokens
    if (v is num) {
      final save = pos;
      final g = next();
      final r = next();
      if (g is num && r is _Op && r.v == 'R') return _Ref(v.toInt());
      pos = save;
    }
    return tmp.first;
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Fonts

class _Font {
  _Font(
    this.toUnicode,
    this.codeBytes, {
    required this.decodable,
    this.widths = const {},
    this.defaultWidth = 500,
  });
  final Map<int, String>? toUnicode;
  final int codeBytes;
  final bool decodable;

  /// Glyph advance per character code, in 1/1000 of the font size (from /Widths or /W).
  final Map<int, double> widths;
  final double defaultWidth;

  double width(int code) => widths[code] ?? defaultWidth;
}

const _winAnsiHigh = <int, int>{
  0x80: 0x20AC,
  0x82: 0x201A,
  0x83: 0x0192,
  0x84: 0x201E,
  0x85: 0x2026,
  0x86: 0x2020,
  0x87: 0x2021,
  0x88: 0x02C6,
  0x89: 0x2030,
  0x8A: 0x0160,
  0x8B: 0x2039,
  0x8C: 0x0152,
  0x8E: 0x017D,
  0x91: 0x2018,
  0x92: 0x2019,
  0x93: 0x201C,
  0x94: 0x201D,
  0x95: 0x2022,
  0x96: 0x2013,
  0x97: 0x2014,
  0x98: 0x02DC,
  0x99: 0x2122,
  0x9A: 0x0161,
  0x9B: 0x203A,
  0x9C: 0x0153,
  0x9E: 0x017E,
  0x9F: 0x0178,
};

// ---------------------------------------------------------------------------------------------------------------------

class _Extractor {
  _Extractor(this.bytes);
  final Uint8List bytes;
  final objects = <int, _Obj>{};
  var _undecodable = 0;
  var _decoded = 0;

  PdfTextResult run() {
    final head = latin1.decode(
      bytes.sublist(0, bytes.length < 1024 ? bytes.length : 1024),
    );
    if (!head.contains('%PDF-')) {
      return const PdfTextResult(PdfTextStatus.unreadable);
    }
    _scanObjects();
    final src = latin1.decode(bytes, allowInvalid: true);
    if (src.contains('/Encrypt')) {
      return const PdfTextResult(PdfTextStatus.encrypted);
    }
    final pages = _pages();
    if (pages.isEmpty) return const PdfTextResult(PdfTextStatus.unreadable);
    final out = StringBuffer();
    var hadContent = false;
    for (final p in pages) {
      final text = _pageText(p);
      if (text != null) hadContent = true;
      if (text != null && text.trim().isNotEmpty) out.writeln(text);
    }
    final text = _normalise(out.toString());
    final letters = RegExp(r'\p{L}', unicode: true).allMatches(text).length;
    if (letters < 25) {
      // content streams existed but nothing printable: scans are images, so there is nothing to decode
      return PdfTextResult(
        _undecodable > 0 && hadContent
            ? PdfTextStatus.unreadable
            : PdfTextStatus.noTextLayer,
        '',
        pages.length,
      );
    }
    if (_decoded > 0 && _undecodable > _decoded) {
      return PdfTextResult(PdfTextStatus.unreadable, '', pages.length);
    }
    return PdfTextResult(PdfTextStatus.ok, text, pages.length);
  }

  // ---- parsing ----

  void _scanObjects() {
    final re = RegExp(r'(\d+)\s+(\d+)\s+obj\b');
    final src = latin1.decode(bytes, allowInvalid: true);
    var from = 0;
    while (true) {
      final m = re.matchAsPrefix(src, from) ?? _find(re, src, from);
      if (m == null) break;
      final n = int.parse(m.group(1)!);
      final lx = _Lexer(bytes, m.end);
      final value = lx.value();
      Uint8List? stream;
      var end = lx.pos;
      lx._skipWs();
      if (lx.pos + 6 <= bytes.length &&
          latin1.decode(bytes.sublist(lx.pos, lx.pos + 6)) == 'stream') {
        var s = lx.pos + 6;
        if (s < bytes.length && bytes[s] == 13) s++;
        if (s < bytes.length && bytes[s] == 10) s++;
        final e = src.indexOf('endstream', s);
        if (e < 0) {
          from = lx.pos;
          continue;
        }
        var stop = e;
        // Prefer the declared /Length (compressed data may legitimately end in a CR or LF byte); fall back to trimming.
        final declared = value is Map ? value['Length'] : null;
        if (declared is num &&
            s + declared.toInt() <= e &&
            e - (s + declared.toInt()) <= 2) {
          stop = s + declared.toInt();
        } else {
          while (stop > s && (bytes[stop - 1] == 10 || bytes[stop - 1] == 13)) {
            stop--;
          }
        }
        stream = Uint8List.sublistView(bytes, s, stop);
        end = e + 9;
      }
      objects[n] = _Obj(value, stream);
      from = end;
    }
    // compressed objects
    for (final o in objects.values.toList()) {
      final v = o.value;
      if (v is Map && _name(v['Type']) == 'ObjStm' && o.stream != null) {
        final data = _decode(v, o.stream!);
        if (data == null) continue;
        final count = _int(v['N']) ?? 0;
        final first = _int(v['First']) ?? 0;
        final head = _Lexer(data);
        final pairs = <(int, int)>[];
        for (var i = 0; i < count; i++) {
          final a = head.next();
          final b2 = head.next();
          if (a is num && b2 is num) pairs.add((a.toInt(), b2.toInt()));
        }
        for (final (num2, off) in pairs) {
          final inner = _Lexer(data, first + off);
          objects.putIfAbsent(num2, () => _Obj(inner.value()));
        }
      }
    }
  }

  RegExpMatch? _find(RegExp re, String src, int from) {
    for (final m in re.allMatches(src, from)) {
      return m;
    }
    return null;
  }

  Object? _resolve(Object? v) {
    var i = 0;
    while (v is _Ref && i++ < 20) {
      v = objects[v.n]?.value;
    }
    return v;
  }

  String? _name(Object? v) {
    final r = _resolve(v);
    return r is _Name ? r.v : null;
  }

  int? _int(Object? v) {
    final r = _resolve(v);
    return r is num ? r.toInt() : null;
  }

  Map<String, Object?>? _dictOf(Object? v) {
    final r = _resolve(v);
    return r is Map<String, Object?> ? r : null;
  }

  Uint8List? _decode(Map dict, Uint8List data) {
    final f = _resolve(dict['Filter']);
    final filters = f == null
        ? const <String>[]
        : f is List
        ? [for (final x in f) _name(x) ?? '']
        : [_name(f) ?? ''];
    var cur = Uint8List.fromList(data);
    for (final name in filters) {
      switch (name) {
        case 'FlateDecode' || 'Fl':
          try {
            cur = Uint8List.fromList(const ZLibDecoder().decodeBytes(cur));
          } catch (_) {
            return null;
          }
        case 'ASCIIHexDecode' || 'AHx':
          final lx = _Lexer(Uint8List.fromList([0x3C, ...cur, 0x3E]));
          cur = Uint8List.fromList((lx.next() as _Str).bytes);
        case 'ASCII85Decode' || 'A85':
          cur = _ascii85(cur);
        default:
          return null; // DCT/CCITT/JBIG2 etc. are images, not text
      }
    }
    return cur;
  }

  Uint8List _ascii85(Uint8List d) {
    final out = <int>[];
    final grp = <int>[];
    var i = 0;
    if (d.length > 1 && d[0] == 0x3C && d[1] == 0x7E) i = 2;
    for (; i < d.length; i++) {
      final c = d[i];
      if (c == 0x7E) break;
      if (_isWs(c)) continue;
      if (c == 0x7A && grp.isEmpty) {
        out.addAll([0, 0, 0, 0]);
        continue;
      }
      grp.add(c - 33);
      if (grp.length == 5) {
        var v = 0;
        for (final g in grp) {
          v = v * 85 + g;
        }
        out.addAll([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]);
        grp.clear();
      }
    }
    if (grp.length > 1) {
      final n = grp.length;
      while (grp.length < 5) {
        grp.add(84);
      }
      var v = 0;
      for (final g in grp) {
        v = v * 85 + g;
      }
      final full = [(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255];
      out.addAll(full.take(n - 1));
    }
    return Uint8List.fromList(out);
  }

  // ---- pages ----

  List<Map<String, Object?>> _pages() {
    Map<String, Object?>? catalog;
    for (final o in objects.values) {
      final v = o.value;
      if (v is Map<String, Object?> && _name(v['Type']) == 'Catalog') {
        catalog = v;
      }
    }
    final result = <Map<String, Object?>>[];
    void walk(Object? node, Map<String, Object?>? inherited, int depth) {
      if (depth > 40) return;
      final d = _dictOf(node);
      if (d == null) return;
      final res = d['Resources'] ?? inherited?['Resources'];
      final merged = {'Resources': res};
      final type = _name(d['Type']);
      final kids = _resolve(d['Kids']);
      if (type == 'Pages' || kids is List) {
        if (kids is List) {
          for (final k in kids) {
            walk(k, merged, depth + 1);
          }
        }
      } else {
        result.add({...d, 'Resources': res});
      }
    }

    if (catalog != null) walk(catalog['Pages'], null, 0);
    if (result.isEmpty) {
      final nums = objects.keys.toList()..sort();
      for (final n in nums) {
        final v = objects[n]!.value;
        if (v is Map<String, Object?> && _name(v['Type']) == 'Page') {
          result.add(v);
        }
      }
    }
    return result;
  }

  final _fontCache = <Object, _Font>{};

  _Font _fontFor(Object? ref) {
    final key = ref is _Ref ? ref.n : ref ?? 0;
    return _fontCache.putIfAbsent(key, () => _buildFont(_dictOf(ref)));
  }

  _Font _buildFont(Map<String, Object?>? f) {
    if (f == null) return _Font(null, 1, decodable: true);
    final subtype = _name(f['Subtype']);
    final tu = _resolve(f['ToUnicode']);
    final tuObj = f['ToUnicode'] is _Ref
        ? objects[(f['ToUnicode'] as _Ref).n]
        : null;
    var codeBytes = subtype == 'Type0' ? 2 : 1;
    Map<int, String>? map;
    if (tu != null && tuObj?.stream != null) {
      final data = _decode(tuObj!.value as Map, tuObj.stream!);
      if (data != null) {
        final parsed = _parseCMap(latin1.decode(data, allowInvalid: true));
        map = parsed.$1;
        if (parsed.$2 != null) codeBytes = parsed.$2!;
      }
    }
    final widths = <int, double>{};
    var dw = 500.0;
    if (subtype == 'Type0') {
      dw = 1000;
      final desc = _resolve(f['DescendantFonts']);
      final d0 = desc is List && desc.isNotEmpty ? _dictOf(desc.first) : null;
      if (d0 != null) {
        dw = (_resolve(d0['DW']) as num?)?.toDouble() ?? 1000;
        final w = _resolve(d0['W']);
        if (w is List) {
          var i = 0;
          while (i < w.length) {
            final first = _int(w[i]);
            final next = i + 1 < w.length ? _resolve(w[i + 1]) : null;
            if (first == null) break;
            if (next is List) {
              for (var k = 0; k < next.length; k++) {
                final v = _resolve(next[k]);
                if (v is num) widths[first + k] = v.toDouble();
              }
              i += 2;
            } else {
              final last = _int(next);
              final v = i + 2 < w.length ? _resolve(w[i + 2]) : null;
              if (last != null && v is num && last - first < 70000) {
                for (var c = first; c <= last; c++) {
                  widths[c] = v.toDouble();
                }
              }
              i += 3;
            }
          }
        }
      }
    } else {
      final first = _int(f['FirstChar']) ?? 0;
      final w = _resolve(f['Widths']);
      if (w is List) {
        for (var k = 0; k < w.length; k++) {
          final v = _resolve(w[k]);
          if (v is num) widths[first + k] = v.toDouble();
        }
      }
      final fd = _dictOf(f['FontDescriptor']);
      final missing = fd == null ? null : _resolve(fd['MissingWidth']);
      if (missing is num && missing > 0) dw = missing.toDouble();
    }
    if (map != null) {
      return _Font(
        map,
        codeBytes,
        decodable: true,
        widths: widths,
        defaultWidth: dw,
      );
    }
    if (subtype == 'Type0') {
      return _Font(null, 2, decodable: false, widths: widths, defaultWidth: dw);
    }
    return _Font(null, 1, decodable: true, widths: widths, defaultWidth: dw);
  }

  (Map<int, String>, int?) _parseCMap(String s) {
    final map = <int, String>{};
    int? bytesPerCode;
    String uni(String hex) {
      final units = <int>[];
      for (var i = 0; i + 4 <= hex.length; i += 4) {
        units.add(int.parse(hex.substring(i, i + 4), radix: 16));
      }
      if (hex.length < 4 && hex.isNotEmpty) {
        units.add(int.parse(hex, radix: 16));
      }
      return String.fromCharCodes(units);
    }

    for (final m in RegExp(
      r'begincodespacerange(.*?)endcodespacerange',
      dotAll: true,
    ).allMatches(s)) {
      final first = RegExp(r'<([0-9A-Fa-f]+)>').firstMatch(m.group(1)!);
      if (first != null) bytesPerCode = first.group(1)!.length ~/ 2;
    }
    for (final m in RegExp(
      r'beginbfchar(.*?)endbfchar',
      dotAll: true,
    ).allMatches(s)) {
      for (final p in RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]*)>',
      ).allMatches(m.group(1)!)) {
        map[int.parse(p.group(1)!, radix: 16)] = uni(p.group(2)!);
      }
    }
    for (final m in RegExp(
      r'beginbfrange(.*?)endbfrange',
      dotAll: true,
    ).allMatches(s)) {
      final body = m.group(1)!;
      for (final p in RegExp(
        r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*(<[0-9A-Fa-f]*>|\[[^\]]*\])',
      ).allMatches(body)) {
        final lo = int.parse(p.group(1)!, radix: 16);
        final hi = int.parse(p.group(2)!, radix: 16);
        final dst = p.group(3)!;
        if (dst.startsWith('[')) {
          final list = [
            for (final x in RegExp(r'<([0-9A-Fa-f]*)>').allMatches(dst))
              x.group(1)!,
          ];
          for (var c = lo; c <= hi && c - lo < list.length; c++) {
            map[c] = uni(list[c - lo]);
          }
        } else {
          final hex = dst.substring(1, dst.length - 1);
          final base = hex.isEmpty ? 0 : int.parse(hex, radix: 16);
          final width = hex.length;
          for (var c = lo; c <= hi && c - lo < 70000; c++) {
            final v = (base + (c - lo)).toRadixString(16).padLeft(width, '0');
            map[c] = uni(v);
          }
        }
      }
    }
    return (map, bytesPerCode);
  }

  // ---- content ----

  String? _pageText(Map<String, Object?> page) {
    final contents = _resolve(page['Contents']);
    final streams = <Uint8List>[];
    void addStream(Object? ref) {
      final o = ref is _Ref ? objects[ref.n] : null;
      if (o == null || o.stream == null) return;
      final d = _decode(o.value as Map, o.stream!);
      if (d != null) streams.add(d);
    }

    if (contents is List) {
      for (final c in contents) {
        addStream(c);
      }
    } else {
      addStream(page['Contents']);
    }
    if (streams.isEmpty) return null;
    final joined = Uint8List.fromList([
      for (final s in streams) ...[...s, 10],
    ]);
    final out = StringBuffer();
    _interpret(joined, _dictOf(page['Resources']), out, 0);
    return out.toString();
  }

  void _interpret(
    Uint8List data,
    Map<String, Object?>? resources,
    StringBuffer out,
    int depth,
  ) {
    final fonts = _dictOf(resources?['Font']);
    final xobjects = _dictOf(resources?['XObject']);
    final lx = _Lexer(data);
    final stack = <Object?>[];
    _Font font = _Font(null, 1, decodable: true);
    var fontSize = 1.0;
    // Position tracking in user space. A new line starts when the baseline of the next shown run differs from the previous
    // one; on the same line a gap wider than a fraction of the font size becomes one space (so kerning splits stay glued).
    var scaleX = 1.0;
    var lineX = 0.0; // start of the current text line
    var x = 0.0; // pen position
    var endX = 0.0; // pen position after the previous shown run
    var curY = 0.0;
    double? lastShownY;
    var wroteOnLine = false;
    var forceBreak = false;

    void newline() {
      if (wroteOnLine) out.write('\n');
      wroteOnLine = false;
    }

    double fs() => fontSize * scaleX.abs();

    void show(List<int> raw) {
      final (text, adv) = _decodeText(raw, font);
      if (text.isEmpty) {
        x += adv * fs() / 1000;
        return;
      }
      final newLine =
          forceBreak ||
          (lastShownY != null && (curY - lastShownY!).abs() > 1.5) ||
          (wroteOnLine && x < endX - fs() * 2);
      if (newLine) newline();
      final gap = x - endX;
      if (wroteOnLine && gap > fs() * 0.18) out.write(' ');
      forceBreak = false;
      lastShownY = curY;
      out.write(text);
      wroteOnLine = true;
      x += adv * fs() / 1000;
      endX = x;
    }

    while (true) {
      final v = lx.next();
      if (v == null) break;
      if (v is! _Op) {
        stack.add(v);
        if (stack.length > 400) stack.removeRange(0, 200);
        continue;
      }
      final op = v.v;
      double n(int fromEnd) {
        final i = stack.length - fromEnd;
        if (i < 0) return 0;
        final q = stack[i];
        return q is num ? q.toDouble() : 0;
      }

      switch (op) {
        case 'BT':
          scaleX = 1;
        case 'Tf':
          if (stack.length >= 2 && stack[stack.length - 2] is _Name) {
            final nm = (stack[stack.length - 2] as _Name).v;
            font = _fontFor(fonts?[nm]);
            fontSize = n(1) == 0 ? 1 : n(1);
          }
        case 'Tm':
          scaleX = n(6) == 0 ? 1 : n(6);
          lineX = n(2);
          x = lineX;
          curY = n(1);
        case 'Td' || 'TD':
          lineX += n(2) * scaleX;
          x = lineX;
          curY += n(1) * scaleX;
        case 'T*':
          forceBreak = true;
          x = lineX;
        case 'Tj':
          if (stack.isNotEmpty && stack.last is _Str) {
            show((stack.last as _Str).bytes);
          }
        case "'" || '"':
          forceBreak = true;
          x = lineX;
          if (stack.isNotEmpty && stack.last is _Str) {
            show((stack.last as _Str).bytes);
          }
        case 'TJ':
          if (stack.isNotEmpty && stack.last is List) {
            for (final e in stack.last as List) {
              if (e is _Str) {
                show(e.bytes);
              } else if (e is num) {
                x -= e * fs() / 1000;
              }
            }
          }
        case 'Do':
          if (depth < 3 && stack.isNotEmpty && stack.last is _Name) {
            final ref = xobjects?[(stack.last as _Name).v];
            final o = ref is _Ref ? objects[ref.n] : null;
            final d = o?.value;
            if (o?.stream != null &&
                d is Map &&
                _name(d['Subtype']) == 'Form') {
              final inner = _decode(d, o!.stream!);
              if (inner != null) {
                newline();
                _interpret(
                  inner,
                  _dictOf(d['Resources']) ?? resources,
                  out,
                  depth + 1,
                );
                newline();
              }
            }
          }
        case 'BI':
          // inline image: skip to EI
          while (true) {
            final t = lx.next();
            if (t == null || (t is _Op && t.v == 'EI')) break;
          }
      }
      stack.clear();
    }
    newline();
  }

  (String, double) _decodeText(List<int> raw, _Font font) {
    final out = StringBuffer();
    var adv = 0.0;
    if (!font.decodable) {
      _undecodable += raw.length;
      return ('', 0);
    }
    final map = font.toUnicode;
    final step = map != null ? font.codeBytes : 1;
    for (var i = 0; i + step <= raw.length; i += step) {
      var code = 0;
      for (var k = 0; k < step; k++) {
        code = code * 256 + raw[i + k];
      }
      adv += font.width(code);
      if (map != null) {
        final s = map[code];
        if (s != null) {
          out.write(s);
          _decoded++;
        } else if (step == 1 && code >= 32 && code < 127) {
          out.writeCharCode(code);
          _decoded++;
        } else {
          _undecodable++;
        }
      } else if (code != 0) {
        out.writeCharCode(_winAnsiHigh[code] ?? code);
        _decoded++;
      }
    }
    return (out.toString(), adv);
  }

  String _normalise(String s) {
    const lig = {
      'ﬁ': 'fi',
      'ﬂ': 'fl',
      'ﬀ': 'ff',
      'ﬃ': 'ffi',
      'ﬄ': 'ffl',
      ' ': ' ',
    };
    var t = s;
    lig.forEach((k, v) => t = t.replaceAll(k, v));
    final lines = [
      for (final l in t.split('\n'))
        if (l.replaceAll(RegExp(r'[ \t]+'), ' ').trim().isNotEmpty)
          l.replaceAll(RegExp(r'[ \t]+'), ' ').trim(),
    ];
    return lines.join('\n');
  }
}
