import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class PickedPdf extends Equatable {
  const PickedPdf({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  @override
  List<Object?> get props => [name, bytes.length];
}

/// Lets the user choose a PDF from the device. Returns null when the picker is cancelled.
abstract class PdfPicker {
  Future<PickedPdf?> pick();
}
