import 'package:cloner_core/cloner_core.dart';
import 'package:flutter/material.dart';

import '../../l10n.dart';

String categoryLabel(ContentCategory c) => switch (c) {
  ContentCategory.photos => tr.categoryPhotos,
  ContentCategory.videos => tr.categoryVideos,
  ContentCategory.contacts => tr.categoryContacts,
  ContentCategory.whatsapp => tr.categoryWhatsapp,
  ContentCategory.whatsappBusiness => tr.categoryWhatsappBusiness,
  ContentCategory.apps => tr.categoryApps,
  ContentCategory.messages => tr.categoryMessages,
  ContentCategory.callLogs => tr.categoryCallLogs,
  ContentCategory.documents => tr.categoryDocuments,
  ContentCategory.audio => tr.categoryAudio,
  ContentCategory.wallpaper => tr.categoryWallpaper,
  ContentCategory.files => tr.categoryFiles,
};

IconData categoryIcon(ContentCategory c) => switch (c) {
  ContentCategory.photos => Icons.photo_outlined,
  ContentCategory.videos => Icons.videocam_outlined,
  ContentCategory.contacts => Icons.contacts_outlined,
  ContentCategory.whatsapp => Icons.chat_outlined,
  ContentCategory.whatsappBusiness => Icons.storefront_outlined,
  ContentCategory.apps => Icons.apps_outlined,
  ContentCategory.messages => Icons.sms_outlined,
  ContentCategory.callLogs => Icons.call_outlined,
  ContentCategory.documents => Icons.description_outlined,
  ContentCategory.audio => Icons.music_note_outlined,
  ContentCategory.wallpaper => Icons.wallpaper_outlined,
  ContentCategory.files => Icons.folder_outlined,
};

IconData deviceIcon(Device d) => switch (d.info.deviceType) {
  DeviceType.desktop || DeviceType.headless || DeviceType.server => Icons.computer,
  _ => Icons.smartphone,
};
