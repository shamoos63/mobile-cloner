import 'package:cloner_core/cloner_core.dart';

import '../platform/android_bridge.dart';
import 'apps_source.dart';
import 'contacts_source.dart';
import 'media_source.dart';
import 'wallpaper_source.dart';
import 'whatsapp_source.dart';

/// Rebuilds the outgoing file list after an app restart from what the
/// checkpoint recorded. Stable file ids make the result line up with the
/// files already marked done.
Future<List<OutgoingFile>> rebuildFiles(AndroidBridge bridge, TransferCheckpoint cp) async {
  final files = <OutgoingFile>[];
  final chatsOnly = cp.options['whatsAppChatsOnly'] == true;
  for (final c in cp.categories) {
    switch (c) {
      case ContentCategory.photos || ContentCategory.videos:
        files.addAll(await MediaSource(bridge).files(c));
      case ContentCategory.contacts:
        files.add((await ContactsSource(bridge).export()).file);
      case ContentCategory.whatsapp || ContentCategory.whatsappBusiness:
        final scan = await WhatsAppSource(bridge)
            .scan(WhatsAppVariant.fromCategory(c)!, chatsOnly ? WhatsAppScope.chatsOnly : WhatsAppScope.full);
        files.addAll(scan.files);
      case ContentCategory.wallpaper:
        files.addAll((await WallpaperSource(bridge).export()).files);
      case ContentCategory.apps:
        final packages = [for (final p in cp.options['apps'] as List? ?? const []) '$p'];
        files.addAll(await AppsSource(bridge).filesFor(packages));
      default:
        break;
    }
  }
  return files;
}
