/// Health info both peers exchange every few seconds during a transfer
/// (Cloner extension, `POST /api/cloner/v1/status`). Lets each side warn
/// about the other's battery and notice a dead link quickly.
class PeerStatus {
  const PeerStatus({this.batteryLevel, this.charging, this.freeBytes, this.paused = false});

  /// 0..100, null when unknown (desktop).
  final int? batteryLevel;
  final bool? charging;

  /// Free storage on the receiver, so the sender can stop before it fills up.
  final int? freeBytes;
  final bool paused;

  static const lowBattery = 15;
  static const criticalBattery = 5;

  bool get isLow => batteryLevel != null && charging != true && batteryLevel! <= lowBattery;
  bool get isCritical => batteryLevel != null && charging != true && batteryLevel! <= criticalBattery;

  factory PeerStatus.fromJson(Map<String, Object?> json) => PeerStatus(
    batteryLevel: (json['battery'] as num?)?.toInt(),
    charging: json['charging'] as bool?,
    freeBytes: (json['freeBytes'] as num?)?.toInt(),
    paused: json['paused'] as bool? ?? false,
  );

  Map<String, Object?> toJson() => {
    'battery': ?batteryLevel,
    'charging': ?charging,
    'freeBytes': ?freeBytes,
    'paused': paused,
  };
}
