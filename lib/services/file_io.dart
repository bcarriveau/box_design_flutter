import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Prompts the user for a save location (desktop) or triggers a browser
/// download (web) and writes [bytes] there. Returns the saved location's
/// URI string, or null if the user cancelled.
Future<String?> saveBytes(
  String fileName,
  Uint8List bytes, {
  String? dialogTitle,
  String mimeType = 'application/octet-stream',
}) async {
  final uri = await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    mimeType: mimeType,
    dialogTitle: dialogTitle,
  );
  return uri?.toString();
}

class PickedFile {
  final String name;
  final Uint8List bytes;

  const PickedFile(this.name, this.bytes);
}

/// Opens a file picker restricted to [allowedExtensions] and returns the
/// picked file's bytes and name, or null if the user cancelled.
Future<PickedFile?> pickFile({List<String>? allowedExtensions, String? dialogTitle}) async {
  final result = await FilePicker.pickFiles(
    dialogTitle: dialogTitle,
    type: allowedExtensions == null ? FileType.any : FileType.custom,
    allowedExtensions: allowedExtensions,
  );
  if (result.isEmpty) return null;
  final file = result.first;
  return PickedFile(file.name, await file.readAsBytes());
}
