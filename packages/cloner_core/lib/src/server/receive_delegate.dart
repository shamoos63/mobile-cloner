import '../protocol/device_info.dart';
import '../protocol/file_dto.dart';
import 'receive_session.dart';

/// Where the bytes of one incoming file go. Implementations write to a
/// temp file first and only move it into place on [commit], so a broken
/// transfer never leaves half a database in the WhatsApp folder.
abstract interface class IncomingFileWriter {
  Future<void> addStream(Stream<List<int>> data);
  Future<void> commit();
  Future<void> abort();
}

/// App-specific decisions for the receiving side.
abstract interface class ReceiveDelegate {
  /// A peer registered with us (discovery).
  void onDeviceSeen(Device device);

  /// Returns the ids of the files to accept, or `null` to reject the whole
  /// request. Typically shows an Accept dialog.
  Future<Set<String>?> onPrepare(Device sender, List<FileDto> files);

  Future<IncomingFileWriter> openFile(ReceiveSession session, FileDto file);

  /// All files settled and (for Cloner senders) the summary arrived.
  /// Post-processing goes here: import contacts, scan media, show the
  /// WhatsApp restore hint, write the backup manifest.
  Future<void> onSessionFinished(ReceiveSession session);

  void onSessionCanceled(ReceiveSession session);
}
