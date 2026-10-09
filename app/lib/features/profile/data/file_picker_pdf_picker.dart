import 'package:file_picker/file_picker.dart';

import '../domain/pdf_picker.dart';
import '../domain/resume_repository.dart';

/// Production [PdfPicker]: the system file dialog, PDF only. A file over the limit is refused BEFORE its bytes are
/// read into memory (the size comes from the file metadata).
class FilePickerPdfPicker implements PdfPicker {
  @override
  Future<PickedPdf?> pick() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (f == null) return null;
    final size = await f.length();
    if (size != null && size > ResumeRepository.maxBytes) {
      throw const ResumeRejected(ResumeRejection.tooLarge);
    }
    final bytes = await f.readAsBytes();
    return PickedPdf(name: f.name, bytes: bytes);
  }
}
