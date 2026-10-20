import 'content_category.dart';
import 'safe_path.dart';

enum WhatsAppVariant {
  messenger('com.whatsapp', 'WhatsApp', ContentCategory.whatsapp),
  business('com.whatsapp.w4b', 'WhatsApp Business', ContentCategory.whatsappBusiness);

  const WhatsAppVariant(this.packageName, this.folderName, this.category);

  final String packageName;

  /// Folder name inside the storage root, e.g. `WhatsApp Business`.
  final String folderName;
  final ContentCategory category;

  static WhatsAppVariant? fromCategory(ContentCategory c) => switch (c) {
    ContentCategory.whatsapp => messenger,
    ContentCategory.whatsappBusiness => business,
    _ => null,
  };
}

/// How much of the WhatsApp folder to move.
enum WhatsAppScope {
  /// Only `Databases` and `Backups`: chats restore, media stays behind.
  chatsOnly,

  /// Everything except throwaway folders (`.Shared`, `.trash`, `.Thumbs`,
  /// `.StickerThumbs`, cached status updates).
  full,
}

/// Maps the WhatsApp folder between storage layouts.
///
/// - Android 10 (API 29) and older: `/sdcard/WhatsApp`
/// - Android 11 (API 30) and newer: `/sdcard/Android/media/com.whatsapp/WhatsApp`
///
/// Paths here are relative to the shared storage root (`/sdcard`,
/// `/storage/emulated/0`). The sender transfers paths relative to the
/// WhatsApp folder, and the receiver picks the root for its own API level.
abstract final class WhatsAppLayout {
  /// First API level where WhatsApp lives under `Android/media`.
  static const scopedStorageSdk = 30;

  static String scopedRoot(WhatsAppVariant v) =>
      'Android/media/${v.packageName}/${v.folderName}';

  static String legacyRoot(WhatsAppVariant v) => v.folderName;

  /// Where WhatsApp on a device with [sdkInt] reads its local backup.
  static String rootFor(WhatsAppVariant v, int sdkInt) =>
      sdkInt >= scopedStorageSdk ? scopedRoot(v) : legacyRoot(v);

  /// Roots to probe on the source phone, most likely first. A phone that was
  /// upgraded to Android 11 can still have data in the legacy folder.
  static List<String> sourceCandidates(WhatsAppVariant v, int sdkInt) =>
      sdkInt >= scopedStorageSdk
          ? [scopedRoot(v), legacyRoot(v)]
          : [legacyRoot(v), scopedRoot(v)];

  /// On API 30+ another app's `Android/media` folder is only reachable
  /// through the Storage Access Framework, All-files access, or root.
  static bool needsSpecialAccess(int sdkInt) => sdkInt >= scopedStorageSdk;

  /// Target path relative to shared storage for a file at [relPath] inside
  /// the WhatsApp folder.
  static String targetPath(WhatsAppVariant v, int sdkInt, String relPath) {
    final rel = SafePath.normalize(relPath);
    if (rel.isEmpty) throw UnsafePathException(relPath);
    return '${rootFor(v, sdkInt)}/$rel';
  }

  static const _chatFolders = {'databases', 'backups'};
  static const _junkFolders = {
    '.shared',
    '.trash',
    '.thumbs',
    '.stickerthumbs',
    '.statuses',
  };

  /// Whether [relPath] (relative to the WhatsApp folder) is copied under
  /// [scope].
  static bool includes(WhatsAppScope scope, String relPath) {
    final rel = SafePath.normalize(relPath);
    final segments = rel.toLowerCase().split('/');
    if (segments.any(_junkFolders.contains)) return false;
    return switch (scope) {
      WhatsAppScope.chatsOnly => _chatFolders.contains(segments.first),
      WhatsAppScope.full => true,
    };
  }

  /// Files WhatsApp needs to offer "Restore" on the new phone.
  static bool isChatDatabase(String relPath) {
    final rel = SafePath.normalize(relPath).toLowerCase();
    return rel.startsWith('databases/msgstore') ||
        rel.startsWith('backups/');
  }
}
