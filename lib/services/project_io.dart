import 'dart:convert';
import 'dart:typed_data';

import '../models/box_project.dart';
import 'file_io.dart';

Future<String?> saveProject(BoxProject project) {
  final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(project.toJson())));
  final fileName = '${project.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.boxproject.json';
  return saveBytes(fileName, bytes, dialogTitle: 'Save Project', mimeType: 'application/json');
}

Future<BoxProject?> openProject() async {
  final picked = await pickFile(allowedExtensions: ['json'], dialogTitle: 'Open Project');
  if (picked == null) return null;
  final json = jsonDecode(utf8.decode(picked.bytes)) as Map<String, dynamic>;
  return BoxProject.fromJson(json);
}
