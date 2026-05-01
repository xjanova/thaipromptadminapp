// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Thaiprompt Admin';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginSubtitle => 'Sign in to manage the platform';

  @override
  String get emailLabel => 'Admin Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'Sign In Securely';

  @override
  String get loginOrDivider => 'or';

  @override
  String get loginWithQr => 'Scan QR to Sign In';

  @override
  String get loginWithOtp => 'Sign In with OTP';

  @override
  String appVersion(Object version) {
    return 'v$version · 2FA Protected';
  }

  @override
  String get qrScannerTitle => 'Scan Pairing QR';

  @override
  String get qrScannerHint =>
      'Point your camera at the QR shown in the admin web';

  @override
  String get qrScannerEnterManually => 'Enter code manually';

  @override
  String get qrScannerCancel => 'Cancel';

  @override
  String get qrPairCodeLabel => '8-character pair code';

  @override
  String get qrPairConfirm => 'Confirm';

  @override
  String get twoFactorTitle => 'Verify 2FA Code';

  @override
  String get twoFactorSubtitle =>
      'Enter the 6-digit code from your Authenticator';

  @override
  String get twoFactorVerify => 'Verify';

  @override
  String get twoFactorResend => 'Resend';

  @override
  String get dashboardTitle => 'Home';

  @override
  String get dashboardWelcome => 'Welcome';

  @override
  String get dashboardMonthlyRevenue => 'Platform Revenue This Month';

  @override
  String get dashboardComparedLastMonth => 'vs. last month';

  @override
  String get dashboardStatNewUsers => 'New Users';

  @override
  String get dashboardStatOrders => 'Orders';

  @override
  String get dashboardStatStores => 'Stores';

  @override
  String get dashboardStatTickets => 'Open Tickets';

  @override
  String get dashboardQuickActions => 'Quick Actions';

  @override
  String get dashboardSeeAll => 'See all →';

  @override
  String get tabHome => 'Home';

  @override
  String get tabModules => 'Modules';

  @override
  String get tabReports => 'Reports';

  @override
  String get tabProfile => 'Profile';

  @override
  String get modulesHubTitle => 'All Modules';

  @override
  String get moduleCategoryFinance => 'Finance';

  @override
  String get moduleCategoryMembers => 'Members / MLM';

  @override
  String get moduleCategoryMarketplace => 'Marketplace';

  @override
  String get moduleCategoryAi => 'AI';

  @override
  String get moduleCategoryFortune => 'Fortune';

  @override
  String get moduleCategorySystem => 'System';

  @override
  String get financeTitle => 'Finance';

  @override
  String get financeWalletsTab => 'Wallets';

  @override
  String get financeWithdrawalsTab => 'Withdrawals';

  @override
  String get financeBillsTab => 'Bills';

  @override
  String get financeBalance => 'Total Balance';

  @override
  String get financePendingWithdrawals => 'Pending';

  @override
  String get walletsListEmpty => 'No wallets yet';

  @override
  String get withdrawalsListEmpty => 'No withdrawal requests';

  @override
  String get withdrawalApprove => 'Approve';

  @override
  String get withdrawalReject => 'Reject';

  @override
  String get withdrawalComplete => 'Mark Transferred';

  @override
  String get withdrawalStatusPending => 'Pending';

  @override
  String get withdrawalStatusApproved => 'Approved';

  @override
  String get withdrawalStatusRejected => 'Rejected';

  @override
  String get withdrawalStatusCompleted => 'Completed';

  @override
  String get errorGeneric => 'Something went wrong, please try again';

  @override
  String get errorNetwork => 'Network connection failed';

  @override
  String get errorUnauthorized => 'Session expired, please log in again';

  @override
  String get errorForbidden => 'Access denied';

  @override
  String get errorValidation => 'Invalid input';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionSearch => 'Search';

  @override
  String get loading => 'Loading...';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLogout => 'Sign Out';

  @override
  String get settingsLogoutAll => 'Sign out of all devices';
}
