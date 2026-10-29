import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of S
/// returned by `S.of(context)`.
///
/// Applications need to include `S.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: S.localizationsDelegates,
///   supportedLocales: S.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the S.supportedLocales
/// property.
abstract class S {
  S(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static S of(BuildContext context) {
    return Localizations.of<S>(context, S)!;
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @accept.
  ///
  /// In ar, this message translates to:
  /// **'قبول'**
  String get accept;

  /// No description provided for @adbChecking.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البحث عن HK Cloner...'**
  String get adbChecking;

  /// No description provided for @adbInstalledOpened.
  ///
  /// In ar, this message translates to:
  /// **'تم التثبيت والفتح. اختر على الهاتف ما تريد نسخه احتياطيًا.'**
  String get adbInstalledOpened;

  /// No description provided for @adbMissing.
  ///
  /// In ar, this message translates to:
  /// **'HK Cloner غير مثبت على الهاتف'**
  String get adbMissing;

  /// No description provided for @adbMissingRetry.
  ///
  /// In ar, this message translates to:
  /// **'HK Cloner غير مثبت على الهاتف. انقر إعادة المحاولة لتثبيته.'**
  String get adbMissingRetry;

  /// No description provided for @adbOlderOpened.
  ///
  /// In ar, this message translates to:
  /// **'فُتح إصدار HK Cloner القديم على الهاتف. انقر إعادة المحاولة لتحديثه.'**
  String get adbOlderOpened;

  /// No description provided for @adbOpened.
  ///
  /// In ar, this message translates to:
  /// **'فُتح على الهاتف. اختر هناك ما تريد نسخه احتياطيًا.'**
  String get adbOpened;

  /// No description provided for @adbOutdated.
  ///
  /// In ar, this message translates to:
  /// **'إصدار HK Cloner قديم'**
  String get adbOutdated;

  /// No description provided for @adbSetupFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل الإعداد: {error}'**
  String adbSetupFailed(String error);

  /// No description provided for @adbTapAllow.
  ///
  /// In ar, this message translates to:
  /// **'اضغط \"سماح\" على الهاتف ليثق بهذا الكمبيوتر'**
  String get adbTapAllow;

  /// No description provided for @adbUpdatedOpened.
  ///
  /// In ar, this message translates to:
  /// **'تم التحديث والفتح. اختر على الهاتف ما تريد نسخه احتياطيًا.'**
  String get adbUpdatedOpened;

  /// No description provided for @allDone.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل كل شيء'**
  String get allDone;

  /// No description provided for @allow.
  ///
  /// In ar, this message translates to:
  /// **'سماح'**
  String get allow;

  /// No description provided for @allowInstallBody.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج أندرويد إلى تفعيل \"تثبيت التطبيقات غير المعروفة\" لتطبيق HK Cloner. فعّله ثم عُد إلى هنا.'**
  String get allowInstallBody;

  /// No description provided for @allowInstallTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسمح لـ HK Cloner بتثبيت التطبيقات'**
  String get allowInstallTitle;

  /// No description provided for @allowPermissionToFind.
  ///
  /// In ar, this message translates to:
  /// **'اسمح بإذن \"{name}\" للعثور على الهاتف الآخر'**
  String allowPermissionToFind(String name);

  /// No description provided for @allowWhatsappFolder.
  ///
  /// In ar, this message translates to:
  /// **'السماح بمجلد واتساب'**
  String get allowWhatsappFolder;

  /// No description provided for @allowWhatsappFolderHint.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب مرة واحدة على أندرويد 11 وما بعده لاستعادة المحادثات.'**
  String get allowWhatsappFolderHint;

  /// No description provided for @allowed.
  ///
  /// In ar, this message translates to:
  /// **'مسموح'**
  String get allowed;

  /// No description provided for @androidApi.
  ///
  /// In ar, this message translates to:
  /// **'أندرويد API {level}'**
  String androidApi(int level);

  /// No description provided for @androidVersion.
  ///
  /// In ar, this message translates to:
  /// **'أندرويد {version}'**
  String androidVersion(String version);

  /// No description provided for @apkSummary.
  ///
  /// In ar, this message translates to:
  /// **'HK Cloner {version} · {size}'**
  String apkSummary(String version, String size);

  /// No description provided for @appMissingOn.
  ///
  /// In ar, this message translates to:
  /// **'HK Cloner غير مثبت على {device}'**
  String appMissingOn(String device);

  /// No description provided for @appOutdatedOn.
  ///
  /// In ar, this message translates to:
  /// **'إصدار HK Cloner على {device} قديم'**
  String appOutdatedOn(String device);

  /// No description provided for @appStatusAlreadyInstalled.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت مسبقًا (الإصدار نفسه أو أحدث)'**
  String get appStatusAlreadyInstalled;

  /// No description provided for @appStatusCanceled.
  ///
  /// In ar, this message translates to:
  /// **'أُلغي'**
  String get appStatusCanceled;

  /// No description provided for @appStatusFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل: {reason}'**
  String appStatusFailed(String reason);

  /// No description provided for @appStatusIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'لم يُستلم بالكامل'**
  String get appStatusIncomplete;

  /// No description provided for @appStatusInstalled.
  ///
  /// In ar, this message translates to:
  /// **'مثبّت'**
  String get appStatusInstalled;

  /// No description provided for @appStatusInstalling.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التثبيت...'**
  String get appStatusInstalling;

  /// No description provided for @appStatusNeedsAndroid.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج إصدار أندرويد أحدث (API {level})'**
  String appStatusNeedsAndroid(int level);

  /// No description provided for @appTitle.
  ///
  /// In ar, this message translates to:
  /// **'HK Cloner'**
  String get appTitle;

  /// No description provided for @appUnreadable.
  ///
  /// In ar, this message translates to:
  /// **'لا يسمح أندرويد لـ HK Cloner بقراءة هذا التطبيق.'**
  String get appUnreadable;

  /// No description provided for @appsBackedUp.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تم نسخ تطبيق واحد احتياطيًا.} =2{تم نسخ تطبيقين احتياطيًا.} few{تم نسخ {count} تطبيقات احتياطيًا.} many{تم نسخ {count} تطبيقًا احتياطيًا.} other{تم نسخ {count} تطبيق احتياطيًا.}}'**
  String appsBackedUp(int count);

  /// No description provided for @appsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا تطبيقات} =1{تطبيق واحد} =2{تطبيقان} few{{count} تطبيقات} many{{count} تطبيقًا} other{{count} تطبيق}}'**
  String appsCount(int count);

  /// No description provided for @appsInstalledSummary.
  ///
  /// In ar, this message translates to:
  /// **'تم تثبيت {installed} من {total} تطبيق.'**
  String appsInstalledSummary(int installed, int total);

  /// No description provided for @appsNotCopied.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنسخ: {names}'**
  String appsNotCopied(String names);

  /// No description provided for @appsNotInstalled.
  ///
  /// In ar, this message translates to:
  /// **'لم يُثبَّت: {names}'**
  String appsNotInstalled(String names);

  /// No description provided for @appsOnlyNote.
  ///
  /// In ar, this message translates to:
  /// **'يُنسخ التطبيق فقط. تبقى بيانات التطبيق وتسجيلات الدخول على الهاتف القديم.'**
  String get appsOnlyNote;

  /// No description provided for @appsSelected.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم يُحدَّد أي تطبيق} =1{تطبيق واحد · {size}} =2{تطبيقان · {size}} few{{count} تطبيقات · {size}} many{{count} تطبيقًا · {size}} other{{count} تطبيق · {size}}}'**
  String appsSelected(int count, String size);

  /// No description provided for @appsSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت قراءتها ولن تُنقل: {names}'**
  String appsSkipped(String names);

  /// No description provided for @backUpApps.
  ///
  /// In ar, this message translates to:
  /// **'نسخ التطبيقات احتياطيًا'**
  String get backUpApps;

  /// No description provided for @backUpNow.
  ///
  /// In ar, this message translates to:
  /// **'انسخ الآن'**
  String get backUpNow;

  /// No description provided for @backingUp.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ النسخ الاحتياطي'**
  String get backingUp;

  /// No description provided for @backupFolder.
  ///
  /// In ar, this message translates to:
  /// **'مجلد النسخ الاحتياطي'**
  String get backupFolder;

  /// No description provided for @backupStation.
  ///
  /// In ar, this message translates to:
  /// **'محطة النسخ الاحتياطي'**
  String get backupStation;

  /// No description provided for @backupStationHint.
  ///
  /// In ar, this message translates to:
  /// **'يمكن للهواتف على هذه الشبكة أو الموصولة عبر USB أن تحفظ نسخها الاحتياطية هنا.'**
  String get backupStationHint;

  /// No description provided for @backupToComputer.
  ///
  /// In ar, this message translates to:
  /// **'نسخ احتياطي إلى الكمبيوتر'**
  String get backupToComputer;

  /// No description provided for @backupToComputerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'تدريجي: تُنسخ الملفات الجديدة فقط'**
  String get backupToComputerSubtitle;

  /// No description provided for @backups.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطية'**
  String get backups;

  /// No description provided for @backupsHint.
  ///
  /// In ar, this message translates to:
  /// **'كل هاتف نُسخ احتياطيًا على هذا الكمبيوتر.'**
  String get backupsHint;

  /// No description provided for @battery.
  ///
  /// In ar, this message translates to:
  /// **'البطارية'**
  String get battery;

  /// No description provided for @cancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancel;

  /// No description provided for @categoryApps.
  ///
  /// In ar, this message translates to:
  /// **'التطبيقات'**
  String get categoryApps;

  /// No description provided for @categoryAudio.
  ///
  /// In ar, this message translates to:
  /// **'الموسيقى'**
  String get categoryAudio;

  /// No description provided for @categoryCallLogs.
  ///
  /// In ar, this message translates to:
  /// **'سجل المكالمات'**
  String get categoryCallLogs;

  /// No description provided for @categoryContacts.
  ///
  /// In ar, this message translates to:
  /// **'جهات الاتصال'**
  String get categoryContacts;

  /// No description provided for @categoryDocuments.
  ///
  /// In ar, this message translates to:
  /// **'المستندات'**
  String get categoryDocuments;

  /// No description provided for @categoryFiles.
  ///
  /// In ar, this message translates to:
  /// **'الملفات'**
  String get categoryFiles;

  /// No description provided for @categoryFromDevice.
  ///
  /// In ar, this message translates to:
  /// **'{category} من {device}'**
  String categoryFromDevice(String category, String device);

  /// No description provided for @categoryMessages.
  ///
  /// In ar, this message translates to:
  /// **'الرسائل'**
  String get categoryMessages;

  /// No description provided for @categoryPhotos.
  ///
  /// In ar, this message translates to:
  /// **'الصور'**
  String get categoryPhotos;

  /// No description provided for @categoryVideos.
  ///
  /// In ar, this message translates to:
  /// **'الفيديوهات'**
  String get categoryVideos;

  /// No description provided for @categoryWallpaper.
  ///
  /// In ar, this message translates to:
  /// **'خلفية الشاشة'**
  String get categoryWallpaper;

  /// No description provided for @categoryWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'واتساب'**
  String get categoryWhatsapp;

  /// No description provided for @categoryWhatsappBusiness.
  ///
  /// In ar, this message translates to:
  /// **'واتساب للأعمال'**
  String get categoryWhatsappBusiness;

  /// No description provided for @changeFolder.
  ///
  /// In ar, this message translates to:
  /// **'تغيير المجلد'**
  String get changeFolder;

  /// No description provided for @chatsAndMedia.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات + الوسائط'**
  String get chatsAndMedia;

  /// No description provided for @chatsOnly.
  ///
  /// In ar, this message translates to:
  /// **'المحادثات فقط'**
  String get chatsOnly;

  /// No description provided for @chooseApk.
  ///
  /// In ar, this message translates to:
  /// **'اختيار ملف APK...'**
  String get chooseApk;

  /// No description provided for @chooseApkDialogTitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر ملف HK Cloner بصيغة APK'**
  String get chooseApkDialogTitle;

  /// No description provided for @chooseApps.
  ///
  /// In ar, this message translates to:
  /// **'اختر التطبيقات'**
  String get chooseApps;

  /// No description provided for @chooseComputer.
  ///
  /// In ar, this message translates to:
  /// **'اختر جهاز كمبيوتر'**
  String get chooseComputer;

  /// No description provided for @chooseNewPhone.
  ///
  /// In ar, this message translates to:
  /// **'اختر الهاتف الجديد'**
  String get chooseNewPhone;

  /// No description provided for @chooseWhatToMove.
  ///
  /// In ar, this message translates to:
  /// **'اختر ما تريد نقله'**
  String get chooseWhatToMove;

  /// No description provided for @close.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get close;

  /// No description provided for @codeWrongDevice.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرمز يخص جهازًا مختلفًا.'**
  String get codeWrongDevice;

  /// No description provided for @codedAndDesignedBy.
  ///
  /// In ar, this message translates to:
  /// **'برمجة وتصميم م. هشام الخطيب'**
  String get codedAndDesignedBy;

  /// No description provided for @computerOverUsb.
  ///
  /// In ar, this message translates to:
  /// **'الكمبيوتر عبر USB'**
  String get computerOverUsb;

  /// No description provided for @computerOverUsbSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'وصّل الهاتف بالكمبيوتر بعد فتح HK Cloner عليه'**
  String get computerOverUsbSubtitle;

  /// No description provided for @confirmContactsImport.
  ///
  /// In ar, this message translates to:
  /// **'أكّد الاستيراد في جهات الاتصال'**
  String get confirmContactsImport;

  /// No description provided for @connect.
  ///
  /// In ar, this message translates to:
  /// **'اتصال'**
  String get connect;

  /// No description provided for @connectAPhone.
  ///
  /// In ar, this message translates to:
  /// **'وصّل هاتفًا'**
  String get connectAPhone;

  /// No description provided for @connectByAddress.
  ///
  /// In ar, this message translates to:
  /// **'الاتصال بالعنوان'**
  String get connectByAddress;

  /// No description provided for @connectFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الاتصال: {error}'**
  String connectFailed(String error);

  /// No description provided for @connectWireless.
  ///
  /// In ar, this message translates to:
  /// **'لاسلكيًا: امسح الرمز بتطبيق HK Cloner، أو اختر \"{host}\" من القائمة على الهاتف.'**
  String connectWireless(String host);

  /// No description provided for @connectedEncrypted.
  ///
  /// In ar, this message translates to:
  /// **'متصل · مشفّر'**
  String get connectedEncrypted;

  /// No description provided for @contactsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا جهات اتصال} =1{جهة اتصال واحدة} =2{جهتا اتصال} few{{count} جهات اتصال} many{{count} جهة اتصال} other{{count} جهة اتصال}}'**
  String contactsCount(int count);

  /// No description provided for @contactsImportHint.
  ///
  /// In ar, this message translates to:
  /// **'فُتح تطبيق جهات الاتصال مع الملف. اختر مكان حفظها.'**
  String get contactsImportHint;

  /// No description provided for @contactsNoApp.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على تطبيق جهات اتصال لاستيراد contacts.vcf.'**
  String get contactsNoApp;

  /// No description provided for @contactsReceived.
  ///
  /// In ar, this message translates to:
  /// **'تم استلام جهات الاتصال'**
  String get contactsReceived;

  /// No description provided for @continueAnotherWay.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة بطريقة أخرى'**
  String get continueAnotherWay;

  /// No description provided for @copied.
  ///
  /// In ar, this message translates to:
  /// **'تم نسخه'**
  String get copied;

  /// No description provided for @copyingAppOf.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ نسخ {name} ({index} من {total})'**
  String copyingAppOf(String name, int index, int total);

  /// No description provided for @couldNotDelete.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحذف: {error}'**
  String couldNotDelete(String error);

  /// No description provided for @couldNotReach.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى {name}: {error}'**
  String couldNotReach(String name, String error);

  /// No description provided for @creditsBy.
  ///
  /// In ar, this message translates to:
  /// **' بواسطة م. هشام الخطيب'**
  String get creditsBy;

  /// No description provided for @creditsMadeWith.
  ///
  /// In ar, this message translates to:
  /// **'صُنع بـ '**
  String get creditsMadeWith;

  /// No description provided for @decline.
  ///
  /// In ar, this message translates to:
  /// **'رفض'**
  String get decline;

  /// No description provided for @delete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get delete;

  /// No description provided for @deleteBackup.
  ///
  /// In ar, this message translates to:
  /// **'حذف النسخة الاحتياطية'**
  String get deleteBackup;

  /// No description provided for @deleteBackupBody.
  ///
  /// In ar, this message translates to:
  /// **'سيؤدي هذا إلى حذف {size} من\n{path}\n\nلن يُمس الهاتف نفسه.'**
  String deleteBackupBody(String size, String path);

  /// No description provided for @deleteBackupTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف النسخة الاحتياطية لـ {name}؟'**
  String deleteBackupTitle(String name);

  /// No description provided for @deletedBackup.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف النسخة الاحتياطية لـ {name}.'**
  String deletedBackup(String name);

  /// No description provided for @desktopBackupStation.
  ///
  /// In ar, this message translates to:
  /// **'محطة النسخ الاحتياطي على الكمبيوتر'**
  String get desktopBackupStation;

  /// No description provided for @desktopSettingsHint.
  ///
  /// In ar, this message translates to:
  /// **'مكان حفظ النسخ الاحتياطية، ومعلومات عن التطبيق.'**
  String get desktopSettingsHint;

  /// No description provided for @deviceBackups.
  ///
  /// In ar, this message translates to:
  /// **'نسخ الأجهزة الاحتياطية'**
  String get deviceBackups;

  /// No description provided for @deviceFallbackName.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز'**
  String get deviceFallbackName;

  /// No description provided for @deviceName.
  ///
  /// In ar, this message translates to:
  /// **'اسم الجهاز'**
  String get deviceName;

  /// No description provided for @deviceNameHint.
  ///
  /// In ar, this message translates to:
  /// **'تظهر هذه التسمية للهواتف وأجهزة الكمبيوتر الأخرى. اتركها فارغة لاستخدام \"{model}\".'**
  String deviceNameHint(String model);

  /// No description provided for @devices.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة'**
  String get devices;

  /// No description provided for @devicesHint.
  ///
  /// In ar, this message translates to:
  /// **'الهواتف الموصولة عبر USB أو التي تشغّل HK Cloner على هذه الشبكة.'**
  String get devicesHint;

  /// No description provided for @differentDevice.
  ///
  /// In ar, this message translates to:
  /// **'هذا جهاز مختلف عن الجهاز الذي كنت ترسل إليه.'**
  String get differentDevice;

  /// No description provided for @differentDeviceThan.
  ///
  /// In ar, this message translates to:
  /// **'هذا جهاز مختلف عن {name}'**
  String differentDeviceThan(String name);

  /// No description provided for @discard.
  ///
  /// In ar, this message translates to:
  /// **'تجاهل'**
  String get discard;

  /// No description provided for @discoveryBlocked.
  ///
  /// In ar, this message translates to:
  /// **'لن يطلب أندرويد الإذن مرة أخرى. افتح الإعدادات > الأذونات واسمح بـ {name}.'**
  String discoveryBlocked(String name);

  /// No description provided for @discoveryLocationNote.
  ///
  /// In ar, this message translates to:
  /// **'يسمّي أندرويد {version} هذا الإذن \"الموقع\". لا يقرأ HK Cloner موقعك أبدًا.'**
  String discoveryLocationNote(String version);

  /// No description provided for @discoveryWhy.
  ///
  /// In ar, this message translates to:
  /// **'بدونه لا يستطيع الهاتفان رؤية بعضهما على شبكة Wi-Fi نفسها أو عبر كابل USB.'**
  String get discoveryWhy;

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get done;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{hours} س {minutes} د'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In ar, this message translates to:
  /// **'{minutes} د'**
  String durationMinutes(int minutes);

  /// No description provided for @durationSeconds.
  ///
  /// In ar, this message translates to:
  /// **'{seconds} ث'**
  String durationSeconds(int seconds);

  /// No description provided for @encryptedProgressSaved.
  ///
  /// In ar, this message translates to:
  /// **'مشفّر · يُحفظ التقدّم باستمرار'**
  String get encryptedProgressSaved;

  /// No description provided for @encryption.
  ///
  /// In ar, this message translates to:
  /// **'التشفير'**
  String get encryption;

  /// No description provided for @encryptionHint.
  ///
  /// In ar, this message translates to:
  /// **'عمليات النقل مشفّرة من طرف إلى طرف على شبكتك المحلية.'**
  String get encryptionHint;

  /// No description provided for @enterAddress.
  ///
  /// In ar, this message translates to:
  /// **'إدخال العنوان'**
  String get enterAddress;

  /// No description provided for @enterAddressSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يظهر أسفل رمز QR على الجهاز الآخر'**
  String get enterAddressSubtitle;

  /// No description provided for @filesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا ملفات} =1{ملف واحد} =2{ملفان} few{{count} ملفات} many{{count} ملفًا} other{{count} ملف}}'**
  String filesCount(int count);

  /// No description provided for @filesProgress.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} ملف'**
  String filesProgress(int done, int total);

  /// No description provided for @finishWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'أكمل إعداد واتساب'**
  String get finishWhatsapp;

  /// No description provided for @finishingStuck.
  ///
  /// In ar, this message translates to:
  /// **'لم يؤكد {name} بعد. إن لم يتغير شيء، اضغط استئناف لإرسال ما تبقى من جديد.'**
  String finishingStuck(String name);

  /// No description provided for @finishingUp.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإنهاء...'**
  String get finishingUp;

  /// No description provided for @finishingWaiting.
  ///
  /// In ar, this message translates to:
  /// **'أُرسل كل شيء. في انتظار تأكيد {name}.'**
  String finishingWaiting(String name);

  /// No description provided for @fromName.
  ///
  /// In ar, this message translates to:
  /// **'من {name}'**
  String fromName(String name);

  /// No description provided for @grant.
  ///
  /// In ar, this message translates to:
  /// **'منح الإذن'**
  String get grant;

  /// No description provided for @history.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get history;

  /// No description provided for @historyHint.
  ///
  /// In ar, this message translates to:
  /// **'أحدث النسخ الاحتياطية، الأحدث أولًا.'**
  String get historyHint;

  /// No description provided for @homeHeadline.
  ///
  /// In ar, this message translates to:
  /// **'انقل كل شيء\nإلى هاتفك الجديد'**
  String get homeHeadline;

  /// No description provided for @homeIntro.
  ///
  /// In ar, this message translates to:
  /// **'الصور والفيديوهات وجهات الاتصال ومحادثات واتساب. عبر Wi-Fi أو نقطة اتصال أو كابل، ويُكمل النقل من حيث توقف.'**
  String get homeIntro;

  /// No description provided for @hotspotFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تشغيل نقطة الاتصال ({error}). استخدم نقطة الاتصال من الإعدادات بدلًا من ذلك.'**
  String hotspotFailed(String error);

  /// No description provided for @hotspotOn.
  ///
  /// In ar, this message translates to:
  /// **'نقطة الاتصال \"{ssid}\" تعمل. ينضم إليها رمز QR تلقائيًا.'**
  String hotspotOn(String ssid);

  /// No description provided for @hotspotUseSettings.
  ///
  /// In ar, this message translates to:
  /// **'شغّل نقطة الاتصال من الإعدادات، ووصّل الهاتف القديم بها، ثم امسح الرمز.'**
  String get hotspotUseSettings;

  /// No description provided for @howConnected.
  ///
  /// In ar, this message translates to:
  /// **'كيف يتصل الهاتفان؟'**
  String get howConnected;

  /// No description provided for @install.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت'**
  String get install;

  /// No description provided for @installAll.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت الكل'**
  String get installAll;

  /// No description provided for @installApps.
  ///
  /// In ar, this message translates to:
  /// **'تثبيت التطبيقات'**
  String get installApps;

  /// No description provided for @installAppsHint.
  ///
  /// In ar, this message translates to:
  /// **'يطلب منك أندرويد تأكيد كل تطبيق. سجّل الدخول من جديد في التطبيقات التي تحتاج ذلك.'**
  String get installAppsHint;

  /// No description provided for @installBlocked.
  ///
  /// In ar, this message translates to:
  /// **'رفض الهاتف التثبيت. انظر إلى الهاتف: إن ظهر سؤال، اضغط تثبيت (أو \"التثبيت على أي حال\"). في هواتف Xiaomi فعّل خيارات المطوّر > \"التثبيت عبر USB\". ثم حاول مجددًا.'**
  String get installBlocked;

  /// No description provided for @installDowngrade.
  ///
  /// In ar, this message translates to:
  /// **'على الهاتف إصدار أحدث من HK Cloner. تثبيت هذا الإصدار يعني إلغاء تثبيت الأحدث أولًا، وهذا يحذف بيانات HK Cloner على الهاتف. لن تُمس الصور وجهات الاتصال والتطبيقات الأخرى.'**
  String get installDowngrade;

  /// No description provided for @installExplain.
  ///
  /// In ar, this message translates to:
  /// **'سيثبّت هذا الكمبيوتر HK Cloner على الهاتف عبر الكابل ثم يفتحه.'**
  String get installExplain;

  /// No description provided for @installFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل التثبيت: {detail}'**
  String installFailed(String detail);

  /// No description provided for @installInvalidApk.
  ///
  /// In ar, this message translates to:
  /// **'هذا الملف ليس ملف APK صالحًا لـ HK Cloner. اختر ملفًا آخر.'**
  String get installInvalidApk;

  /// No description provided for @installNoSpace.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد مساحة كافية على الهاتف. حرّر {size} على الأقل ثم حاول مجددًا.'**
  String installNoSpace(String size);

  /// No description provided for @installNotAuthorized.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف لا يثق بهذا الكمبيوتر بعد. افتح قفله واضغط سماح على \"السماح بتصحيح أخطاء USB؟\" (حدّد \"السماح دائمًا من هذا الكمبيوتر\")، ثم حاول مجددًا.'**
  String get installNotAuthorized;

  /// No description provided for @installOnPhone.
  ///
  /// In ar, this message translates to:
  /// **'التثبيت على الهاتف'**
  String get installOnPhone;

  /// No description provided for @installTapInstall.
  ///
  /// In ar, this message translates to:
  /// **'إذا سألك الهاتف عن التثبيت، اضغط تثبيت.'**
  String get installTapInstall;

  /// No description provided for @installUpdateIncompatible.
  ///
  /// In ar, this message translates to:
  /// **'على الهاتف نسخة مختلفة من HK Cloner (من كمبيوتر آخر أو من متجر آخر). لا يستبدلها أندرويد إلا بعد إلغاء تثبيتها، وهذا يحذف بيانات HK Cloner على الهاتف: إعداداته وأي نقل غير مكتمل. لن تُمس الصور وجهات الاتصال والتطبيقات الأخرى.'**
  String get installUpdateIncompatible;

  /// No description provided for @installingAppOf.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تثبيت {name} ({index} من {total})'**
  String installingAppOf(String name, int index, int total);

  /// No description provided for @installingOn.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التثبيت على {device}. قد يستغرق ذلك دقيقة.'**
  String installingOn(String device);

  /// No description provided for @interruptConnectionLost.
  ///
  /// In ar, this message translates to:
  /// **'انقطع الاتصال. أعد الاتصال (Wi-Fi أو نقطة اتصال أو كابل) واضغط استئناف.'**
  String get interruptConnectionLost;

  /// No description provided for @interruptLowBatteryPeer.
  ///
  /// In ar, this message translates to:
  /// **'البطارية منخفضة جدًا على الهاتف الآخر. اشحنه واضغط استئناف.'**
  String get interruptLowBatteryPeer;

  /// No description provided for @interruptLowBatterySelf.
  ///
  /// In ar, this message translates to:
  /// **'البطارية منخفضة جدًا على هذا الهاتف. اشحنه واضغط استئناف.'**
  String get interruptLowBatterySelf;

  /// No description provided for @interruptPaused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا. اضغط استئناف للمتابعة.'**
  String get interruptPaused;

  /// No description provided for @interruptStopped.
  ///
  /// In ar, this message translates to:
  /// **'توقف النقل. اضغط استئناف للمتابعة من حيث توقف.'**
  String get interruptStopped;

  /// No description provided for @itemsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا عناصر} =1{عنصر واحد} =2{عنصران} few{{count} عناصر} many{{count} عنصرًا} other{{count} عنصر}}'**
  String itemsCount(int count);

  /// No description provided for @itemsMoved.
  ///
  /// In ar, this message translates to:
  /// **'تم نقل {done} من {total} عنصر'**
  String itemsMoved(int done, int total);

  /// No description provided for @keepScreenOn.
  ///
  /// In ar, this message translates to:
  /// **'إبقاء الشاشة مضاءة'**
  String get keepScreenOn;

  /// No description provided for @keepScreenOnHint.
  ///
  /// In ar, this message translates to:
  /// **'أثناء الإرسال أو الاستقبال. بعض الهواتف تُبطئ شبكة Wi-Fi عند إطفاء الشاشة.'**
  String get keepScreenOnHint;

  /// No description provided for @lastBackupAt.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة احتياطية {when}'**
  String lastBackupAt(String when);

  /// No description provided for @lastChatBackupDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{آخر نسخة احتياطية للمحادثات: منذ يوم واحد} =2{آخر نسخة احتياطية للمحادثات: منذ يومين} few{آخر نسخة احتياطية للمحادثات: منذ {days} أيام} many{آخر نسخة احتياطية للمحادثات: منذ {days} يومًا} other{آخر نسخة احتياطية للمحادثات: منذ {days} يوم}}'**
  String lastChatBackupDays(int days);

  /// No description provided for @lastChatBackupHours.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة احتياطية للمحادثات: منذ {hours} س'**
  String lastChatBackupHours(int hours);

  /// No description provided for @linked.
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get linked;

  /// No description provided for @loadingApps.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تحميل التطبيقات...'**
  String get loadingApps;

  /// No description provided for @locationPermission.
  ///
  /// In ar, this message translates to:
  /// **'الموقع'**
  String get locationPermission;

  /// No description provided for @lookForPhones.
  ///
  /// In ar, this message translates to:
  /// **'البحث عن هواتف'**
  String get lookForPhones;

  /// No description provided for @lookingForDevices.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البحث عن الأجهزة. على الجهاز الآخر، افتح HK Cloner واضغط استقبال.'**
  String get lookingForDevices;

  /// No description provided for @maximize.
  ///
  /// In ar, this message translates to:
  /// **'تكبير'**
  String get maximize;

  /// No description provided for @minimize.
  ///
  /// In ar, this message translates to:
  /// **'تصغير'**
  String get minimize;

  /// No description provided for @modeCableHint.
  ///
  /// In ar, this message translates to:
  /// **'الأسرع. كابل USB-C إلى USB-C أو محوّل OTG'**
  String get modeCableHint;

  /// No description provided for @modeHotspot.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد شبكة Wi-Fi'**
  String get modeHotspot;

  /// No description provided for @modeHotspotHint.
  ///
  /// In ar, this message translates to:
  /// **'ينشئ هذا الهاتف نقطة اتصال خاصة، وينضم إليها رمز QR'**
  String get modeHotspotHint;

  /// No description provided for @modeWifi.
  ///
  /// In ar, this message translates to:
  /// **'نفس شبكة Wi-Fi'**
  String get modeWifi;

  /// No description provided for @modeWifiHint.
  ///
  /// In ar, this message translates to:
  /// **'يجد الهاتفان بعضهما تلقائيًا'**
  String get modeWifiHint;

  /// No description provided for @nearbyDevicesPermission.
  ///
  /// In ar, this message translates to:
  /// **'الأجهزة المجاورة'**
  String get nearbyDevicesPermission;

  /// No description provided for @nearbyOnWifi.
  ///
  /// In ar, this message translates to:
  /// **'قريبة على شبكة Wi-Fi'**
  String get nearbyOnWifi;

  /// No description provided for @noAddressReachable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى الجهاز الآخر على أيٍّ من عناوينه.'**
  String get noAddressReachable;

  /// No description provided for @noAppsFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على تطبيقات'**
  String get noAppsFound;

  /// No description provided for @noBackupsYet.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ احتياطية بعد. افتح HK Cloner على هاتف واضغط \"نسخ احتياطي إلى الكمبيوتر\".'**
  String get noBackupsYet;

  /// No description provided for @noBundledApk.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على تطبيق الهاتف في هذه النسخة من HK Cloner. اختر ملف HK Cloner بصيغة APK ({file}) لتثبيته على الهاتف.'**
  String noBundledApk(String file);

  /// No description provided for @noFolderAccess.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد وصول إلى {path}. امنح الإذن للمجلد قبل الاستقبال.'**
  String noFolderAccess(String path);

  /// No description provided for @noPhonesFound.
  ///
  /// In ar, this message translates to:
  /// **'لم يُعثر على هواتف بعد. افتح HK Cloner على هاتف متصل بالشبكة نفسها.'**
  String get noPhonesFound;

  /// No description provided for @notFindingHelp.
  ///
  /// In ar, this message translates to:
  /// **'نفس شبكة Wi-Fi: يجب أن يكون الهاتفان على الشبكة نفسها، وبعض أجهزة الراوتر (شبكات الضيوف) تعزل الأجهزة عن بعضها.\n\nكابل USB: افتح HK Cloner على الهاتفين واضغط سماح على كليهما. يجب أن يعمل أحد الهاتفين كمضيف USB (OTG)؛ إن لم يحدث شيء، اقلب الكابل أو استخدم محوّل OTG.\n\nلا يوجد راوتر إطلاقًا: اختر \"لا توجد شبكة Wi-Fi\" على الهاتف الجديد وامسح رمزه.'**
  String get notFindingHelp;

  /// No description provided for @notNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get notNow;

  /// No description provided for @nothingBackedUp.
  ///
  /// In ar, this message translates to:
  /// **'لم يُنسخ شيء احتياطيًا بعد.'**
  String get nothingBackedUp;

  /// No description provided for @nothingLost.
  ///
  /// In ar, this message translates to:
  /// **'لم يضِع شيء. استأنف من هنا، أو انتقل إلى نقطة الاتصال أو كابل USB أو رمز QR.'**
  String get nothingLost;

  /// No description provided for @notifReceiving.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total} · {speed}'**
  String notifReceiving(String done, String total, String speed);

  /// No description provided for @notifSending.
  ///
  /// In ar, this message translates to:
  /// **'{done}/{total} ملف · {speed}'**
  String notifSending(int done, int total, String speed);

  /// No description provided for @notifStarting.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ البدء...'**
  String get notifStarting;

  /// No description provided for @notifTimeLeft.
  ///
  /// In ar, this message translates to:
  /// **'متبقٍ {time}'**
  String notifTimeLeft(String time);

  /// No description provided for @open.
  ///
  /// In ar, this message translates to:
  /// **'فتح'**
  String get open;

  /// No description provided for @openAndroidAppSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح إعدادات التطبيق في أندرويد'**
  String get openAndroidAppSettings;

  /// No description provided for @openAndroidAppSettingsHint.
  ///
  /// In ar, this message translates to:
  /// **'الأذونات والتخزين والإشعارات لتطبيق HK Cloner'**
  String get openAndroidAppSettingsHint;

  /// No description provided for @openSettings.
  ///
  /// In ar, this message translates to:
  /// **'فتح الإعدادات'**
  String get openSettings;

  /// No description provided for @openWhatsapp.
  ///
  /// In ar, this message translates to:
  /// **'فتح واتساب'**
  String get openWhatsapp;

  /// No description provided for @overview.
  ///
  /// In ar, this message translates to:
  /// **'نظرة عامة'**
  String get overview;

  /// No description provided for @pause.
  ///
  /// In ar, this message translates to:
  /// **'إيقاف مؤقت'**
  String get pause;

  /// No description provided for @paused.
  ///
  /// In ar, this message translates to:
  /// **'متوقف مؤقتًا'**
  String get paused;

  /// No description provided for @peerBatteryLowBody.
  ///
  /// In ar, this message translates to:
  /// **'وصّله بالشاحن. إن انطفأ، يُستأنف النقل من حيث توقف.'**
  String get peerBatteryLowBody;

  /// No description provided for @peerBatteryLowTitle.
  ///
  /// In ar, this message translates to:
  /// **'بطارية الهاتف المُرسِل منخفضة ({level}%)'**
  String peerBatteryLowTitle(int level);

  /// No description provided for @permAllFiles.
  ///
  /// In ar, this message translates to:
  /// **'جميع الملفات (واتساب)'**
  String get permAllFiles;

  /// No description provided for @permAllFilesPurpose.
  ///
  /// In ar, this message translates to:
  /// **'قراءة محادثات واتساب واستعادتها على أندرويد 11 وما بعده'**
  String get permAllFilesPurpose;

  /// No description provided for @permCamera.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get permCamera;

  /// No description provided for @permCameraPurpose.
  ///
  /// In ar, this message translates to:
  /// **'مسح رمز QR للاقتران'**
  String get permCameraPurpose;

  /// No description provided for @permContactsPurpose.
  ///
  /// In ar, this message translates to:
  /// **'إرسال جهات الاتصال واستقبالها'**
  String get permContactsPurpose;

  /// No description provided for @permLocationPurpose.
  ///
  /// In ar, this message translates to:
  /// **'العثور على الهاتف الآخر عبر Wi-Fi (لا يقرأ موقعك أبدًا)'**
  String get permLocationPurpose;

  /// No description provided for @permNearbyPurpose.
  ///
  /// In ar, this message translates to:
  /// **'العثور على الهاتف الآخر عبر Wi-Fi والكابل'**
  String get permNearbyPurpose;

  /// No description provided for @permNotifications.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات'**
  String get permNotifications;

  /// No description provided for @permNotificationsPurpose.
  ///
  /// In ar, this message translates to:
  /// **'عرض التقدّم أثناء النقل'**
  String get permNotificationsPurpose;

  /// No description provided for @permPhotos.
  ///
  /// In ar, this message translates to:
  /// **'الصور والفيديوهات'**
  String get permPhotos;

  /// No description provided for @permPhotosPurpose.
  ///
  /// In ar, this message translates to:
  /// **'إرسال معرض الصور واستقباله'**
  String get permPhotosPurpose;

  /// No description provided for @phone.
  ///
  /// In ar, this message translates to:
  /// **'الهاتف'**
  String get phone;

  /// No description provided for @plugInForApps.
  ///
  /// In ar, this message translates to:
  /// **'وصّل الهاتف عبر USB (مع تفعيل تصحيح أخطاء USB) لتثبيت التطبيقات من هذا الكمبيوتر.'**
  String get plugInForApps;

  /// No description provided for @plugInPhone.
  ///
  /// In ar, this message translates to:
  /// **'وصّل هاتفًا مع تفعيل تصحيح أخطاء USB. سيُثبَّت HK Cloner ويُفتح عليه تلقائيًا.'**
  String get plugInPhone;

  /// No description provided for @prepareFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تجهيز {category}: {error}'**
  String prepareFailed(String category, String error);

  /// No description provided for @readyAt.
  ///
  /// In ar, this message translates to:
  /// **'جاهز · {address}'**
  String readyAt(String address);

  /// No description provided for @receive.
  ///
  /// In ar, this message translates to:
  /// **'استقبال'**
  String get receive;

  /// No description provided for @receiveSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا هاتفي الجديد'**
  String get receiveSubtitle;

  /// No description provided for @receivingFrom.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الاستقبال من {name}'**
  String receivingFrom(String name);

  /// No description provided for @reconnectFirst.
  ///
  /// In ar, this message translates to:
  /// **'أعد الاتصال بـ {name} أولًا'**
  String reconnectFirst(String name);

  /// No description provided for @refresh.
  ///
  /// In ar, this message translates to:
  /// **'تحديث'**
  String get refresh;

  /// No description provided for @restore.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get restore;

  /// No description provided for @restoreApps.
  ///
  /// In ar, this message translates to:
  /// **'استعادة التطبيقات'**
  String get restoreApps;

  /// No description provided for @restoreComplete.
  ///
  /// In ar, this message translates to:
  /// **'اكتملت الاستعادة.'**
  String get restoreComplete;

  /// No description provided for @restoreFromComputer.
  ///
  /// In ar, this message translates to:
  /// **'استعادة من الكمبيوتر'**
  String get restoreFromComputer;

  /// No description provided for @restoreFromComputerSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'استرجع نسخة احتياطية إلى هذا الهاتف'**
  String get restoreFromComputerSubtitle;

  /// No description provided for @restoreNoPhone.
  ///
  /// In ar, this message translates to:
  /// **'افتح HK Cloner على الهاتف واضغط \"استعادة من الكمبيوتر\"، أو صِله عبر USB.'**
  String get restoreNoPhone;

  /// No description provided for @restoreStopped.
  ///
  /// In ar, this message translates to:
  /// **'توقفت الاستعادة إلى {name} عند {done} من {total} ملف.'**
  String restoreStopped(String name, int done, int total);

  /// No description provided for @restoreToWhichPhone.
  ///
  /// In ar, this message translates to:
  /// **'الاستعادة إلى أي هاتف؟'**
  String get restoreToWhichPhone;

  /// No description provided for @restoreWindow.
  ///
  /// In ar, this message translates to:
  /// **'استعادة الحجم'**
  String get restoreWindow;

  /// No description provided for @resume.
  ///
  /// In ar, this message translates to:
  /// **'استئناف'**
  String get resume;

  /// No description provided for @retry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get retry;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @scanQrCode.
  ///
  /// In ar, this message translates to:
  /// **'مسح رمز QR'**
  String get scanQrCode;

  /// No description provided for @scanQrCodeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'يعمل أيضًا مع نقطة الاتصال وكابل USB'**
  String get scanQrCodeSubtitle;

  /// No description provided for @scanTheCode.
  ///
  /// In ar, this message translates to:
  /// **'امسح الرمز'**
  String get scanTheCode;

  /// No description provided for @scanThisWithOldPhone.
  ///
  /// In ar, this message translates to:
  /// **'امسح هذا الرمز بتطبيق HK Cloner على هاتفك القديم'**
  String get scanThisWithOldPhone;

  /// No description provided for @scanning.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الفحص...'**
  String get scanning;

  /// No description provided for @searchApps.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في التطبيقات'**
  String get searchApps;

  /// No description provided for @sectionAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get sectionAbout;

  /// No description provided for @sectionAppearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get sectionAppearance;

  /// No description provided for @sectionComputer.
  ///
  /// In ar, this message translates to:
  /// **'الكمبيوتر'**
  String get sectionComputer;

  /// No description provided for @sectionContent.
  ///
  /// In ar, this message translates to:
  /// **'المحتوى'**
  String get sectionContent;

  /// No description provided for @sectionLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get sectionLanguage;

  /// No description provided for @sectionNearby.
  ///
  /// In ar, this message translates to:
  /// **'بالقرب منك'**
  String get sectionNearby;

  /// No description provided for @sectionNotFinding.
  ///
  /// In ar, this message translates to:
  /// **'لا يظهر الجهاز؟'**
  String get sectionNotFinding;

  /// No description provided for @sectionOtherWays.
  ///
  /// In ar, this message translates to:
  /// **'طرق أخرى للاتصال'**
  String get sectionOtherWays;

  /// No description provided for @sectionPermissions.
  ///
  /// In ar, this message translates to:
  /// **'الأذونات'**
  String get sectionPermissions;

  /// No description provided for @sectionPhoneToPhone.
  ///
  /// In ar, this message translates to:
  /// **'من هاتف إلى هاتف'**
  String get sectionPhoneToPhone;

  /// No description provided for @sectionProgress.
  ///
  /// In ar, this message translates to:
  /// **'التقدّم'**
  String get sectionProgress;

  /// No description provided for @sectionThisPhone.
  ///
  /// In ar, this message translates to:
  /// **'هذا الهاتف'**
  String get sectionThisPhone;

  /// No description provided for @sectionTransfers.
  ///
  /// In ar, this message translates to:
  /// **'النقل'**
  String get sectionTransfers;

  /// No description provided for @selectAll.
  ///
  /// In ar, this message translates to:
  /// **'تحديد الكل'**
  String get selectAll;

  /// No description provided for @selectNone.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التحديد'**
  String get selectNone;

  /// No description provided for @selfBatteryLowBody.
  ///
  /// In ar, this message translates to:
  /// **'وصّل هذا الهاتف بالشاحن. التقدّم محفوظ، فيمكن استئناف النقل إن انطفأ.'**
  String get selfBatteryLowBody;

  /// No description provided for @selfBatteryLowTitle.
  ///
  /// In ar, this message translates to:
  /// **'البطارية منخفضة ({level}%)'**
  String selfBatteryLowTitle(int level);

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'إرسال'**
  String get send;

  /// No description provided for @sendSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هذا هاتفي القديم'**
  String get sendSubtitle;

  /// No description provided for @sendingTo.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الإرسال إلى {name}'**
  String sendingTo(String name);

  /// No description provided for @sentFromLocalSend.
  ///
  /// In ar, this message translates to:
  /// **'مُرسل من LocalSend.'**
  String get sentFromLocalSend;

  /// No description provided for @sentFromLocalSendDownloads.
  ///
  /// In ar, this message translates to:
  /// **'مُرسل من LocalSend. تُحفظ الملفات في التنزيلات.'**
  String get sentFromLocalSendDownloads;

  /// No description provided for @settings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settings;

  /// No description provided for @sidebarEncrypted.
  ///
  /// In ar, this message translates to:
  /// **'مشفّر من طرف إلى طرف على شبكتك المحلية'**
  String get sidebarEncrypted;

  /// No description provided for @sizeOfSize.
  ///
  /// In ar, this message translates to:
  /// **'{done} من {total}'**
  String sizeOfSize(String done, String total);

  /// No description provided for @sortName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get sortName;

  /// No description provided for @sortSize.
  ///
  /// In ar, this message translates to:
  /// **'الحجم'**
  String get sortSize;

  /// No description provided for @startBackup.
  ///
  /// In ar, this message translates to:
  /// **'بدء النسخ الاحتياطي'**
  String get startBackup;

  /// No description provided for @startTransfer.
  ///
  /// In ar, this message translates to:
  /// **'بدء النقل'**
  String get startTransfer;

  /// No description provided for @startupFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التشغيل: {error}'**
  String startupFailed(String error);

  /// No description provided for @startupPreparing.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تجهيز الاتصال الآمن...'**
  String get startupPreparing;

  /// No description provided for @storedInBackupFolder.
  ///
  /// In ar, this message translates to:
  /// **'يُحفظ كل شيء في مجلد النسخ الاحتياطي لهذا الجهاز.'**
  String get storedInBackupFolder;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'داكن'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'فاتح'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'النظام'**
  String get themeSystem;

  /// No description provided for @thisComputer.
  ///
  /// In ar, this message translates to:
  /// **'هذا الكمبيوتر'**
  String get thisComputer;

  /// No description provided for @thisPhone.
  ///
  /// In ar, this message translates to:
  /// **'هذا الهاتف'**
  String get thisPhone;

  /// No description provided for @tickToScan.
  ///
  /// In ar, this message translates to:
  /// **'حدّد للفحص'**
  String get tickToScan;

  /// No description provided for @timeLeft.
  ///
  /// In ar, this message translates to:
  /// **'الوقت المتبقي'**
  String get timeLeft;

  /// No description provided for @total.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get total;

  /// No description provided for @transferComplete.
  ///
  /// In ar, this message translates to:
  /// **'اكتمل النقل'**
  String get transferComplete;

  /// No description provided for @transferDoneSummary.
  ///
  /// In ar, this message translates to:
  /// **'تم نقل {count} عنصر إلى {name}.'**
  String transferDoneSummary(int count, String name);

  /// No description provided for @transferFailed.
  ///
  /// In ar, this message translates to:
  /// **'فشل النقل: {error}'**
  String transferFailed(String error);

  /// No description provided for @transferPaused.
  ///
  /// In ar, this message translates to:
  /// **'توقف النقل مؤقتًا'**
  String get transferPaused;

  /// No description provided for @transfersShowLive.
  ///
  /// In ar, this message translates to:
  /// **'تظهر عمليات النقل هنا مباشرة.'**
  String get transfersShowLive;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مجددًا'**
  String get tryAgain;

  /// No description provided for @unfinishedTransferTo.
  ///
  /// In ar, this message translates to:
  /// **'نقل غير مكتمل إلى {name}'**
  String unfinishedTransferTo(String name);

  /// No description provided for @uninstallAndInstall.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء التثبيت ثم التثبيت'**
  String get uninstallAndInstall;

  /// No description provided for @unknownError.
  ///
  /// In ar, this message translates to:
  /// **'خطأ غير معروف'**
  String get unknownError;

  /// No description provided for @updateExplain.
  ///
  /// In ar, this message translates to:
  /// **'على الهاتف الإصدار {version}. التحديث يحتفظ ببياناته.'**
  String updateExplain(String version);

  /// No description provided for @updateOnPhone.
  ///
  /// In ar, this message translates to:
  /// **'التحديث على الهاتف'**
  String get updateOnPhone;

  /// No description provided for @usbCable.
  ///
  /// In ar, this message translates to:
  /// **'كابل USB'**
  String get usbCable;

  /// No description provided for @usbComputerUnreachable.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى الكمبيوتر عبر USB. افصل الكابل ثم أعد توصيله.'**
  String get usbComputerUnreachable;

  /// No description provided for @usbConnectHint.
  ///
  /// In ar, this message translates to:
  /// **'وصّل الهاتفين بكابل USB-C (أو محوّل OTG) وافتح HK Cloner على كليهما. ثم اضغط سماح على الهاتفين.'**
  String get usbConnectHint;

  /// No description provided for @usbConnected.
  ///
  /// In ar, this message translates to:
  /// **'متصل بالكابل. على الهاتف القديم، اضغط إرسال: سيظهر هذا الهاتف في أعلى القائمة.'**
  String get usbConnected;

  /// No description provided for @usbDenied.
  ///
  /// In ar, this message translates to:
  /// **'لم يُسمح بالوصول إلى USB. افصل الكابل، ثم أعد توصيله واضغط سماح.'**
  String get usbDenied;

  /// No description provided for @usbDetached.
  ///
  /// In ar, this message translates to:
  /// **'فُصل الكابل. أعد توصيله وسيُكمل النقل من حيث توقف.'**
  String get usbDetached;

  /// No description provided for @usbDeviceName.
  ///
  /// In ar, this message translates to:
  /// **'USB: {name}'**
  String usbDeviceName(String name);

  /// No description provided for @usbError.
  ///
  /// In ar, this message translates to:
  /// **'فشل الاتصال عبر الكابل. افصله ثم أعد توصيله.'**
  String get usbError;

  /// No description provided for @usbNoLink.
  ///
  /// In ar, this message translates to:
  /// **'لم يتعرّف الهاتفان على بعضهما عبر الكابل. يجب أن يعمل أحدهما كمضيف USB (OTG): جرّب قلب الكابل، أو كابل USB-C آخر، أو محوّل OTG على الهاتف الجديد. أو استخدم \"لا توجد شبكة Wi-Fi\".'**
  String get usbNoLink;

  /// No description provided for @usbPermission.
  ///
  /// In ar, this message translates to:
  /// **'اضغط سماح على هذا الهاتف ليتمكن HK Cloner من استخدام الكابل.'**
  String get usbPermission;

  /// No description provided for @usbSwitching.
  ///
  /// In ar, this message translates to:
  /// **'اقتربنا. على الهاتف الآخر، اضغط موافق لفتح HK Cloner، ثم سماح.'**
  String get usbSwitching;

  /// No description provided for @usbUnsupported.
  ///
  /// In ar, this message translates to:
  /// **'الجهاز الموصول بالكابل لا يدعم النقل بين الهواتف. يعمل خيار \"لا توجد شبكة Wi-Fi\" دون كابل أو راوتر.'**
  String get usbUnsupported;

  /// No description provided for @useNoWifiMode.
  ///
  /// In ar, this message translates to:
  /// **'استخدم \"لا توجد شبكة Wi-Fi\"'**
  String get useNoWifiMode;

  /// No description provided for @versionLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version}'**
  String versionLabel(String version);

  /// No description provided for @waitingForPhone.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار هاتف'**
  String get waitingForPhone;

  /// No description provided for @wallpaperFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر تعيين خلفية الشاشة: {error}'**
  String wallpaperFailed(String error);

  /// No description provided for @wallpaperNeedsAllFiles.
  ///
  /// In ar, this message translates to:
  /// **'لا يشارك أندرويد خلفية الشاشة إلا مع التطبيقات التي لديها إذن الوصول إلى جميع الملفات.'**
  String get wallpaperNeedsAllFiles;

  /// No description provided for @wallpaperSet.
  ///
  /// In ar, this message translates to:
  /// **'تم تعيين خلفية الشاشة'**
  String get wallpaperSet;

  /// No description provided for @wallpaperSetHint.
  ///
  /// In ar, this message translates to:
  /// **'أصبحت الشاشة الرئيسية وشاشة القفل مطابقتين لهاتفك القديم.'**
  String get wallpaperSetHint;

  /// No description provided for @wantsToSend.
  ///
  /// In ar, this message translates to:
  /// **'يريد {name} الإرسال'**
  String wantsToSend(String name);

  /// No description provided for @whatsappBackupSteps.
  ///
  /// In ar, this message translates to:
  /// **'في واتساب: الإعدادات > الدردشات > النسخ الاحتياطي للدردشات > نسخ احتياطي. ثم عُد إلى هنا.'**
  String get whatsappBackupSteps;

  /// No description provided for @whatsappGoesToFolder.
  ///
  /// In ar, this message translates to:
  /// **'تُحفظ ملفات واتساب في المجلد الذي يستخدمه واتساب على إصدار أندرويد هذا.'**
  String get whatsappGoesToFolder;

  /// No description provided for @whatsappNeedsGrant.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج أندرويد 11 وما بعده إلى موافقتك لقراءة هذا المجلد.'**
  String get whatsappNeedsGrant;

  /// No description provided for @whatsappRestoreSteps.
  ///
  /// In ar, this message translates to:
  /// **'1. ثبّته من متجر Play (إن كان مثبتًا، أزِل تثبيته ثم ثبّته من جديد).\n2. أكّد رقم الهاتف نفسه.\n3. اضغط \"استعادة\" عندما يعثر على النسخة الاحتياطية المحلية.'**
  String get whatsappRestoreSteps;

  /// No description provided for @whereBackupsGo.
  ///
  /// In ar, this message translates to:
  /// **'أين تريد حفظ النسخ الاحتياطية؟'**
  String get whereBackupsGo;
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(lookupS(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_SDelegate old) => false;
}

S lookupS(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return SAr();
    case 'en':
      return SEn();
  }

  throw FlutterError(
    'S.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
