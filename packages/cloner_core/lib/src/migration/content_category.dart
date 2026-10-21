/// What a transferred file is, which decides where the receiver puts it.
enum ContentCategory {
  photos('photos'),
  videos('videos'),
  contacts('contacts'),
  whatsapp('whatsapp'),
  whatsappBusiness('whatsapp_business'),
  apps('apps'),
  messages('messages'),
  callLogs('call_logs'),
  documents('documents'),
  audio('audio'),

  /// Home and lock screen wallpaper images, applied on the receiver.
  wallpaper('wallpaper'),

  /// Plain files, including anything a stock LocalSend client sends.
  files('files');

  const ContentCategory(this.wireName);

  /// Stable name used on the wire and as the backup folder name.
  final String wireName;

  static ContentCategory parse(Object? value) {
    for (final c in values) {
      if (c.wireName == value) return c;
    }
    return ContentCategory.files;
  }

  bool get isWhatsApp => this == whatsapp || this == whatsappBusiness;
}
