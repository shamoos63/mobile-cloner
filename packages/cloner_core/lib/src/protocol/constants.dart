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
}
