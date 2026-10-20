import 'package:path/path.dart' as p;

import '../protocol/file_dto.dart';
import 'content_category.dart';
import 'safe_path.dart';
import 'whatsapp_layout.dart';

/// Where an incoming file ends up on an Android receiver. The app turns each
/// target into the right platform call.
sealed class RestoreTarget {
  const RestoreTarget();
}

/// Insert into MediaStore (gallery) under [relativeDir], e.g. `DCIM/Camera`.
class MediaStoreTarget extends RestoreTarget {
  const MediaStoreTarget({required this.isVideo, required this.relativeDir, required this.displayName, this.takenAt});
  final bool isVideo;
  final String relativeDir;
  final String displayName;
  final DateTime? takenAt;
}

/// A file at a fixed path under shared storage (`/sdcard/<path>`).
class SharedStorageTarget extends RestoreTarget {
  const SharedStorageTarget({required this.path, required this.needsSpecialAccess, this.whatsApp});

  /// Relative to the shared storage root, forward slashes.
  final String path;

  /// True when the path is inside another app's `Android/media` folder on
  /// API 30+, which needs a SAF grant or All-files access.
  final bool needsSpecialAccess;
  final WhatsAppVariant? whatsApp;
}

/// Saved to a staging folder, then processed once the session ends.
class DeferredTarget extends RestoreTarget {
  const DeferredTarget(this.category, this.relPath);
  final ContentCategory category;
  final String relPath;
}

/// Maps incoming files to [RestoreTarget]s for an Android receiver running
/// API level [sdkInt].
class AndroidRestorePlanner {
  const AndroidRestorePlanner({required this.sdkInt, this.downloadsSubdir = 'MobileCloner'});

  final int sdkInt;
  final String downloadsSubdir;

  RestoreTarget targetFor(FileDto file) {
    final rel = file.relPath;
    switch (file.category) {
      case ContentCategory.photos:
      case ContentCategory.videos:
        final album = file.cloner?.mediaAlbum;
        final relDir = p.posix.dirname(rel);
        return MediaStoreTarget(
          isVideo: file.category == ContentCategory.videos || file.fileType.startsWith('video/'),
          // Keep the original folder (e.g. DCIM/Camera) when the sender gave one.
          relativeDir: relDir != '.'
              ? relDir
              : (album == null || album.isEmpty ? 'DCIM/Camera' : 'Pictures/${SafePath.normalize(album)}'),
          displayName: p.posix.basename(rel),
          takenAt: file.cloner?.takenAt ?? file.modified,
        );
      case ContentCategory.whatsapp:
      case ContentCategory.whatsappBusiness:
        final variant = WhatsAppVariant.fromCategory(file.category)!;
        return SharedStorageTarget(
          path: WhatsAppLayout.targetPath(variant, sdkInt, rel),
          needsSpecialAccess: WhatsAppLayout.needsSpecialAccess(sdkInt),
          whatsApp: variant,
        );
      case ContentCategory.audio:
        return SharedStorageTarget(path: 'Music/$rel', needsSpecialAccess: false);
      case ContentCategory.documents:
        return SharedStorageTarget(path: 'Documents/$rel', needsSpecialAccess: false);
      case ContentCategory.contacts:
      case ContentCategory.apps:
      case ContentCategory.messages:
      case ContentCategory.callLogs:
        return DeferredTarget(file.category, rel);
      case ContentCategory.files:
        return SharedStorageTarget(path: 'Download/$downloadsSubdir/$rel', needsSpecialAccess: false);
    }
  }
}
