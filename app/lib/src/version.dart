/// Build number of this release; must match the `+N` in pubspec.yaml
/// (CI checks). The desktop installs or updates the phone app when the
/// phone's versionCode is lower.
const appVersionCode = 2;

/// Shown in Settings; matches the version before `+` in pubspec.yaml.
const appVersionName = '0.2.0';

const androidPackage = 'com.mobilecloner.app';
const androidActivity = '.MainActivity';
