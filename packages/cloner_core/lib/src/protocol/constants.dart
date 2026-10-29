/// Protocol constants.
///
/// Mobile Cloner speaks the LocalSend v2 protocol
/// (https://github.com/localsend/protocol) for discovery and transfer, so a
/// stock LocalSend client can still send plain files to us and vice versa.
/// Cloner-specific data rides in optional extra JSON fields (`cloner`) that
/// LocalSend ignores, plus a small extra API under [clonerApiBase].
library;

const protocolVersion = '2.1';
const defaultPort = 53317;

/// Plain-HTTP listener bound to 127.0.0.1 only. ADB maps the USB cable onto
/// it, so cable transfers skip TLS (the cable is the trust boundary and TLS
/// is the main CPU cost on phones). Not reachable from the network.
const loopbackPort = 53320;
const defaultMulticastGroup = '224.0.0.167';

const localSendApiBase = '/api/localsend/v2';
const clonerApiBase = '/api/cloner/v1';

/// Version of the Cloner extension carried in `cloner.ext`.
const clonerExtensionVersion = 1;

abstract final class ApiRoute {
  static const register = '$localSendApiBase/register';
  static const info = '$localSendApiBase/info';
  static const prepareUpload = '$localSendApiBase/prepare-upload';
  static const upload = '$localSendApiBase/upload';
  static const cancel = '$localSendApiBase/cancel';

  /// Sent by a Cloner sender after the last file of a session, carrying a
  /// summary so the receiver can run post-processing (contacts import,
  /// media scan, WhatsApp hints) even if some files were skipped.
  static const finish = '$clonerApiBase/finish';

  /// Heartbeat both ways during a transfer: battery, free space, pause.
  static const status = '$clonerApiBase/status';

  /// Installed apps (JSON list) and one app's icon (`?package=`, PNG), for
  /// the computer over USB. Served on the loopback listener only.
  static const apps = '$clonerApiBase/apps';
  static const appIcon = '$clonerApiBase/apps/icon';
}
