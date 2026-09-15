import 'package:flutter_test/flutter_test.dart';

import 'package:box_design_flutter/models/box_project.dart';

void main() {
  test('plate thickness and standoff settings default sensibly on a new project', () {
    final project = BoxProject();
    expect(project.plateThicknessMm, 5);
    expect(project.addStandoffs, isFalse);
    expect(project.standoffHeightMm, 3);
    expect(project.standoffWallThicknessMm, 2);
  });

  test('plate thickness and standoff settings round-trip through toJson/fromJson', () {
    final project = BoxProject(
      plateThicknessMm: 6.5,
      addStandoffs: true,
      standoffHeightMm: 4,
      standoffWallThicknessMm: 2.5,
    );
    final reloaded = BoxProject.fromJson(project.toJson());
    expect(reloaded.plateThicknessMm, 6.5);
    expect(reloaded.addStandoffs, isTrue);
    expect(reloaded.standoffHeightMm, 4);
    expect(reloaded.standoffWallThicknessMm, 2.5);
  });

  test('loading a project JSON saved before these settings existed falls back to defaults', () {
    // Regression guard: an older project file on disk won't have these keys
    // at all -- fromJson must not crash and should fall back sensibly.
    final project = BoxProject();
    final json = project.toJson()
      ..remove('plateThicknessMm')
      ..remove('addStandoffs')
      ..remove('standoffHeightMm')
      ..remove('standoffWallThicknessMm');
    final reloaded = BoxProject.fromJson(json);
    expect(reloaded.plateThicknessMm, 5);
    expect(reloaded.addStandoffs, isFalse);
    expect(reloaded.standoffHeightMm, 3);
    expect(reloaded.standoffWallThicknessMm, 2);
  });

  test('copyWith updates only the requested plate/standoff fields', () {
    final project = BoxProject(plateThicknessMm: 5, addStandoffs: false, standoffHeightMm: 3, standoffWallThicknessMm: 2);
    final updated = project.copyWith(addStandoffs: true, standoffHeightMm: 5);
    expect(updated.plateThicknessMm, 5);
    expect(updated.addStandoffs, isTrue);
    expect(updated.standoffHeightMm, 5);
    expect(updated.standoffWallThicknessMm, 2);
  });
}
