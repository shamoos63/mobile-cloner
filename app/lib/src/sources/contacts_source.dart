import 'dart:io';

import 'package:cloner_core/cloner_core.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform/android_bridge.dart';

/// Contacts as one vCard file made by Android's own exporter, which keeps
/// every field (multiple numbers, emails, addresses, notes, photos).
class ContactsSource {
  ContactsSource(this.bridge);

  final AndroidBridge bridge;

  Future<bool> requestAccess() async {
    final r = await bridge.requestPermissions([AndroidPermission.readContacts, AndroidPermission.writeContacts]);
    return r[AndroidPermission.readContacts] ?? false;
  }

  Future<({OutgoingFile file, int count})> export() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'contacts.vcf');
    final count = await bridge.exportContacts(path);
    final file = OutgoingFile.fromFile(File(path), category: ContentCategory.contacts, relPath: 'contacts.vcf');
    return (file: file, count: count);
  }
}
