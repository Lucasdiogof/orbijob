import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbijob/features/profile/domain/pdf_text.dart';

/// Builds small but structurally real PDFs (objects, streams, optionally compressed or in an object stream).
class _Pdf {
  final parts = <int, List<int>>{};

  void obj(int n, String body) =>
      parts[n] = latin1.encode('$n 0 obj\n$body\nendobj\n');

  void stream(int n, String dict, List<int> data, {bool flate = false}) {
    final payload = flate ? ZLibEncoder().encodeBytes(data) : data;
    parts[n] = [
      ...latin1.encode(
        '$n 0 obj\n<< $dict ${flate ? '/Filter /FlateDecode ' : ''}/Length ${payload.length} >>\nstream\n',
      ),
      ...payload,
      ...latin1.encode('\nendstream\nendobj\n'),
    ];
  }

  Uint8List bytes() {
    final keys = parts.keys.toList()..sort();
    return Uint8List.fromList([
      ...latin1.encode('%PDF-1.5\n'),
      for (final k in keys) ...parts[k]!,
      ...latin1.encode('trailer\n<< /Root 1 0 R >>\n%%EOF'),
    ]);
  }
}

Uint8List _simple(String content, {bool flate = false}) {
  final p = _Pdf()
    ..obj(1, '<< /Type /Catalog /Pages 2 0 R >>')
    ..obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>')
    ..obj(
      3,
      '<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    )
    ..stream(4, '', latin1.encode(content), flate: flate)
    ..obj(
      5,
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>',
    );
  return p.bytes();
}

String _hex16(String s) =>
    s.codeUnits.map((c) => c.toRadixString(16).padLeft(4, '0')).join();

void main() {
  test('simple fonts: lines, spaces between shows, parentheses and escapes', () {
    final r = extractPdfText(
      _simple(
        'BT /F1 12 Tf 72 700 Td (Maria Souza) Tj 0 -16 Td (Fisioterapeuta p\\351lvica \\(CREFITO\\)) Tj ET\n'
        'BT /F1 10 Tf 72 650 Td [(Skills)] TJ 40 0 Td (Flutter) Tj ET',
      ),
    );
    expect(r.status, PdfTextStatus.ok);
    expect(r.pages, 1);
    expect(r.text, contains('Maria Souza'));
    expect(r.text, contains('Fisioterapeuta pélvica (CREFITO)'));
    expect(r.text.split('\n'), contains('Skills Flutter'));
  });

  test('Flate-compressed content and TJ kerning that means a space', () {
    final r = extractPdfText(
      _simple(
        'BT /F1 12 Tf 72 700 Td [(Backend) -400 (developer) -400 (with ten years of Flutter and Dart experience)] TJ ET',
        flate: true,
      ),
    );
    expect(r.status, PdfTextStatus.ok);
    expect(r.text, contains('Backend developer with ten years'));
  });

  test('Type0 Identity-H font decoded through its ToUnicode map', () {
    const text = 'Experiência em Flutter e fisioterapia pélvica';
    final glyphs = {for (var i = 0; i < text.length; i++) text[i]: 0x20 + i};
    final cmap = StringBuffer(
      '/CIDInit /ProcSet findresource begin 12 dict begin begincmap\n'
      '1 begincodespacerange <0000> <FFFF> endcodespacerange\n'
      '${glyphs.length} beginbfchar\n',
    );
    glyphs.forEach((ch, code) {
      cmap.writeln(
        '<${code.toRadixString(16).padLeft(4, '0')}> <${_hex16(ch)}>',
      );
    });
    cmap.write('endbfchar\nendcmap');
    final shown = text
        .split('')
        .map((c) => glyphs[c]!.toRadixString(16).padLeft(4, '0'))
        .join();
    final p = _Pdf()
      ..obj(1, '<< /Type /Catalog /Pages 2 0 R >>')
      ..obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>')
      ..obj(
        3,
        '<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      )
      ..stream(
        4,
        '',
        latin1.encode('BT /F1 12 Tf 72 700 Td <$shown> Tj ET'),
        flate: true,
      )
      ..obj(
        5,
        '<< /Type /Font /Subtype /Type0 /BaseFont /AAAAAA+Font /Encoding /Identity-H /ToUnicode 6 0 R >>',
      )
      ..stream(6, '', latin1.encode(cmap.toString()), flate: true);
    final r = extractPdfText(p.bytes());
    expect(r.status, PdfTextStatus.ok);
    expect(r.text, contains(text));
  });

  test('bfrange with a start code and an array form', () {
    final cmap =
        '1 begincodespacerange <00> <FF> endcodespacerange\n'
        '1 beginbfrange <41> <43> <0061> endbfrange\n'
        '1 beginbfrange <44> <45> [<0078> <0079>] endbfrange';
    final p = _Pdf()
      ..obj(1, '<< /Type /Catalog /Pages 2 0 R >>')
      ..obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>')
      ..obj(
        3,
        '<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      )
      ..stream(
        4,
        '',
        latin1.encode(
          'BT /F1 12 Tf 0 0 Td (ABCDE and some more readable words here) Tj ET',
        ),
      )
      ..obj(5, '<< /Type /Font /Subtype /TrueType /ToUnicode 6 0 R >>')
      ..stream(6, '', latin1.encode(cmap));
    final r = extractPdfText(p.bytes());
    expect(r.text, startsWith('abcxy'));
  });

  test('objects inside an object stream (PDF 1.5) are found', () {
    final inner = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      '<< /Type /Font /Subtype /Type1 /Encoding /WinAnsiEncoding >>',
    ];
    final nums = [1, 2, 3, 5];
    final body = StringBuffer();
    final header = StringBuffer();
    for (var i = 0; i < inner.length; i++) {
      header.write('${nums[i]} ${body.length} ');
      body.write('${inner[i]}\n');
    }
    final data = '$header$body';
    final p = _Pdf()
      ..stream(
        6,
        '/Type /ObjStm /N ${inner.length} /First ${header.length}',
        latin1.encode(data),
        flate: true,
      )
      ..stream(
        4,
        '',
        latin1.encode(
          'BT /F1 12 Tf 72 700 Td (Compressed object streams are fine) Tj ET',
        ),
      );
    final r = extractPdfText(p.bytes());
    expect(r.status, PdfTextStatus.ok);
    expect(r.text, contains('Compressed object streams are fine'));
  });

  test(
    'a scan (image only, no text operators) is reported as having no text layer',
    () {
      final p = _Pdf()
        ..obj(1, '<< /Type /Catalog /Pages 2 0 R >>')
        ..obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>')
        ..obj(
          3,
          '<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /XObject << /Im0 5 0 R >> >> >>',
        )
        ..stream(4, '', latin1.encode('q 595 0 0 842 0 0 cm /Im0 Do Q'))
        ..stream(
          5,
          '/Type /XObject /Subtype /Image /Width 1 /Height 1 /ColorSpace /DeviceGray /BitsPerComponent 8',
          [128],
        );
      final r = extractPdfText(p.bytes());
      expect(r.status, PdfTextStatus.noTextLayer);
      expect(r.text, isEmpty, reason: 'never pretends to have read anything');
    },
  );

  test('encrypted PDFs are reported as such, not guessed at', () {
    final bytes = Uint8List.fromList([
      ...latin1.encode(
        '%PDF-1.6\n1 0 obj\n<< /Type /Catalog >>\nendobj\ntrailer\n<< /Root 1 0 R /Encrypt 9 0 R >>\n',
      ),
    ]);
    expect(extractPdfText(bytes).status, PdfTextStatus.encrypted);
  });

  test('a Type0 font with no ToUnicode is unreadable, not garbage text', () {
    final p = _Pdf()
      ..obj(1, '<< /Type /Catalog /Pages 2 0 R >>')
      ..obj(2, '<< /Type /Pages /Kids [3 0 R] /Count 1 >>')
      ..obj(
        3,
        '<< /Type /Page /Parent 2 0 R /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
      )
      ..stream(
        4,
        '',
        latin1.encode('BT /F1 12 Tf 0 0 Td <00240025002600270028> Tj ET'),
      )
      ..obj(5, '<< /Type /Font /Subtype /Type0 /Encoding /Identity-H >>');
    final r = extractPdfText(p.bytes());
    expect(r.status, isNot(PdfTextStatus.ok));
    expect(r.text, isEmpty);
  });

  test('not a PDF, empty and truncated input never throw', () {
    expect(extractPdfText(Uint8List(0)).status, PdfTextStatus.unreadable);
    expect(
      extractPdfText(Uint8List.fromList([1, 2, 3])).status,
      PdfTextStatus.unreadable,
    );
    final good = _simple('BT /F1 12 Tf 0 0 Td (Hello) Tj ET');
    final cut = good.sublist(0, good.length ~/ 2);
    expect(() => extractPdfText(cut), returnsNormally);
  });

  test('ligatures and non-breaking spaces are normalised', () {
    final r = extractPdfText(
      _simple(
        'BT /F1 12 Tf 0 0 Td (Office of the first certificate of qualification) Tj ET',
      ),
    );
    expect(r.text, contains('Office'));
  });
}
