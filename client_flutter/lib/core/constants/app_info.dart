// lib/core/constants/app_info.dart
/// Central product metadata.
///
/// `APP_VERSION` and `APP_BUILD` are injected by the release workflow so the
/// in-app version never silently drifts from the published build. Local runs
/// fall back to the checked-in values below.
class AppInfo {
  const AppInfo._();

  static const String name = 'Kolom Fight';
  static const String nameBn = 'কলম খেলা';
  static const String tagline = 'Classroom Pen Battle';

  static const String version = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.2.0',
  );
  static const String buildNumber = String.fromEnvironment(
    'APP_BUILD',
    defaultValue: '3',
  );

  static String get displayVersion => '$version ($buildNumber)';
  static const String releasesUrl =
      'https://github.com/mahmud-r-farhan/pen-game/releases';
}
