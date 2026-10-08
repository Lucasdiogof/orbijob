import 'dart:io';
import 'dart:typed_data';

/// Minimal PNG reader: validates signature, chunk layout and that IDAT inflates; returns IHDR data.
class PngInfo {
  PngInfo(this.width, this.height, this.colorType, this.hasTransparencyChunk);
  final int width;
  final int height;

  /// 0 gray, 2 RGB, 3 palette, 4 gray+alpha, 6 RGBA.
  final int colorType;
  final bool hasTransparencyChunk;

  bool get hasAlpha => colorType == 4 || colorType == 6 || hasTransparencyChunk;
}

PngInfo readPng(File f) {
  final b = f.readAsBytesSync();
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < 8; i++) {
    if (b[i] != sig[i]) throw FormatException('${f.path}: bad PNG signature');
  }
  final bd = ByteData.sublistView(b);
  var off = 8;
  int? w, h, ct;
  var tRNS = false, iend = false;
  final idat = BytesBuilder();
  while (off < b.length) {
    final len = bd.getUint32(off);
    final type = String.fromCharCodes(b.sublist(off + 4, off + 8));
    final data = b.sublist(off + 8, off + 8 + len);
    if (type == 'IHDR') {
      w = ByteData.sublistView(Uint8List.fromList(data)).getUint32(0);
      h = ByteData.sublistView(Uint8List.fromList(data)).getUint32(4);
      ct = data[9];
    } else if (type == 'tRNS') {
      tRNS = true;
    } else if (type == 'IDAT') {
      idat.add(data);
    } else if (type == 'IEND') {
      iend = true;
    }
    off += 12 + len;
  }
  if (w == null || !iend) throw FormatException('${f.path}: truncated PNG');
  ZLibCodec().decode(idat.toBytes()); // throws if the pixel stream is corrupt
  return PngInfo(w, h!, ct!, tRNS);
}
