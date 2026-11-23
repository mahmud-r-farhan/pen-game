import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolom_fight/core/constants/app_info.dart';

void main() {
  test('checked-in version metadata matches pubspec.yaml', () {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final versionLine = lines.firstWhere((line) => line.startsWith('version:'));
    final value = versionLine.substring('version:'.length).trim();
    final parts = value.split('+');

    expect(parts, hasLength(2), reason: 'pubspec version must be name+build');
    expect(AppInfo.version, parts[0]);
    expect(AppInfo.buildNumber, parts[1]);
    expect(AppInfo.displayVersion, '${parts[0]} (${parts[1]})');
  });

  test('product metadata is non-empty and release URL is https', () {
    expect(AppInfo.name, isNotEmpty);
    expect(AppInfo.nameBn, isNotEmpty);
    expect(AppInfo.tagline, isNotEmpty);
    expect(AppInfo.releasesUrl, startsWith('https://'));
  });
}
