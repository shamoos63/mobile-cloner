import 'dart:ui';

import '../l10n/app_localizations.dart';
import 'services/app_settings.dart';

export '../l10n/app_localizations.dart';

/// Strings in the app's current language, for code without a
/// BuildContext (service messages, notifications, helpers). Changing the
/// language rebuilds the whole app, so nothing keeps the old text.
S get tr => lookupS(Locale(AppSettings.instance.language));

/// Keeps numbers, sizes, speeds and addresses left-to-right inside Arabic
/// text ("12.4 MB/s" would otherwise come out scrambled).
String ltr(String text) => '\u2066$text\u2069';
