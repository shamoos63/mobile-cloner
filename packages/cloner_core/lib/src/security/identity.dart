import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart' as crypto;

/// A device's TLS identity: a self-signed certificate whose SHA-256 hash is
/// the device fingerprint (same scheme as LocalSend).
class DeviceIdentity {
  const DeviceIdentity({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.fingerprint,
  });

  final String certificatePem;
  final String privateKeyPem;
  final String fingerprint;

  /// Generates a fresh RSA-2048 key and a 10 year self-signed certificate.
  /// Takes a second or two on a phone, so persist the result.
  static DeviceIdentity generate() {
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = pair.privateKey as RSAPrivateKey;
    final publicKey = pair.publicKey as RSAPublicKey;
    final cn = 'MobileCloner-${_randomHex(6)}';
    final csr = X509Utils.generateRsaCsrPem({'CN': cn}, privateKey, publicKey);
    final cert = X509Utils.generateSelfSignedCertificate(privateKey, csr, 3650);
    return DeviceIdentity(
      certificatePem: cert,
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
      fingerprint: fingerprintOfPem(cert),
    );
  }

  static String fingerprintOfPem(String pem) =>
      fingerprintOfDer(CryptoUtils.getBytesFromPEMString(pem));

  static String fingerprintOfDer(List<int> der) =>
      crypto.sha256.convert(der).toString().toUpperCase();

  SecurityContext toSecurityContext() => SecurityContext()
    ..useCertificateChainBytes(utf8.encode(certificatePem))
    ..usePrivateKeyBytes(utf8.encode(privateKeyPem));

  factory DeviceIdentity.fromJson(Map<String, Object?> json) => DeviceIdentity(
    certificatePem: json['certificate'] as String,
    privateKeyPem: json['privateKey'] as String,
    fingerprint: json['fingerprint'] as String,
  );

  Map<String, Object?> toJson() => {
    'certificate': certificatePem,
    'privateKey': privateKeyPem,
    'fingerprint': fingerprint,
  };

  static String _randomHex(int bytes) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }
}
