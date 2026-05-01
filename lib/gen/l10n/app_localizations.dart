import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('en'),
    Locale('th')
  ];

  /// No description provided for @appName.
  ///
  /// In th, this message translates to:
  /// **'Thaiprompt Admin'**
  String get appName;

  /// No description provided for @loginTitle.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบ'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบเพื่อจัดการแพลตฟอร์ม'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In th, this message translates to:
  /// **'อีเมลผู้ดูแล'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In th, this message translates to:
  /// **'รหัสผ่าน'**
  String get passwordLabel;

  /// No description provided for @rememberMe.
  ///
  /// In th, this message translates to:
  /// **'จดจำการเข้าสู่ระบบ'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In th, this message translates to:
  /// **'ลืมรหัส?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบอย่างปลอดภัย'**
  String get loginButton;

  /// No description provided for @loginOrDivider.
  ///
  /// In th, this message translates to:
  /// **'หรือ'**
  String get loginOrDivider;

  /// No description provided for @loginWithQr.
  ///
  /// In th, this message translates to:
  /// **'สแกน QR เพื่อเข้าสู่ระบบ'**
  String get loginWithQr;

  /// No description provided for @loginWithOtp.
  ///
  /// In th, this message translates to:
  /// **'เข้าสู่ระบบด้วย OTP'**
  String get loginWithOtp;

  /// No description provided for @appVersion.
  ///
  /// In th, this message translates to:
  /// **'v{version} · ป้องกันด้วย 2FA'**
  String appVersion(Object version);

  /// No description provided for @qrScannerTitle.
  ///
  /// In th, this message translates to:
  /// **'สแกน QR Pairing'**
  String get qrScannerTitle;

  /// No description provided for @qrScannerHint.
  ///
  /// In th, this message translates to:
  /// **'หันกล้องไปที่ QR ที่แสดงในเว็บแอดมิน'**
  String get qrScannerHint;

  /// No description provided for @qrScannerEnterManually.
  ///
  /// In th, this message translates to:
  /// **'กรอกรหัสด้วยมือ'**
  String get qrScannerEnterManually;

  /// No description provided for @qrScannerCancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get qrScannerCancel;

  /// No description provided for @qrPairCodeLabel.
  ///
  /// In th, this message translates to:
  /// **'รหัสจับคู่ 8 ตัว'**
  String get qrPairCodeLabel;

  /// No description provided for @qrPairConfirm.
  ///
  /// In th, this message translates to:
  /// **'ยืนยัน'**
  String get qrPairConfirm;

  /// No description provided for @twoFactorTitle.
  ///
  /// In th, this message translates to:
  /// **'ยืนยันรหัส 2FA'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorSubtitle.
  ///
  /// In th, this message translates to:
  /// **'กรอกรหัส 6 หลักจาก Authenticator'**
  String get twoFactorSubtitle;

  /// No description provided for @twoFactorVerify.
  ///
  /// In th, this message translates to:
  /// **'ยืนยัน'**
  String get twoFactorVerify;

  /// No description provided for @twoFactorResend.
  ///
  /// In th, this message translates to:
  /// **'ส่งรหัสใหม่'**
  String get twoFactorResend;

  /// No description provided for @dashboardTitle.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก'**
  String get dashboardTitle;

  /// No description provided for @dashboardWelcome.
  ///
  /// In th, this message translates to:
  /// **'ยินดีต้อนรับ'**
  String get dashboardWelcome;

  /// No description provided for @dashboardMonthlyRevenue.
  ///
  /// In th, this message translates to:
  /// **'รายได้แพลตฟอร์มเดือนนี้'**
  String get dashboardMonthlyRevenue;

  /// No description provided for @dashboardComparedLastMonth.
  ///
  /// In th, this message translates to:
  /// **'เทียบกับเดือนที่แล้ว'**
  String get dashboardComparedLastMonth;

  /// No description provided for @dashboardStatNewUsers.
  ///
  /// In th, this message translates to:
  /// **'สมาชิกใหม่'**
  String get dashboardStatNewUsers;

  /// No description provided for @dashboardStatOrders.
  ///
  /// In th, this message translates to:
  /// **'คำสั่งซื้อ'**
  String get dashboardStatOrders;

  /// No description provided for @dashboardStatStores.
  ///
  /// In th, this message translates to:
  /// **'ร้านค้า'**
  String get dashboardStatStores;

  /// No description provided for @dashboardStatTickets.
  ///
  /// In th, this message translates to:
  /// **'เปิดตั๋ว'**
  String get dashboardStatTickets;

  /// No description provided for @dashboardQuickActions.
  ///
  /// In th, this message translates to:
  /// **'ทางลัดการจัดการ'**
  String get dashboardQuickActions;

  /// No description provided for @dashboardSeeAll.
  ///
  /// In th, this message translates to:
  /// **'ดูทั้งหมด →'**
  String get dashboardSeeAll;

  /// No description provided for @tabHome.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก'**
  String get tabHome;

  /// No description provided for @tabModules.
  ///
  /// In th, this message translates to:
  /// **'โมดูล'**
  String get tabModules;

  /// No description provided for @tabReports.
  ///
  /// In th, this message translates to:
  /// **'รายงาน'**
  String get tabReports;

  /// No description provided for @tabProfile.
  ///
  /// In th, this message translates to:
  /// **'โปรไฟล์'**
  String get tabProfile;

  /// No description provided for @modulesHubTitle.
  ///
  /// In th, this message translates to:
  /// **'โมดูลทั้งหมด'**
  String get modulesHubTitle;

  /// No description provided for @moduleCategoryFinance.
  ///
  /// In th, this message translates to:
  /// **'การเงิน'**
  String get moduleCategoryFinance;

  /// No description provided for @moduleCategoryMembers.
  ///
  /// In th, this message translates to:
  /// **'สมาชิก / MLM'**
  String get moduleCategoryMembers;

  /// No description provided for @moduleCategoryMarketplace.
  ///
  /// In th, this message translates to:
  /// **'Marketplace'**
  String get moduleCategoryMarketplace;

  /// No description provided for @moduleCategoryAi.
  ///
  /// In th, this message translates to:
  /// **'AI'**
  String get moduleCategoryAi;

  /// No description provided for @moduleCategoryFortune.
  ///
  /// In th, this message translates to:
  /// **'พยากรณ์'**
  String get moduleCategoryFortune;

  /// No description provided for @moduleCategorySystem.
  ///
  /// In th, this message translates to:
  /// **'ระบบ'**
  String get moduleCategorySystem;

  /// No description provided for @financeTitle.
  ///
  /// In th, this message translates to:
  /// **'การเงิน'**
  String get financeTitle;

  /// No description provided for @financeWalletsTab.
  ///
  /// In th, this message translates to:
  /// **'วอลเล็ต'**
  String get financeWalletsTab;

  /// No description provided for @financeWithdrawalsTab.
  ///
  /// In th, this message translates to:
  /// **'ถอนเงิน'**
  String get financeWithdrawalsTab;

  /// No description provided for @financeBillsTab.
  ///
  /// In th, this message translates to:
  /// **'บิล'**
  String get financeBillsTab;

  /// No description provided for @financeBalance.
  ///
  /// In th, this message translates to:
  /// **'ยอดคงเหลือรวม'**
  String get financeBalance;

  /// No description provided for @financePendingWithdrawals.
  ///
  /// In th, this message translates to:
  /// **'รออนุมัติ'**
  String get financePendingWithdrawals;

  /// No description provided for @walletsListEmpty.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มี wallet ในระบบ'**
  String get walletsListEmpty;

  /// No description provided for @withdrawalsListEmpty.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีคำขอถอนเงิน'**
  String get withdrawalsListEmpty;

  /// No description provided for @withdrawalApprove.
  ///
  /// In th, this message translates to:
  /// **'อนุมัติ'**
  String get withdrawalApprove;

  /// No description provided for @withdrawalReject.
  ///
  /// In th, this message translates to:
  /// **'ปฏิเสธ'**
  String get withdrawalReject;

  /// No description provided for @withdrawalComplete.
  ///
  /// In th, this message translates to:
  /// **'บันทึกการโอน'**
  String get withdrawalComplete;

  /// No description provided for @withdrawalStatusPending.
  ///
  /// In th, this message translates to:
  /// **'รออนุมัติ'**
  String get withdrawalStatusPending;

  /// No description provided for @withdrawalStatusApproved.
  ///
  /// In th, this message translates to:
  /// **'อนุมัติแล้ว'**
  String get withdrawalStatusApproved;

  /// No description provided for @withdrawalStatusRejected.
  ///
  /// In th, this message translates to:
  /// **'ปฏิเสธ'**
  String get withdrawalStatusRejected;

  /// No description provided for @withdrawalStatusCompleted.
  ///
  /// In th, this message translates to:
  /// **'โอนแล้ว'**
  String get withdrawalStatusCompleted;

  /// No description provided for @errorGeneric.
  ///
  /// In th, this message translates to:
  /// **'เกิดข้อผิดพลาด กรุณาลองใหม่'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In th, this message translates to:
  /// **'เชื่อมต่อเครือข่ายไม่ได้'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In th, this message translates to:
  /// **'หมดอายุการเข้าสู่ระบบ กรุณา login ใหม่'**
  String get errorUnauthorized;

  /// No description provided for @errorForbidden.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีสิทธิ์เข้าถึง'**
  String get errorForbidden;

  /// No description provided for @errorValidation.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลไม่ถูกต้อง'**
  String get errorValidation;

  /// No description provided for @actionCancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get actionCancel;

  /// No description provided for @actionConfirm.
  ///
  /// In th, this message translates to:
  /// **'ยืนยัน'**
  String get actionConfirm;

  /// No description provided for @actionRetry.
  ///
  /// In th, this message translates to:
  /// **'ลองใหม่'**
  String get actionRetry;

  /// No description provided for @actionSearch.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา'**
  String get actionSearch;

  /// No description provided for @loading.
  ///
  /// In th, this message translates to:
  /// **'กำลังโหลด...'**
  String get loading;

  /// No description provided for @settingsTitle.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In th, this message translates to:
  /// **'ภาษา'**
  String get settingsLanguage;

  /// No description provided for @settingsLogout.
  ///
  /// In th, this message translates to:
  /// **'ออกจากระบบ'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutAll.
  ///
  /// In th, this message translates to:
  /// **'ออกจากทุกอุปกรณ์'**
  String get settingsLogoutAll;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'th':
      return AppL10nTh();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
