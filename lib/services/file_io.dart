import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

// Without this, the desktop save/open dialog isn't owned by the app window
// (file_picker's default is unlocked) — it can silently drop behind the
// main window with no visual cue, which reads as "nothing happened" and
// invites a confusing retry. Locking it keeps the dialog modally in front,
// the way a native Windows/Linux app dialog normally behaves.
const _desktopWindowOptions = WindowsOptions(lockParentWindow: true);
const _desktopLinuxOptions = LinuxOptions(lockParentWindow: true);

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
    windowsOptions: _desktopWindowOptions,
    linuxOptions: _desktopLinuxOptions,
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
    windowsOptions: _desktopWindowOptions,
    linuxOptions: _desktopLinuxOptions,
  );
  if (result.isEmpty) return null;
  final file = result.first;
  return PickedFile(file.name, await file.readAsBytes());
}
