import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/controller_template.dart';

const _prefsKey = 'user_templates_v1';

/// Persists user-made templates (built with the Template Maker) to local
/// storage, so they survive an app restart. Backed by shared_preferences,
/// which is browser localStorage on web and a plain file on desktop --
/// plenty for a handful of small template JSON blobs.
class UserTemplateStore {
  Future<List<ControllerTemplate>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw == null) return [];
    final templates = <ControllerTemplate>[];
    for (final entry in raw) {
      try {
        final json = jsonDecode(entry) as Map<String, dynamic>;
        templates.add(ControllerTemplate.fromJson(json, source: TemplateSource.userMade));
      } catch (_) {
        // Skip a corrupt entry rather than losing every other saved template.
      }
    }
    return templates;
  }

  Future<void> saveAll(List<ControllerTemplate> templates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, [for (final t in templates) jsonEncode(t.toJson())]);
  }
}
