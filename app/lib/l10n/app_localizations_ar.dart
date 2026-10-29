// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class SAr extends S {
  SAr([String locale = 'ar']) : super(locale);

  @override
  String get accept => 'قبول';

  @override
  String get adbChecking => 'جارٍ البحث عن HK Cloner...';

  @override
  String get adbInstalledOpened =>
      'تم التثبيت والفتح. اختر على الهاتف ما تريد نسخه احتياطيًا.';

  @override
  String get adbMissing => 'HK Cloner غير مثبت على الهاتف';

  @override
  String get adbMissingRetry =>
      'HK Cloner غير مثبت على الهاتف. انقر إعادة المحاولة لتثبيته.';

  @override
  String get adbOlderOpened =>
      'فُتح إصدار HK Cloner القديم على الهاتف. انقر إعادة المحاولة لتحديثه.';

  @override
  String get adbOpened => 'فُتح على الهاتف. اختر هناك ما تريد نسخه احتياطيًا.';

  @override
  String get adbOutdated => 'إصدار HK Cloner قديم';

  @override
  String adbSetupFailed(String error) {
    return 'فشل الإعداد: $error';
  }

  @override
  String get adbTapAllow => 'اضغط \"سماح\" على الهاتف ليثق بهذا الكمبيوتر';

  @override
  String get adbUpdatedOpened =>
      'تم التحديث والفتح. اختر على الهاتف ما تريد نسخه احتياطيًا.';

  @override
  String get allDone => 'اكتمل كل شيء';

  @override
  String get allow => 'سماح';

  @override
  String allowPermissionToFind(String name) {
    return 'اسمح بإذن \"$name\" للعثور على الهاتف الآخر';
  }

  @override
  String get allowWhatsappFolder => 'السماح بمجلد واتساب';

  @override
  String get allowWhatsappFolderHint =>
      'مطلوب مرة واحدة على أندرويد 11 وما بعده لاستعادة المحادثات.';

  @override
  String get allowed => 'مسموح';

  @override
  String androidApi(int level) {
    return 'أندرويد API $level';
  }

  @override
  String androidVersion(String version) {
    return 'أندرويد $version';
  }

  @override
  String apkSummary(String version, String size) {
    return 'HK Cloner $version · $size';
  }

  @override
  String appMissingOn(String device) {
    return 'HK Cloner غير مثبت على $device';
  }

  @override
  String appOutdatedOn(String device) {
    return 'إصدار HK Cloner على $device قديم';
  }

  @override
  String get appTitle => 'HK Cloner';

  @override
  String get backUpNow => 'انسخ الآن';

  @override
  String get backingUp => 'جارٍ النسخ الاحتياطي';

  @override
  String get backupFolder => 'مجلد النسخ الاحتياطي';

  @override
  String get backupStation => 'محطة النسخ الاحتياطي';

  @override
  String get backupStationHint =>
      'يمكن للهواتف على هذه الشبكة أو الموصولة عبر USB أن تحفظ نسخها الاحتياطية هنا.';

  @override
  String get backupToComputer => 'نسخ احتياطي إلى الكمبيوتر';

  @override
  String get backupToComputerSubtitle => 'تدريجي: تُنسخ الملفات الجديدة فقط';

  @override
  String get backups => 'النسخ الاحتياطية';

  @override
  String get backupsHint => 'كل هاتف نُسخ احتياطيًا على هذا الكمبيوتر.';

  @override
  String get battery => 'البطارية';

  @override
  String get cancel => 'إلغاء';

  @override
  String get categoryApps => 'التطبيقات';

  @override
  String get categoryAudio => 'الموسيقى';

  @override
  String get categoryCallLogs => 'سجل المكالمات';

  @override
  String get categoryContacts => 'جهات الاتصال';

  @override
  String get categoryDocuments => 'المستندات';

  @override
  String get categoryFiles => 'الملفات';

  @override
  String categoryFromDevice(String category, String device) {
    return '$category من $device';
  }

  @override
  String get categoryMessages => 'الرسائل';

  @override
  String get categoryPhotos => 'الصور';

  @override
  String get categoryVideos => 'الفيديوهات';

  @override
  String get categoryWallpaper => 'خلفية الشاشة';

  @override
  String get categoryWhatsapp => 'واتساب';

  @override
  String get categoryWhatsappBusiness => 'واتساب للأعمال';

  @override
  String get changeFolder => 'تغيير المجلد';

  @override
  String get chatsAndMedia => 'المحادثات + الوسائط';

  @override
  String get chatsOnly => 'المحادثات فقط';

  @override
  String get chooseApk => 'اختيار ملف APK...';

  @override
  String get chooseApkDialogTitle => 'اختر ملف HK Cloner بصيغة APK';

  @override
  String get chooseComputer => 'اختر جهاز كمبيوتر';

  @override
  String get chooseNewPhone => 'اختر الهاتف الجديد';

  @override
  String get chooseWhatToMove => 'اختر ما تريد نقله';

  @override
  String get close => 'إغلاق';

  @override
  String get codeWrongDevice => 'هذا الرمز يخص جهازًا مختلفًا.';

  @override
  String get codedAndDesignedBy => 'برمجة وتصميم م. هشام الخطيب';

  @override
  String get computerOverUsb => 'الكمبيوتر عبر USB';

  @override
  String get computerOverUsbSubtitle =>
      'وصّل الهاتف بالكمبيوتر بعد فتح HK Cloner عليه';

  @override
  String get confirmContactsImport => 'أكّد الاستيراد في جهات الاتصال';

  @override
  String get connect => 'اتصال';

  @override
  String get connectAPhone => 'وصّل هاتفًا';

  @override
  String get connectByAddress => 'الاتصال بالعنوان';

  @override
  String connectFailed(String error) {
    return 'تعذّر الاتصال: $error';
  }

  @override
  String connectWireless(String host) {
    return 'لاسلكيًا: امسح الرمز بتطبيق HK Cloner، أو اختر \"$host\" من القائمة على الهاتف.';
  }

  @override
  String get connectedEncrypted => 'متصل · مشفّر';

  @override
  String contactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جهة اتصال',
      many: '$count جهة اتصال',
      few: '$count جهات اتصال',
      two: 'جهتا اتصال',
      one: 'جهة اتصال واحدة',
      zero: 'لا جهات اتصال',
    );
    return '$_temp0';
  }

  @override
  String get contactsImportHint =>
      'فُتح تطبيق جهات الاتصال مع الملف. اختر مكان حفظها.';

  @override
  String get contactsReceived => 'تم استلام جهات الاتصال';

  @override
  String get continueAnotherWay => 'المتابعة بطريقة أخرى';

  @override
  String get copied => 'تم نسخه';

  @override
  String couldNotDelete(String error) {
    return 'تعذّر الحذف: $error';
  }

  @override
  String couldNotReach(String name, String error) {
    return 'تعذّر الوصول إلى $name: $error';
  }

  @override
  String get creditsBy => ' بواسطة م. هشام الخطيب';

  @override
  String get creditsMadeWith => 'صُنع بـ ';

  @override
  String get decline => 'رفض';

  @override
  String get delete => 'حذف';

  @override
  String get deleteBackup => 'حذف النسخة الاحتياطية';

  @override
  String deleteBackupBody(String size, String path) {
    return 'سيؤدي هذا إلى حذف $size من\n$path\n\nلن يُمس الهاتف نفسه.';
  }

  @override
  String deleteBackupTitle(String name) {
    return 'حذف النسخة الاحتياطية لـ $name؟';
  }

  @override
  String deletedBackup(String name) {
    return 'تم حذف النسخة الاحتياطية لـ $name.';
  }

  @override
  String get desktopBackupStation => 'محطة النسخ الاحتياطي على الكمبيوتر';

  @override
  String get desktopSettingsHint =>
      'مكان حفظ النسخ الاحتياطية، ومعلومات عن التطبيق.';

  @override
  String get deviceBackups => 'نسخ الأجهزة الاحتياطية';

  @override
  String get deviceFallbackName => 'الجهاز';

  @override
  String get deviceName => 'اسم الجهاز';

  @override
  String deviceNameHint(String model) {
    return 'تظهر هذه التسمية للهواتف وأجهزة الكمبيوتر الأخرى. اتركها فارغة لاستخدام \"$model\".';
  }

  @override
  String get devices => 'الأجهزة';

  @override
  String get devicesHint =>
      'الهواتف الموصولة عبر USB أو التي تشغّل HK Cloner على هذه الشبكة.';

  @override
  String get differentDevice => 'هذا جهاز مختلف عن الجهاز الذي كنت ترسل إليه.';

  @override
  String differentDeviceThan(String name) {
    return 'هذا جهاز مختلف عن $name';
  }

  @override
  String get discard => 'تجاهل';

  @override
  String discoveryBlocked(String name) {
    return 'لن يطلب أندرويد الإذن مرة أخرى. افتح الإعدادات > الأذونات واسمح بـ $name.';
  }

  @override
  String discoveryLocationNote(String version) {
    return 'يسمّي أندرويد $version هذا الإذن \"الموقع\". لا يقرأ HK Cloner موقعك أبدًا.';
  }

  @override
  String get discoveryWhy =>
      'بدونه لا يستطيع الهاتفان رؤية بعضهما على شبكة Wi-Fi نفسها أو عبر كابل USB.';

  @override
  String get done => 'تم';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours س $minutes د';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes د';
  }

  @override
  String durationSeconds(int seconds) {
    return '$seconds ث';
  }

  @override
  String get encryptedProgressSaved => 'مشفّر · يُحفظ التقدّم باستمرار';

  @override
  String get encryption => 'التشفير';

  @override
  String get encryptionHint =>
      'عمليات النقل مشفّرة من طرف إلى طرف على شبكتك المحلية.';

  @override
  String get enterAddress => 'إدخال العنوان';

  @override
  String get enterAddressSubtitle => 'يظهر أسفل رمز QR على الجهاز الآخر';

  @override
  String filesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملف',
      many: '$count ملفًا',
      few: '$count ملفات',
      two: 'ملفان',
      one: 'ملف واحد',
      zero: 'لا ملفات',
    );
    return '$_temp0';
  }

  @override
  String filesProgress(int done, int total) {
    return '$done من $total ملف';
  }

  @override
  String get finishWhatsapp => 'أكمل إعداد واتساب';

  @override
  String fromName(String name) {
    return 'من $name';
  }

  @override
  String get grant => 'منح الإذن';

  @override
  String get history => 'السجل';

  @override
  String get historyHint => 'أحدث النسخ الاحتياطية، الأحدث أولًا.';

  @override
  String get homeHeadline => 'انقل كل شيء\nإلى هاتفك الجديد';

  @override
  String get homeIntro =>
      'الصور والفيديوهات وجهات الاتصال ومحادثات واتساب. عبر Wi-Fi أو نقطة اتصال أو كابل، ويُكمل النقل من حيث توقف.';

  @override
  String hotspotFailed(String error) {
    return 'تعذّر تشغيل نقطة الاتصال ($error). استخدم نقطة الاتصال من الإعدادات بدلًا من ذلك.';
  }

  @override
  String hotspotOn(String ssid) {
    return 'نقطة الاتصال \"$ssid\" تعمل. ينضم إليها رمز QR تلقائيًا.';
  }

  @override
  String get hotspotUseSettings =>
      'شغّل نقطة الاتصال من الإعدادات، ووصّل الهاتف القديم بها، ثم امسح الرمز.';

  @override
  String get howConnected => 'كيف يتصل الهاتفان؟';

  @override
  String get installBlocked =>
      'رفض الهاتف التثبيت. انظر إلى الهاتف: إن ظهر سؤال، اضغط تثبيت (أو \"التثبيت على أي حال\"). في هواتف Xiaomi فعّل خيارات المطوّر > \"التثبيت عبر USB\". ثم حاول مجددًا.';

  @override
  String get installDowngrade =>
      'على الهاتف إصدار أحدث من HK Cloner. تثبيت هذا الإصدار يعني إلغاء تثبيت الأحدث أولًا، وهذا يحذف بيانات HK Cloner على الهاتف. لن تُمس الصور وجهات الاتصال والتطبيقات الأخرى.';

  @override
  String get installExplain =>
      'سيثبّت هذا الكمبيوتر HK Cloner على الهاتف عبر الكابل ثم يفتحه.';

  @override
  String installFailed(String detail) {
    return 'فشل التثبيت: $detail';
  }

  @override
  String get installInvalidApk =>
      'هذا الملف ليس ملف APK صالحًا لـ HK Cloner. اختر ملفًا آخر.';

  @override
  String installNoSpace(String size) {
    return 'لا توجد مساحة كافية على الهاتف. حرّر $size على الأقل ثم حاول مجددًا.';
  }

  @override
  String get installNotAuthorized =>
      'الهاتف لا يثق بهذا الكمبيوتر بعد. افتح قفله واضغط سماح على \"السماح بتصحيح أخطاء USB؟\" (حدّد \"السماح دائمًا من هذا الكمبيوتر\")، ثم حاول مجددًا.';

  @override
  String get installOnPhone => 'التثبيت على الهاتف';

  @override
  String get installTapInstall => 'إذا سألك الهاتف عن التثبيت، اضغط تثبيت.';

  @override
  String get installUpdateIncompatible =>
      'على الهاتف نسخة مختلفة من HK Cloner (من كمبيوتر آخر أو من متجر آخر). لا يستبدلها أندرويد إلا بعد إلغاء تثبيتها، وهذا يحذف بيانات HK Cloner على الهاتف: إعداداته وأي نقل غير مكتمل. لن تُمس الصور وجهات الاتصال والتطبيقات الأخرى.';

  @override
  String installingOn(String device) {
    return 'جارٍ التثبيت على $device. قد يستغرق ذلك دقيقة.';
  }

  @override
  String get interruptConnectionLost =>
      'انقطع الاتصال. أعد الاتصال (Wi-Fi أو نقطة اتصال أو كابل) واضغط استئناف.';

  @override
  String get interruptLowBatteryPeer =>
      'البطارية منخفضة جدًا على الهاتف الآخر. اشحنه واضغط استئناف.';

  @override
  String get interruptLowBatterySelf =>
      'البطارية منخفضة جدًا على هذا الهاتف. اشحنه واضغط استئناف.';

  @override
  String get interruptPaused => 'متوقف مؤقتًا. اضغط استئناف للمتابعة.';

  @override
  String get interruptStopped =>
      'توقف النقل. اضغط استئناف للمتابعة من حيث توقف.';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String itemsMoved(int done, int total) {
    return 'تم نقل $done من $total عنصر';
  }

  @override
  String get keepScreenOn => 'إبقاء الشاشة مضاءة';

  @override
  String get keepScreenOnHint =>
      'أثناء الإرسال أو الاستقبال. بعض الهواتف تُبطئ شبكة Wi-Fi عند إطفاء الشاشة.';

  @override
  String lastBackupAt(String when) {
    return 'آخر نسخة احتياطية $when';
  }

  @override
  String lastChatBackupDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'آخر نسخة احتياطية للمحادثات: منذ $days يوم',
      many: 'آخر نسخة احتياطية للمحادثات: منذ $days يومًا',
      few: 'آخر نسخة احتياطية للمحادثات: منذ $days أيام',
      two: 'آخر نسخة احتياطية للمحادثات: منذ يومين',
      one: 'آخر نسخة احتياطية للمحادثات: منذ يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String lastChatBackupHours(int hours) {
    return 'آخر نسخة احتياطية للمحادثات: منذ $hours س';
  }

  @override
  String get linked => 'متصل';

  @override
  String get locationPermission => 'الموقع';

  @override
  String get lookForPhones => 'البحث عن هواتف';

  @override
  String get lookingForDevices =>
      'جارٍ البحث عن الأجهزة. على الجهاز الآخر، افتح HK Cloner واضغط استقبال.';

  @override
  String get maximize => 'تكبير';

  @override
  String get minimize => 'تصغير';

  @override
  String get modeCableHint => 'الأسرع. كابل USB-C إلى USB-C أو محوّل OTG';

  @override
  String get modeHotspot => 'لا توجد شبكة Wi-Fi';

  @override
  String get modeHotspotHint =>
      'ينشئ هذا الهاتف نقطة اتصال خاصة، وينضم إليها رمز QR';

  @override
  String get modeWifi => 'نفس شبكة Wi-Fi';

  @override
  String get modeWifiHint => 'يجد الهاتفان بعضهما تلقائيًا';

  @override
  String get nearbyDevicesPermission => 'الأجهزة المجاورة';

  @override
  String get nearbyOnWifi => 'قريبة على شبكة Wi-Fi';

  @override
  String get noAddressReachable =>
      'تعذّر الوصول إلى الجهاز الآخر على أيٍّ من عناوينه.';

  @override
  String get noBackupsYet =>
      'لا توجد نسخ احتياطية بعد. افتح HK Cloner على هاتف واضغط \"نسخ احتياطي إلى الكمبيوتر\".';

  @override
  String noBundledApk(String file) {
    return 'لم يُعثر على تطبيق الهاتف في هذه النسخة من HK Cloner. اختر ملف HK Cloner بصيغة APK ($file) لتثبيته على الهاتف.';
  }

  @override
  String noFolderAccess(String path) {
    return 'لا يوجد وصول إلى $path. امنح الإذن للمجلد قبل الاستقبال.';
  }

  @override
  String get noPhonesFound =>
      'لم يُعثر على هواتف بعد. افتح HK Cloner على هاتف متصل بالشبكة نفسها.';

  @override
  String get notFindingHelp =>
      'نفس شبكة Wi-Fi: يجب أن يكون الهاتفان على الشبكة نفسها، وبعض أجهزة الراوتر (شبكات الضيوف) تعزل الأجهزة عن بعضها.\n\nكابل USB: افتح HK Cloner على الهاتفين واضغط سماح على كليهما. يجب أن يعمل أحد الهاتفين كمضيف USB (OTG)؛ إن لم يحدث شيء، اقلب الكابل أو استخدم محوّل OTG.\n\nلا يوجد راوتر إطلاقًا: اختر \"لا توجد شبكة Wi-Fi\" على الهاتف الجديد وامسح رمزه.';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get nothingBackedUp => 'لم يُنسخ شيء احتياطيًا بعد.';

  @override
  String get nothingLost =>
      'لم يضِع شيء. استأنف من هنا، أو انتقل إلى نقطة الاتصال أو كابل USB أو رمز QR.';

  @override
  String notifReceiving(String done, String total, String speed) {
    return '$done من $total · $speed';
  }

  @override
  String notifSending(int done, int total, String speed) {
    return '$done/$total ملف · $speed';
  }

  @override
  String get notifStarting => 'جارٍ البدء...';

  @override
  String notifTimeLeft(String time) {
    return 'متبقٍ $time';
  }

  @override
  String get open => 'فتح';

  @override
  String get openAndroidAppSettings => 'فتح إعدادات التطبيق في أندرويد';

  @override
  String get openAndroidAppSettingsHint =>
      'الأذونات والتخزين والإشعارات لتطبيق HK Cloner';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get openWhatsapp => 'فتح واتساب';

  @override
  String get overview => 'نظرة عامة';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get paused => 'متوقف مؤقتًا';

  @override
  String get peerBatteryLowBody =>
      'وصّله بالشاحن. إن انطفأ، يُستأنف النقل من حيث توقف.';

  @override
  String peerBatteryLowTitle(int level) {
    return 'بطارية الهاتف المُرسِل منخفضة ($level%)';
  }

  @override
  String get permAllFiles => 'جميع الملفات (واتساب)';

  @override
  String get permAllFilesPurpose =>
      'قراءة محادثات واتساب واستعادتها على أندرويد 11 وما بعده';

  @override
  String get permCamera => 'الكاميرا';

  @override
  String get permCameraPurpose => 'مسح رمز QR للاقتران';

  @override
  String get permContactsPurpose => 'إرسال جهات الاتصال واستقبالها';

  @override
  String get permLocationPurpose =>
      'العثور على الهاتف الآخر عبر Wi-Fi (لا يقرأ موقعك أبدًا)';

  @override
  String get permNearbyPurpose => 'العثور على الهاتف الآخر عبر Wi-Fi والكابل';

  @override
  String get permNotifications => 'الإشعارات';

  @override
  String get permNotificationsPurpose => 'عرض التقدّم أثناء النقل';

  @override
  String get permPhotos => 'الصور والفيديوهات';

  @override
  String get permPhotosPurpose => 'إرسال معرض الصور واستقباله';

  @override
  String get phone => 'الهاتف';

  @override
  String get plugInPhone =>
      'وصّل هاتفًا مع تفعيل تصحيح أخطاء USB. سيُثبَّت HK Cloner ويُفتح عليه تلقائيًا.';

  @override
  String readyAt(String address) {
    return 'جاهز · $address';
  }

  @override
  String get receive => 'استقبال';

  @override
  String get receiveSubtitle => 'هذا هاتفي الجديد';

  @override
  String receivingFrom(String name) {
    return 'جارٍ الاستقبال من $name';
  }

  @override
  String reconnectFirst(String name) {
    return 'أعد الاتصال بـ $name أولًا';
  }

  @override
  String get refresh => 'تحديث';

  @override
  String get restore => 'استعادة';

  @override
  String get restoreComplete => 'اكتملت الاستعادة.';

  @override
  String get restoreFromComputer => 'استعادة من الكمبيوتر';

  @override
  String get restoreFromComputerSubtitle =>
      'استرجع نسخة احتياطية إلى هذا الهاتف';

  @override
  String get restoreNoPhone =>
      'افتح HK Cloner على الهاتف واضغط \"استعادة من الكمبيوتر\"، أو صِله عبر USB.';

  @override
  String restoreStopped(String name, int done, int total) {
    return 'توقفت الاستعادة إلى $name عند $done من $total ملف.';
  }

  @override
  String get restoreToWhichPhone => 'الاستعادة إلى أي هاتف؟';

  @override
  String get restoreWindow => 'استعادة الحجم';

  @override
  String get resume => 'استئناف';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get save => 'حفظ';

  @override
  String get scanQrCode => 'مسح رمز QR';

  @override
  String get scanQrCodeSubtitle => 'يعمل أيضًا مع نقطة الاتصال وكابل USB';

  @override
  String get scanTheCode => 'امسح الرمز';

  @override
  String get scanThisWithOldPhone =>
      'امسح هذا الرمز بتطبيق HK Cloner على هاتفك القديم';

  @override
  String get scanning => 'جارٍ الفحص...';

  @override
  String get sectionAbout => 'حول التطبيق';

  @override
  String get sectionAppearance => 'المظهر';

  @override
  String get sectionComputer => 'الكمبيوتر';

  @override
  String get sectionContent => 'المحتوى';

  @override
  String get sectionLanguage => 'اللغة';

  @override
  String get sectionNearby => 'بالقرب منك';

  @override
  String get sectionNotFinding => 'لا يظهر الجهاز؟';

  @override
  String get sectionOtherWays => 'طرق أخرى للاتصال';

  @override
  String get sectionPermissions => 'الأذونات';

  @override
  String get sectionPhoneToPhone => 'من هاتف إلى هاتف';

  @override
  String get sectionProgress => 'التقدّم';

  @override
  String get sectionThisPhone => 'هذا الهاتف';

  @override
  String get sectionTransfers => 'النقل';

  @override
  String get selfBatteryLowBody =>
      'وصّل هذا الهاتف بالشاحن. التقدّم محفوظ، فيمكن استئناف النقل إن انطفأ.';

  @override
  String selfBatteryLowTitle(int level) {
    return 'البطارية منخفضة ($level%)';
  }

  @override
  String get send => 'إرسال';

  @override
  String get sendSubtitle => 'هذا هاتفي القديم';

  @override
  String sendingTo(String name) {
    return 'جارٍ الإرسال إلى $name';
  }

  @override
  String get sentFromLocalSend => 'مُرسل من LocalSend.';

  @override
  String get sentFromLocalSendDownloads =>
      'مُرسل من LocalSend. تُحفظ الملفات في التنزيلات.';

  @override
  String get settings => 'الإعدادات';

  @override
  String get sidebarEncrypted => 'مشفّر من طرف إلى طرف على شبكتك المحلية';

  @override
  String sizeOfSize(String done, String total) {
    return '$done من $total';
  }

  @override
  String get startBackup => 'بدء النسخ الاحتياطي';

  @override
  String get startTransfer => 'بدء النقل';

  @override
  String startupFailed(String error) {
    return 'تعذّر التشغيل: $error';
  }

  @override
  String get startupPreparing => 'جارٍ تجهيز الاتصال الآمن...';

  @override
  String get storedInBackupFolder =>
      'يُحفظ كل شيء في مجلد النسخ الاحتياطي لهذا الجهاز.';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'النظام';

  @override
  String get thisComputer => 'هذا الكمبيوتر';

  @override
  String get thisPhone => 'هذا الهاتف';

  @override
  String get tickToScan => 'حدّد للفحص';

  @override
  String get timeLeft => 'الوقت المتبقي';

  @override
  String get total => 'الإجمالي';

  @override
  String get transferComplete => 'اكتمل النقل';

  @override
  String transferFailed(String error) {
    return 'فشل النقل: $error';
  }

  @override
  String get transferPaused => 'توقف النقل مؤقتًا';

  @override
  String get transfersShowLive => 'تظهر عمليات النقل هنا مباشرة.';

  @override
  String get tryAgain => 'حاول مجددًا';

  @override
  String unfinishedTransferTo(String name) {
    return 'نقل غير مكتمل إلى $name';
  }

  @override
  String get uninstallAndInstall => 'إلغاء التثبيت ثم التثبيت';

  @override
  String get unknownError => 'خطأ غير معروف';

  @override
  String updateExplain(String version) {
    return 'على الهاتف الإصدار $version. التحديث يحتفظ ببياناته.';
  }

  @override
  String get updateOnPhone => 'التحديث على الهاتف';

  @override
  String get usbCable => 'كابل USB';

  @override
  String get usbComputerUnreachable =>
      'تعذّر الوصول إلى الكمبيوتر عبر USB. افصل الكابل ثم أعد توصيله.';

  @override
  String get usbConnectHint =>
      'وصّل الهاتفين بكابل USB-C (أو محوّل OTG) وافتح HK Cloner على كليهما. ثم اضغط سماح على الهاتفين.';

  @override
  String get usbConnected =>
      'متصل بالكابل. على الهاتف القديم، اضغط إرسال: سيظهر هذا الهاتف في أعلى القائمة.';

  @override
  String get usbDenied =>
      'لم يُسمح بالوصول إلى USB. افصل الكابل، ثم أعد توصيله واضغط سماح.';

  @override
  String get usbDetached =>
      'فُصل الكابل. أعد توصيله وسيُكمل النقل من حيث توقف.';

  @override
  String usbDeviceName(String name) {
    return 'USB: $name';
  }

  @override
  String get usbError => 'فشل الاتصال عبر الكابل. افصله ثم أعد توصيله.';

  @override
  String get usbNoLink =>
      'لم يتعرّف الهاتفان على بعضهما عبر الكابل. يجب أن يعمل أحدهما كمضيف USB (OTG): جرّب قلب الكابل، أو كابل USB-C آخر، أو محوّل OTG على الهاتف الجديد. أو استخدم \"لا توجد شبكة Wi-Fi\".';

  @override
  String get usbPermission =>
      'اضغط سماح على هذا الهاتف ليتمكن HK Cloner من استخدام الكابل.';

  @override
  String get usbSwitching =>
      'اقتربنا. على الهاتف الآخر، اضغط موافق لفتح HK Cloner، ثم سماح.';

  @override
  String get usbUnsupported =>
      'الجهاز الموصول بالكابل لا يدعم النقل بين الهواتف. يعمل خيار \"لا توجد شبكة Wi-Fi\" دون كابل أو راوتر.';

  @override
  String get useNoWifiMode => 'استخدم \"لا توجد شبكة Wi-Fi\"';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get waitingForPhone => 'في انتظار هاتف';

  @override
  String wallpaperFailed(String error) {
    return 'تعذّر تعيين خلفية الشاشة: $error';
  }

  @override
  String get wallpaperNeedsAllFiles =>
      'لا يشارك أندرويد خلفية الشاشة إلا مع التطبيقات التي لديها إذن الوصول إلى جميع الملفات.';

  @override
  String get wallpaperSet => 'تم تعيين خلفية الشاشة';

  @override
  String get wallpaperSetHint =>
      'أصبحت الشاشة الرئيسية وشاشة القفل مطابقتين لهاتفك القديم.';

  @override
  String wantsToSend(String name) {
    return 'يريد $name الإرسال';
  }

  @override
  String get whatsappBackupSteps =>
      'في واتساب: الإعدادات > الدردشات > النسخ الاحتياطي للدردشات > نسخ احتياطي. ثم عُد إلى هنا.';

  @override
  String get whatsappGoesToFolder =>
      'تُحفظ ملفات واتساب في المجلد الذي يستخدمه واتساب على إصدار أندرويد هذا.';

  @override
  String get whatsappNeedsGrant =>
      'يحتاج أندرويد 11 وما بعده إلى موافقتك لقراءة هذا المجلد.';

  @override
  String get whatsappRestoreSteps =>
      '1. ثبّته من متجر Play (إن كان مثبتًا، أزِل تثبيته ثم ثبّته من جديد).\n2. أكّد رقم الهاتف نفسه.\n3. اضغط \"استعادة\" عندما يعثر على النسخة الاحتياطية المحلية.';

  @override
  String get whereBackupsGo => 'أين تريد حفظ النسخ الاحتياطية؟';
}
