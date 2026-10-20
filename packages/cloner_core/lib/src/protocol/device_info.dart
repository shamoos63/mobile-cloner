import 'constants.dart';

enum DeviceType {
  mobile,
  desktop,
  web,
  headless,
  server;

  static DeviceType? tryParse(Object? value) {
    for (final t in values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

enum ProtocolType {
  http,
  https;

  static ProtocolType parse(Object? value) =>
      value == 'http' ? ProtocolType.http : ProtocolType.https;
}

/// Platform of a Cloner peer. Plain LocalSend peers have no [ClonerPeerInfo].
enum ClonerPlatform {
  android,
  ios,
  windows,
  macos,
  linux,
  unknown;

  static ClonerPlatform parse(Object? value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return ClonerPlatform.unknown;
  }

  bool get isDesktop =>
      this == windows || this == macos || this == linux;
}

/// Extra info only Mobile Cloner peers send. Lets the sender know how the
/// receiver lays out storage (for example where WhatsApp lives) before it
/// prepares a transfer.
class ClonerPeerInfo {
  const ClonerPeerInfo({
    required this.platform,
    this.ext = clonerExtensionVersion,
    this.appVersion,
    this.sdkInt,
    this.osVersion,
    this.capabilities = const {},
  });

  final int ext;
  final String? appVersion;
  final ClonerPlatform platform;

  /// Android API level (Build.VERSION.SDK_INT). Null on other platforms.
  final int? sdkInt;
  final String? osVersion;

  /// What this peer can restore when receiving, e.g. `contacts`, `media`,
  /// `whatsapp`, `apps`, `sms`. A desktop peer stores everything as backup.
  final Set<String> capabilities;

  factory ClonerPeerInfo.fromJson(Map<String, Object?> json) => ClonerPeerInfo(
    ext: (json['ext'] as num?)?.toInt() ?? 1,
    appVersion: json['appVersion'] as String?,
    platform: ClonerPlatform.parse(json['platform']),
    sdkInt: (json['sdkInt'] as num?)?.toInt(),
    osVersion: json['osVersion'] as String?,
    capabilities: {
      for (final c in (json['capabilities'] as List?) ?? const []) c as String,
    },
  );

  Map<String, Object?> toJson() => {
    'ext': ext,
    'appVersion': ?appVersion,
    'platform': platform.name,
    'sdkInt': ?sdkInt,
    'osVersion': ?osVersion,
    'capabilities': capabilities.toList(),
  };
}

/// The info block every peer announces (LocalSend `register` / multicast DTO).
class DeviceInfo {
  const DeviceInfo({
    required this.alias,
    required this.fingerprint,
    this.version = protocolVersion,
    this.deviceModel,
    this.deviceType,
    this.port = defaultPort,
    this.protocol = ProtocolType.https,
    this.download = false,
    this.cloner,
  });

  final String alias;
  final String version;
  final String? deviceModel;
  final DeviceType? deviceType;
  final String fingerprint;
  final int port;
  final ProtocolType protocol;
  final bool download;
  final ClonerPeerInfo? cloner;

  bool get isCloner => cloner != null;

  factory DeviceInfo.fromJson(Map<String, Object?> json) => DeviceInfo(
    alias: json['alias'] as String? ?? 'Unknown',
    version: json['version'] as String? ?? '1.0',
    deviceModel: json['deviceModel'] as String?,
    deviceType: DeviceType.tryParse(json['deviceType']),
    fingerprint: json['fingerprint'] as String? ?? '',
    port: (json['port'] as num?)?.toInt() ?? defaultPort,
    protocol: ProtocolType.parse(json['protocol']),
    download: json['download'] as bool? ?? false,
    cloner: json['cloner'] is Map
        ? ClonerPeerInfo.fromJson((json['cloner'] as Map).cast())
        : null,
  );

  Map<String, Object?> toJson({bool announce = false, bool withAnnounce = false}) => {
    'alias': alias,
    'version': version,
    'deviceModel': deviceModel,
    'deviceType': deviceType?.name,
    'fingerprint': fingerprint,
    'port': port,
    'protocol': protocol.name,
    'download': download,
    if (withAnnounce) 'announce': announce,
    'cloner': ?cloner?.toJson(),
  };
}

/// A peer we discovered on the network.
class Device {
  const Device({required this.ip, required this.info});

  final String ip;
  final DeviceInfo info;

  String get fingerprint => info.fingerprint;
  int get port => info.port;
  bool get https => info.protocol == ProtocolType.https;

  Uri uri(String path, [Map<String, String>? query]) => Uri(
    scheme: https ? 'https' : 'http',
    host: ip,
    port: port,
    path: path,
    queryParameters: query,
  );

  @override
  String toString() => '${info.alias} ($ip:$port)';
}
