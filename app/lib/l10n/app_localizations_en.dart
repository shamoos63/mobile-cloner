// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class SEn extends S {
  SEn([String locale = 'en']) : super(locale);

  @override
  String get accept => 'Accept';

  @override
  String get adbChecking => 'Checking for HK Cloner...';

  @override
  String get adbInstalledOpened =>
      'Installed and opened. Choose what to back up on the phone.';

  @override
  String get adbMissing => 'HK Cloner isn\'t on the phone';

  @override
  String get adbMissingRetry =>
      'HK Cloner isn\'t on the phone. Click Retry to install it.';

  @override
  String get adbOlderOpened =>
      'Opened the older HK Cloner on the phone. Click Retry to update it.';

  @override
  String get adbOpened => 'Opened on the phone. Choose what to back up there.';

  @override
  String get adbOutdated => 'HK Cloner is out of date';

  @override
  String adbSetupFailed(String error) {
    return 'Setup failed: $error';
  }

  @override
  String get adbTapAllow => 'Tap \"Allow\" on the phone to trust this computer';

  @override
  String get adbUpdatedOpened =>
      'Updated and opened. Choose what to back up on the phone.';

  @override
  String get allDone => 'All done';

  @override
  String get allow => 'Allow';

  @override
  String get allowInstallBody =>
      'Android needs \"Install unknown apps\" turned on for HK Cloner. Turn it on, then come back here.';

  @override
  String get allowInstallTitle => 'Allow HK Cloner to install apps';

  @override
  String allowPermissionToFind(String name) {
    return 'Allow \"$name\" to find the other phone';
  }

  @override
  String get allowWhatsappFolder => 'Allow WhatsApp folder';

  @override
  String get allowWhatsappFolderHint =>
      'Needed once on Android 11+ so chats restore.';

  @override
  String get allowed => 'Allowed';

  @override
  String androidApi(int level) {
    return 'Android API $level';
  }

  @override
  String androidVersion(String version) {
    return 'Android $version';
  }

  @override
  String apkSummary(String version, String size) {
    return 'HK Cloner $version · $size';
  }

  @override
  String appMissingOn(String device) {
    return 'HK Cloner isn\'t on $device';
  }

  @override
  String appOutdatedOn(String device) {
    return 'HK Cloner on $device is out of date';
  }

  @override
  String get appStatusAlreadyInstalled =>
      'Already installed (same or newer version)';

  @override
  String get appStatusCanceled => 'Canceled';

  @override
  String appStatusFailed(String reason) {
    return 'Failed: $reason';
  }

  @override
  String get appStatusIncomplete => 'Not fully received';

  @override
  String get appStatusInstalled => 'Installed';

  @override
  String get appStatusInstalling => 'Installing...';

  @override
  String appStatusNeedsAndroid(int level) {
    return 'Needs a newer Android (API $level)';
  }

  @override
  String get appTitle => 'HK Cloner';

  @override
  String get appUnreadable => 'Android doesn\'t let HK Cloner read this app.';

  @override
  String appsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps',
      one: '1 app',
      zero: 'No apps',
    );
    return '$_temp0';
  }

  @override
  String appsInstalledSummary(int installed, int total) {
    return '$installed of $total apps installed.';
  }

  @override
  String appsNotInstalled(String names) {
    return 'Not installed: $names';
  }

  @override
  String get appsOnlyNote =>
      'Only the app is copied. App data and sign-ins stay on the old phone.';

  @override
  String appsSelected(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count apps · $size',
      one: '1 app · $size',
      zero: 'No apps selected',
    );
    return '$_temp0';
  }

  @override
  String get backUpNow => 'Back up now';

  @override
  String get backingUp => 'Backing up';

  @override
  String get backupFolder => 'Backup folder';

  @override
  String get backupStation => 'Backup station';

  @override
  String get backupStationHint =>
      'Phones on this network or plugged in by USB can back up here.';

  @override
  String get backupToComputer => 'Back up to computer';

  @override
  String get backupToComputerSubtitle =>
      'Incremental, only new files are copied';

  @override
  String get backups => 'Backups';

  @override
  String get backupsHint => 'Every phone backed up to this computer.';

  @override
  String get battery => 'Battery';

  @override
  String get cancel => 'Cancel';

  @override
  String get categoryApps => 'Apps';

  @override
  String get categoryAudio => 'Music';

  @override
  String get categoryCallLogs => 'Call logs';

  @override
  String get categoryContacts => 'Contacts';

  @override
  String get categoryDocuments => 'Documents';

  @override
  String get categoryFiles => 'Files';

  @override
  String categoryFromDevice(String category, String device) {
    return '$category from $device';
  }

  @override
  String get categoryMessages => 'Messages';

  @override
  String get categoryPhotos => 'Photos';

  @override
  String get categoryVideos => 'Videos';

  @override
  String get categoryWallpaper => 'Wallpaper';

  @override
  String get categoryWhatsapp => 'WhatsApp';

  @override
  String get categoryWhatsappBusiness => 'WhatsApp Business';

  @override
  String get changeFolder => 'Change folder';

  @override
  String get chatsAndMedia => 'Chats + media';

  @override
  String get chatsOnly => 'Chats only';

  @override
  String get chooseApk => 'Choose APK...';

  @override
  String get chooseApkDialogTitle => 'Choose the HK Cloner APK';

  @override
  String get chooseApps => 'Choose apps';

  @override
  String get chooseComputer => 'Choose a computer';

  @override
  String get chooseNewPhone => 'Choose the new phone';

  @override
  String get chooseWhatToMove => 'Choose what to move';

  @override
  String get close => 'Close';

  @override
  String get codeWrongDevice => 'The code belongs to a different device.';

  @override
  String get codedAndDesignedBy => 'Coded and designed by Eng. Hisham Khateeb';

  @override
  String get computerOverUsb => 'Computer over USB';

  @override
  String get computerOverUsbSubtitle =>
      'Plug the phone into the computer with HK Cloner open there first';

  @override
  String get confirmContactsImport => 'Confirm the import in Contacts';

  @override
  String get connect => 'Connect';

  @override
  String get connectAPhone => 'Connect a phone';

  @override
  String get connectByAddress => 'Connect by address';

  @override
  String connectFailed(String error) {
    return 'Could not connect: $error';
  }

  @override
  String connectWireless(String host) {
    return 'Wireless: scan the code with HK Cloner, or pick \"$host\" from the list on the phone.';
  }

  @override
  String get connectedEncrypted => 'Connected · encrypted';

  @override
  String contactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count contacts',
      one: '1 contact',
      zero: 'No contacts',
    );
    return '$_temp0';
  }

  @override
  String get contactsImportHint =>
      'Your Contacts app opened with the file. Pick where to save them.';

  @override
  String get contactsNoApp => 'No Contacts app found to import contacts.vcf.';

  @override
  String get contactsReceived => 'Contacts received';

  @override
  String get continueAnotherWay => 'Continue another way';

  @override
  String get copied => 'Copied';

  @override
  String couldNotDelete(String error) {
    return 'Could not delete: $error';
  }

  @override
  String couldNotReach(String name, String error) {
    return 'Could not reach $name: $error';
  }

  @override
  String get creditsBy => ' by Eng. Hisham Khateeb';

  @override
  String get creditsMadeWith => 'Made with ';

  @override
  String get decline => 'Decline';

  @override
  String get delete => 'Delete';

  @override
  String get deleteBackup => 'Delete backup';

  @override
  String deleteBackupBody(String size, String path) {
    return 'This removes $size from\n$path\n\nThe phone itself is not touched.';
  }

  @override
  String deleteBackupTitle(String name) {
    return 'Delete the backup of $name?';
  }

  @override
  String deletedBackup(String name) {
    return 'Deleted the backup of $name.';
  }

  @override
  String get desktopBackupStation => 'Desktop backup station';

  @override
  String get desktopSettingsHint =>
      'Where backups are kept, and about this app.';

  @override
  String get deviceBackups => 'Device backups';

  @override
  String get deviceFallbackName => 'device';

  @override
  String get deviceName => 'Device name';

  @override
  String deviceNameHint(String model) {
    return 'Other phones and computers see this name. Leave it empty to use \"$model\".';
  }

  @override
  String get devices => 'Devices';

  @override
  String get devicesHint =>
      'Phones plugged in by USB or running HK Cloner on this network.';

  @override
  String get differentDevice =>
      'That is a different device than the one you were sending to.';

  @override
  String differentDeviceThan(String name) {
    return 'That is a different device than $name';
  }

  @override
  String get discard => 'Discard';

  @override
  String discoveryBlocked(String name) {
    return 'Android will not ask again. Open Settings > Permissions and allow $name.';
  }

  @override
  String discoveryLocationNote(String version) {
    return 'Android $version calls this permission Location. HK Cloner never reads where you are.';
  }

  @override
  String get discoveryWhy =>
      'Without it, phones on the same Wi-Fi or a USB cable cannot see each other.';

  @override
  String get done => 'Done';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds s';
  }

  @override
  String get encryptedProgressSaved =>
      'Encrypted · progress saved continuously';

  @override
  String get encryption => 'Encryption';

  @override
  String get encryptionHint =>
      'Transfers are end-to-end encrypted on your local network.';

  @override
  String get enterAddress => 'Enter address';

  @override
  String get enterAddressSubtitle =>
      'Shown under the QR code on the other device';

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count files',
      one: '1 file',
      zero: 'No files',
    );
    return '$_temp0';
  }

  @override
  String filesProgress(int done, int total) {
    return '$done of $total files';
  }

  @override
  String get finishWhatsapp => 'Finish WhatsApp';

  @override
  String fromName(String name) {
    return 'from $name';
  }

  @override
  String get grant => 'Grant';

  @override
  String get history => 'History';

  @override
  String get historyHint => 'Recent backups, newest first.';

  @override
  String get homeHeadline => 'Move everything\nto your new phone';

  @override
  String get homeIntro =>
      'Photos, videos, contacts and WhatsApp chats. Over Wi-Fi, hotspot or cable, and it picks up where it left off.';

  @override
  String hotspotFailed(String error) {
    return 'Could not start the hotspot ($error). Use the Settings hotspot instead.';
  }

  @override
  String hotspotOn(String ssid) {
    return 'Hotspot \"$ssid\" is on. The QR code joins it automatically.';
  }

  @override
  String get hotspotUseSettings =>
      'Turn on the hotspot in Settings, connect the old phone to it, then scan.';

  @override
  String get howConnected => 'How are the phones connected?';

  @override
  String get install => 'Install';

  @override
  String get installAll => 'Install all';

  @override
  String get installApps => 'Install apps';

  @override
  String get installAppsHint =>
      'Android asks you to confirm each app. Sign in again in apps that need it.';

  @override
  String get installBlocked =>
      'The phone refused the install. Look at the phone: if it asks, tap Install (or \"Install anyway\"). On Xiaomi phones turn on Developer options > \"Install via USB\". Then try again.';

  @override
  String get installDowngrade =>
      'The phone has a newer HK Cloner than this one. Installing this version means uninstalling the newer one first, which deletes HK Cloner\'s data on the phone. Photos, contacts and other apps are not touched.';

  @override
  String get installExplain =>
      'This computer installs HK Cloner on the phone over the cable, then opens it.';

  @override
  String installFailed(String detail) {
    return 'The install failed: $detail';
  }

  @override
  String get installInvalidApk =>
      'That file isn\'t a working HK Cloner APK. Choose another one.';

  @override
  String installNoSpace(String size) {
    return 'Not enough free space on the phone. Free up at least $size and try again.';
  }

  @override
  String get installNotAuthorized =>
      'The phone does not trust this computer yet. Unlock it and tap Allow on \"Allow USB debugging?\" (tick \"Always allow from this computer\"), then try again.';

  @override
  String get installOnPhone => 'Install on phone';

  @override
  String get installTapInstall =>
      'If the phone asks whether to install, tap Install.';

  @override
  String get installUpdateIncompatible =>
      'A different copy of HK Cloner is on the phone (built on another computer or from another store). Android only replaces it after uninstalling it, which deletes HK Cloner\'s data on the phone: its settings and any unfinished transfer. Photos, contacts and other apps are not touched.';

  @override
  String installingAppOf(String name, int index, int total) {
    return 'Installing $name ($index of $total)';
  }

  @override
  String installingOn(String device) {
    return 'Installing on $device. This takes up to a minute.';
  }

  @override
  String get interruptConnectionLost =>
      'Connection lost. Reconnect (Wi-Fi, hotspot or cable) and tap Resume.';

  @override
  String get interruptLowBatteryPeer =>
      'Battery critical on the other phone. Charge it and tap Resume.';

  @override
  String get interruptLowBatterySelf =>
      'Battery critical on this phone. Charge it and tap Resume.';

  @override
  String get interruptPaused => 'Paused. Tap Resume to continue.';

  @override
  String get interruptStopped =>
      'Stopped. Tap Resume to continue from where it stopped.';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
      zero: 'No items',
    );
    return '$_temp0';
  }

  @override
  String itemsMoved(int done, int total) {
    return '$done of $total items moved';
  }

  @override
  String get keepScreenOn => 'Keep screen on';

  @override
  String get keepScreenOnHint =>
      'While sending or receiving. Some phones slow down Wi-Fi when the screen is off.';

  @override
  String lastBackupAt(String when) {
    return 'Last backup $when';
  }

  @override
  String lastChatBackupDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Last chat backup: $days days ago',
      one: 'Last chat backup: 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String lastChatBackupHours(int hours) {
    return 'Last chat backup: $hours h ago';
  }

  @override
  String get linked => 'Linked';

  @override
  String get loadingApps => 'Loading apps...';

  @override
  String get locationPermission => 'Location';

  @override
  String get lookForPhones => 'Look for phones';

  @override
  String get lookingForDevices =>
      'Looking for devices. On the other device, open HK Cloner and tap Receive.';

  @override
  String get maximize => 'Maximize';

  @override
  String get minimize => 'Minimize';

  @override
  String get modeCableHint => 'Fastest. USB-C to USB-C or an OTG adapter';

  @override
  String get modeHotspot => 'No Wi-Fi around';

  @override
  String get modeHotspotHint =>
      'This phone makes a private hotspot; the QR joins it';

  @override
  String get modeWifi => 'Same Wi-Fi';

  @override
  String get modeWifiHint => 'Phones find each other automatically';

  @override
  String get nearbyDevicesPermission => 'Nearby devices';

  @override
  String get nearbyOnWifi => 'Nearby on Wi-Fi';

  @override
  String get noAddressReachable =>
      'Could not reach the other device at any of its addresses.';

  @override
  String get noAppsFound => 'No apps found';

  @override
  String get noBackupsYet =>
      'No backups yet. Open HK Cloner on a phone and tap \"Back up to computer\".';

  @override
  String noBundledApk(String file) {
    return 'No phone app was found in this copy of HK Cloner. Choose the HK Cloner APK ($file) to install it on the phone.';
  }

  @override
  String noFolderAccess(String path) {
    return 'No access to $path. Grant the folder before receiving.';
  }

  @override
  String get noPhonesFound =>
      'No phones found yet. Open HK Cloner on a phone on the same network.';

  @override
  String get notFindingHelp =>
      'Same Wi-Fi: both phones must be on the same network, and some routers (guest networks) keep devices apart.\n\nUSB cable: open HK Cloner on both phones and tap Allow on both. One phone must work as USB host (OTG); if nothing happens, turn the cable around or use an OTG adapter.\n\nNo router at all: choose \"No Wi-Fi around\" on the new phone and scan its code.';

  @override
  String get notNow => 'Not now';

  @override
  String get nothingBackedUp => 'Nothing backed up yet.';

  @override
  String get nothingLost =>
      'Nothing is lost. Resume here, or switch to hotspot, USB cable or a QR code.';

  @override
  String notifReceiving(String done, String total, String speed) {
    return '$done of $total · $speed';
  }

  @override
  String notifSending(int done, int total, String speed) {
    return '$done/$total files · $speed';
  }

  @override
  String get notifStarting => 'Starting...';

  @override
  String notifTimeLeft(String time) {
    return '$time left';
  }

  @override
  String get open => 'Open';

  @override
  String get openAndroidAppSettings => 'Open Android app settings';

  @override
  String get openAndroidAppSettingsHint =>
      'Permissions, storage and notifications for HK Cloner';

  @override
  String get openSettings => 'Open settings';

  @override
  String get openWhatsapp => 'Open WhatsApp';

  @override
  String get overview => 'Overview';

  @override
  String get pause => 'Pause';

  @override
  String get paused => 'Paused';

  @override
  String get peerBatteryLowBody =>
      'Plug it in. If it dies, the transfer resumes from where it stopped.';

  @override
  String peerBatteryLowTitle(int level) {
    return 'Sending phone battery is low ($level%)';
  }

  @override
  String get permAllFiles => 'All files (WhatsApp)';

  @override
  String get permAllFilesPurpose =>
      'Read and restore WhatsApp chats on Android 11 and newer';

  @override
  String get permCamera => 'Camera';

  @override
  String get permCameraPurpose => 'Scan the pairing QR code';

  @override
  String get permContactsPurpose => 'Send and receive contacts';

  @override
  String get permLocationPurpose =>
      'Find the other phone on Wi-Fi (never reads where you are)';

  @override
  String get permNearbyPurpose => 'Find the other phone on Wi-Fi and cable';

  @override
  String get permNotifications => 'Notifications';

  @override
  String get permNotificationsPurpose => 'Show progress while a transfer runs';

  @override
  String get permPhotos => 'Photos and videos';

  @override
  String get permPhotosPurpose => 'Send and receive your gallery';

  @override
  String get phone => 'Phone';

  @override
  String get plugInPhone =>
      'Plug in a phone with USB debugging on. HK Cloner installs and opens on it by itself.';

  @override
  String readyAt(String address) {
    return 'Ready · $address';
  }

  @override
  String get receive => 'Receive';

  @override
  String get receiveSubtitle => 'This is my new phone';

  @override
  String receivingFrom(String name) {
    return 'Receiving from $name';
  }

  @override
  String reconnectFirst(String name) {
    return 'Reconnect to $name first';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get restore => 'Restore';

  @override
  String get restoreComplete => 'Restore complete.';

  @override
  String get restoreFromComputer => 'Restore from computer';

  @override
  String get restoreFromComputerSubtitle => 'Bring a backup onto this phone';

  @override
  String get restoreNoPhone =>
      'Open HK Cloner on the phone and tap \"Restore from computer\", or link it by USB.';

  @override
  String restoreStopped(String name, int done, int total) {
    return 'Restore to $name stopped at $done of $total files.';
  }

  @override
  String get restoreToWhichPhone => 'Restore to which phone?';

  @override
  String get restoreWindow => 'Restore';

  @override
  String get resume => 'Resume';

  @override
  String get retry => 'Retry';

  @override
  String get save => 'Save';

  @override
  String get scanQrCode => 'Scan QR code';

  @override
  String get scanQrCodeSubtitle => 'Works on hotspot and USB cable too';

  @override
  String get scanTheCode => 'Scan the code';

  @override
  String get scanThisWithOldPhone =>
      'Scan this with HK Cloner on your old phone';

  @override
  String get scanning => 'Scanning...';

  @override
  String get searchApps => 'Search apps';

  @override
  String get sectionAbout => 'About';

  @override
  String get sectionAppearance => 'Appearance';

  @override
  String get sectionComputer => 'Computer';

  @override
  String get sectionContent => 'Content';

  @override
  String get sectionLanguage => 'Language';

  @override
  String get sectionNearby => 'Nearby';

  @override
  String get sectionNotFinding => 'Not finding it?';

  @override
  String get sectionOtherWays => 'Other ways to connect';

  @override
  String get sectionPermissions => 'Permissions';

  @override
  String get sectionPhoneToPhone => 'Phone to phone';

  @override
  String get sectionProgress => 'Progress';

  @override
  String get sectionThisPhone => 'This phone';

  @override
  String get sectionTransfers => 'Transfers';

  @override
  String get selectAll => 'Select all';

  @override
  String get selectNone => 'Select none';

  @override
  String get selfBatteryLowBody =>
      'Plug in this phone. Progress is saved, so the transfer can resume if it turns off.';

  @override
  String selfBatteryLowTitle(int level) {
    return 'Battery low ($level%)';
  }

  @override
  String get send => 'Send';

  @override
  String get sendSubtitle => 'This is my old phone';

  @override
  String sendingTo(String name) {
    return 'Sending to $name';
  }

  @override
  String get sentFromLocalSend => 'Sent from LocalSend.';

  @override
  String get sentFromLocalSendDownloads =>
      'Sent from LocalSend. Files go to Downloads.';

  @override
  String get settings => 'Settings';

  @override
  String get sidebarEncrypted => 'End-to-end encrypted on your local network';

  @override
  String sizeOfSize(String done, String total) {
    return '$done of $total';
  }

  @override
  String get sortName => 'Name';

  @override
  String get sortSize => 'Size';

  @override
  String get startBackup => 'Start backup';

  @override
  String get startTransfer => 'Start transfer';

  @override
  String startupFailed(String error) {
    return 'Could not start: $error';
  }

  @override
  String get startupPreparing => 'Preparing secure connection...';

  @override
  String get storedInBackupFolder =>
      'Everything is stored in this device\'s backup folder.';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get thisComputer => 'This computer';

  @override
  String get thisPhone => 'This phone';

  @override
  String get tickToScan => 'Tick to scan';

  @override
  String get timeLeft => 'Time left';

  @override
  String get total => 'Total';

  @override
  String get transferComplete => 'Transfer complete';

  @override
  String transferFailed(String error) {
    return 'Transfer failed: $error';
  }

  @override
  String get transferPaused => 'Transfer paused';

  @override
  String get transfersShowLive => 'Transfers show up here live.';

  @override
  String get tryAgain => 'Try again';

  @override
  String unfinishedTransferTo(String name) {
    return 'Unfinished transfer to $name';
  }

  @override
  String get uninstallAndInstall => 'Uninstall and install';

  @override
  String get unknownError => 'unknown error';

  @override
  String updateExplain(String version) {
    return 'The phone has version $version. Updating keeps its data.';
  }

  @override
  String get updateOnPhone => 'Update on phone';

  @override
  String get usbCable => 'USB cable';

  @override
  String get usbComputerUnreachable =>
      'Could not reach the computer over USB. Unplug and plug the cable back in.';

  @override
  String get usbConnectHint =>
      'Connect the phones with a USB-C cable (or an OTG adapter) and open HK Cloner on both. Then tap Allow on both phones.';

  @override
  String get usbConnected =>
      'Connected by cable. On the old phone, tap Send: this phone is at the top of the list.';

  @override
  String get usbDenied =>
      'USB access was not allowed. Unplug the cable, plug it back in and tap Allow.';

  @override
  String get usbDetached =>
      'The cable was unplugged. Plug it back in: the transfer continues where it stopped.';

  @override
  String usbDeviceName(String name) {
    return 'USB: $name';
  }

  @override
  String get usbError =>
      'The cable link failed. Unplug it and plug it back in.';

  @override
  String get usbNoLink =>
      'The phones have not found each other over the cable. One of them must act as USB host (OTG): try turning the cable around, another USB-C cable, or an OTG adapter on the new phone. Or use \"No Wi-Fi around\".';

  @override
  String get usbPermission =>
      'Tap Allow on this phone so HK Cloner can use the cable.';

  @override
  String get usbSwitching =>
      'Almost there. On the other phone, tap OK to open HK Cloner, then Allow.';

  @override
  String get usbUnsupported =>
      'The device on the cable cannot do phone-to-phone transfers. \"No Wi-Fi around\" works without a cable or a router.';

  @override
  String get useNoWifiMode => 'Use \"No Wi-Fi around\"';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get waitingForPhone => 'Waiting for a phone';

  @override
  String wallpaperFailed(String error) {
    return 'Could not set the wallpaper: $error';
  }

  @override
  String get wallpaperNeedsAllFiles =>
      'Android only shares the wallpaper with apps that have All-files access.';

  @override
  String get wallpaperSet => 'Wallpaper set';

  @override
  String get wallpaperSetHint =>
      'The home and lock screens now match your old phone.';

  @override
  String wantsToSend(String name) {
    return '$name wants to send';
  }

  @override
  String get whatsappBackupSteps =>
      'In WhatsApp: Settings > Chats > Chat backup > Back up. Then come back here.';

  @override
  String get whatsappGoesToFolder =>
      'WhatsApp files go to the folder WhatsApp uses on this Android version.';

  @override
  String get whatsappNeedsGrant =>
      'Android 11+ needs your OK to read this folder.';

  @override
  String get whatsappRestoreSteps =>
      '1. Install it from the Play Store (if it is installed already, uninstall and reinstall it).\n2. Verify the same phone number.\n3. Tap \"Restore\" when it finds the local backup.';

  @override
  String get whereBackupsGo => 'Where should backups go?';
}
