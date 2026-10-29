import '../l10n.dart';

/// Sizes keep Western digits and Latin units in every language, isolated
/// left-to-right so they read correctly inside Arabic text.
String formatBytes(num bytes) => ltr(_bytes(bytes));

String _bytes(num bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 || v >= 100 ? 0 : 1)} ${units[i]}';
}

String formatSpeed(double bytesPerSecond) => ltr('${_bytes(bytesPerSecond)}/s');

String formatDuration(Duration d) {
  if (d.inHours > 0) return tr.durationHoursMinutes(d.inHours, d.inMinutes % 60);
  if (d.inMinutes > 0) return tr.durationMinutes(d.inMinutes);
  return tr.durationSeconds(d.inSeconds);
}
