/// Real transfer speed over a sliding window, so the number reacts to a
/// slowdown within seconds instead of averaging over the whole session.
class SpeedMeter {
  SpeedMeter({this.window = const Duration(seconds: 5), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Duration window;
  final DateTime Function() _clock;
  final List<(DateTime, int)> _samples = [];
  int _total = 0;

  /// Records [bytes] newly transferred.
  void add(int bytes) {
    if (bytes <= 0) return;
    _total += bytes;
    final now = _clock();
    _samples.add((now, _total));
    final cutoff = now.subtract(window);
    while (_samples.length > 2 && _samples[1].$1.isBefore(cutoff)) {
      _samples.removeAt(0);
    }
  }

  /// Bytes per second over the window (0 until two samples exist).
  double get bytesPerSecond {
    if (_samples.length < 2) return 0;
    final first = _samples.first, last = _samples.last;
    final ms = last.$1.difference(first.$1).inMilliseconds;
    if (ms <= 0) return 0;
    // Idle since the last sample: speed decays to zero.
    final idleMs = _clock().difference(last.$1).inMilliseconds;
    return (last.$2 - first.$2) * 1000 / (ms + (idleMs > 1000 ? idleMs : 0));
  }

  Duration? eta(int remainingBytes) {
    final bps = bytesPerSecond;
    if (bps <= 0) return null;
    return Duration(seconds: (remainingBytes / bps).ceil());
  }
}
