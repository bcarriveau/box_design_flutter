import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/hole_preset.dart';

/// Raw-content URL for this project's own bundled hole/slot presets --
/// `loadRemoteDefaults` fetches this file so the "Generic Holes" palette can
/// pick up presets added or resized in the repo after this build without an
/// app update.
const String defaultHolePresetRepoUrl =
    'https://raw.githubusercontent.com/computergeek1507/box_design_flutter/main/assets/hole_presets.json';

/// Holds every [HolePreset] shown in the "Generic Holes" palette section:
/// [HolePreset.builtIns] until (optionally) replaced/extended by presets
/// fetched from a remote repo.
class HolePresetLibrary extends ChangeNotifier {
  final List<HolePreset> _presets = List.of(HolePreset.builtIns);

  List<HolePreset> get presets => List.unmodifiable(_presets);

  /// Fetches [url] -- a JSON array of [HolePreset.toJson] objects -- and
  /// merges it into the current set, replacing any built-in preset with the
  /// same id.
  Future<int> fetchRemotePresets(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch hole presets: HTTP ${response.statusCode}');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    var count = 0;
    for (final entry in list) {
      final preset = HolePreset.fromJson(entry as Map<String, dynamic>);
      _presets.removeWhere((p) => p.id == preset.id);
      _presets.add(preset);
      count++;
    }
    notifyListeners();
    return count;
  }

  /// Best-effort refresh from [defaultHolePresetRepoUrl] -- the app still
  /// works offline on [HolePreset.builtIns]. Any failure (offline, blocked,
  /// repo unreachable) is swallowed.
  Future<void> loadRemoteDefaults() async {
    try {
      await fetchRemotePresets(defaultHolePresetRepoUrl);
    } catch (_) {
      // Built-in presets already loaded; a remote refresh is optional.
    }
  }
}
