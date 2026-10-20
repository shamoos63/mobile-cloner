import 'package:cloner_core/cloner_core.dart';
import 'package:test/test.dart';

void main() {
  group('WhatsAppLayout', () {
    test('legacy root on Android 10 and older', () {
      expect(WhatsAppLayout.rootFor(WhatsAppVariant.messenger, 23), 'WhatsApp');
      expect(WhatsAppLayout.rootFor(WhatsAppVariant.messenger, 29), 'WhatsApp');
      expect(WhatsAppLayout.rootFor(WhatsAppVariant.business, 29), 'WhatsApp Business');
    });

    test('Android/media root on Android 11+', () {
      expect(WhatsAppLayout.rootFor(WhatsAppVariant.messenger, 30), 'Android/media/com.whatsapp/WhatsApp');
      expect(
        WhatsAppLayout.rootFor(WhatsAppVariant.business, 34),
        'Android/media/com.whatsapp.w4b/WhatsApp Business',
      );
    });

    test('old phone to new phone maps the database path', () {
      expect(
        WhatsAppLayout.targetPath(WhatsAppVariant.messenger, 33, 'Databases/msgstore.db.crypt14'),
        'Android/media/com.whatsapp/WhatsApp/Databases/msgstore.db.crypt14',
      );
      expect(
        WhatsAppLayout.targetPath(WhatsAppVariant.business, 26, 'Databases/msgstore.db.crypt14'),
        'WhatsApp Business/Databases/msgstore.db.crypt14',
      );
    });

    test('source candidates prefer the layout of the running Android version', () {
      expect(WhatsAppLayout.sourceCandidates(WhatsAppVariant.messenger, 31).first, startsWith('Android/media'));
      expect(WhatsAppLayout.sourceCandidates(WhatsAppVariant.messenger, 28).first, 'WhatsApp');
    });

    test('scope filtering', () {
      expect(WhatsAppLayout.includes(WhatsAppScope.chatsOnly, 'Databases/msgstore.db.crypt14'), isTrue);
      expect(WhatsAppLayout.includes(WhatsAppScope.chatsOnly, 'Backups/chatsettings.db.crypt14'), isTrue);
      expect(WhatsAppLayout.includes(WhatsAppScope.chatsOnly, 'Media/WhatsApp Images/a.jpg'), isFalse);
      expect(WhatsAppLayout.includes(WhatsAppScope.full, 'Media/WhatsApp Images/a.jpg'), isTrue);
      expect(WhatsAppLayout.includes(WhatsAppScope.full, 'Media/.Statuses/x.jpg'), isFalse);
      expect(WhatsAppLayout.includes(WhatsAppScope.full, '.Shared/tmp'), isFalse);
    });

    test('rejects path traversal', () {
      expect(
        () => WhatsAppLayout.targetPath(WhatsAppVariant.messenger, 30, '../../evil'),
        throwsA(isA<UnsafePathException>()),
      );
    });
  });

  group('AndroidRestorePlanner', () {
    FileDto dto(ContentCategory c, String rel, {String type = 'image/jpeg'}) => FileDto(
      id: rel,
      fileName: rel.split('/').last,
      size: 1,
      fileType: type,
      cloner: ClonerFileMeta(category: c, relPath: rel),
    );

    test('WhatsApp needs special access only on API 30+', () {
      final legacy = const AndroidRestorePlanner(sdkInt: 29).targetFor(dto(ContentCategory.whatsapp, 'Databases/msgstore.db.crypt14'));
      final scoped = const AndroidRestorePlanner(sdkInt: 30).targetFor(dto(ContentCategory.whatsapp, 'Databases/msgstore.db.crypt14'));
      expect(legacy, isA<SharedStorageTarget>().having((t) => t.needsSpecialAccess, 'special', isFalse));
      expect(scoped, isA<SharedStorageTarget>().having((t) => t.needsSpecialAccess, 'special', isTrue));
      expect((scoped as SharedStorageTarget).path, startsWith('Android/media/com.whatsapp/'));
    });

    test('photos keep their folder', () {
      final t = const AndroidRestorePlanner(sdkInt: 33).targetFor(dto(ContentCategory.photos, 'DCIM/Camera/IMG_1.jpg'));
      expect(t, isA<MediaStoreTarget>().having((t) => t.relativeDir, 'dir', 'DCIM/Camera'));
    });

    test('contacts are deferred', () {
      final t = const AndroidRestorePlanner(sdkInt: 33).targetFor(dto(ContentCategory.contacts, 'contacts.vcf', type: 'text/vcard'));
      expect(t, isA<DeferredTarget>());
    });
  });

  group('SafePath', () {
    test('normalizes separators and dots', () {
      expect(SafePath.normalize(r'a\b/./c'), 'a/b/c');
    });
    test('rejects drive letters and ..', () {
      expect(() => SafePath.normalize('C:/x'), throwsA(isA<UnsafePathException>()));
      expect(() => SafePath.normalize('a/../b'), throwsA(isA<UnsafePathException>()));
    });
  });

  group('PairingCode', () {
    test('round trips', () {
      const code = PairingCode(
        addresses: ['192.168.43.1', '192.168.42.129'],
        port: 53317,
        fingerprint: 'ABC',
        alias: 'Old phone',
        pin: '123456',
        wifiSsid: 'Cloner-1234',
        wifiPassword: 'p@ss word',
      );
      final decoded = PairingCode.tryDecode(code.encode())!;
      expect(decoded.addresses, code.addresses);
      expect(decoded.pin, '123456');
      expect(decoded.wifiPassword, 'p@ss word');
      expect(decoded.https, isTrue);
    });
  });
}
