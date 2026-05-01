// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppL10nTh extends AppL10n {
  AppL10nTh([String locale = 'th']) : super(locale);

  @override
  String get appName => 'Thaiprompt Admin';

  @override
  String get loginTitle => 'เข้าสู่ระบบ';

  @override
  String get loginSubtitle => 'เข้าสู่ระบบเพื่อจัดการแพลตฟอร์ม';

  @override
  String get emailLabel => 'อีเมลผู้ดูแล';

  @override
  String get passwordLabel => 'รหัสผ่าน';

  @override
  String get rememberMe => 'จดจำการเข้าสู่ระบบ';

  @override
  String get forgotPassword => 'ลืมรหัส?';

  @override
  String get loginButton => 'เข้าสู่ระบบอย่างปลอดภัย';

  @override
  String get loginOrDivider => 'หรือ';

  @override
  String get loginWithQr => 'สแกน QR เพื่อเข้าสู่ระบบ';

  @override
  String get loginWithOtp => 'เข้าสู่ระบบด้วย OTP';

  @override
  String appVersion(Object version) {
    return 'v$version · ป้องกันด้วย 2FA';
  }

  @override
  String get qrScannerTitle => 'สแกน QR Pairing';

  @override
  String get qrScannerHint => 'หันกล้องไปที่ QR ที่แสดงในเว็บแอดมิน';

  @override
  String get qrScannerEnterManually => 'กรอกรหัสด้วยมือ';

  @override
  String get qrScannerCancel => 'ยกเลิก';

  @override
  String get qrPairCodeLabel => 'รหัสจับคู่ 8 ตัว';

  @override
  String get qrPairConfirm => 'ยืนยัน';

  @override
  String get twoFactorTitle => 'ยืนยันรหัส 2FA';

  @override
  String get twoFactorSubtitle => 'กรอกรหัส 6 หลักจาก Authenticator';

  @override
  String get twoFactorVerify => 'ยืนยัน';

  @override
  String get twoFactorResend => 'ส่งรหัสใหม่';

  @override
  String get dashboardTitle => 'หน้าหลัก';

  @override
  String get dashboardWelcome => 'ยินดีต้อนรับ';

  @override
  String get dashboardMonthlyRevenue => 'รายได้แพลตฟอร์มเดือนนี้';

  @override
  String get dashboardComparedLastMonth => 'เทียบกับเดือนที่แล้ว';

  @override
  String get dashboardStatNewUsers => 'สมาชิกใหม่';

  @override
  String get dashboardStatOrders => 'คำสั่งซื้อ';

  @override
  String get dashboardStatStores => 'ร้านค้า';

  @override
  String get dashboardStatTickets => 'เปิดตั๋ว';

  @override
  String get dashboardQuickActions => 'ทางลัดการจัดการ';

  @override
  String get dashboardSeeAll => 'ดูทั้งหมด →';

  @override
  String get tabHome => 'หน้าหลัก';

  @override
  String get tabModules => 'โมดูล';

  @override
  String get tabReports => 'รายงาน';

  @override
  String get tabProfile => 'โปรไฟล์';

  @override
  String get modulesHubTitle => 'โมดูลทั้งหมด';

  @override
  String get moduleCategoryFinance => 'การเงิน';

  @override
  String get moduleCategoryMembers => 'สมาชิก / MLM';

  @override
  String get moduleCategoryMarketplace => 'Marketplace';

  @override
  String get moduleCategoryAi => 'AI';

  @override
  String get moduleCategoryFortune => 'พยากรณ์';

  @override
  String get moduleCategorySystem => 'ระบบ';

  @override
  String get financeTitle => 'การเงิน';

  @override
  String get financeWalletsTab => 'วอลเล็ต';

  @override
  String get financeWithdrawalsTab => 'ถอนเงิน';

  @override
  String get financeBillsTab => 'บิล';

  @override
  String get financeBalance => 'ยอดคงเหลือรวม';

  @override
  String get financePendingWithdrawals => 'รออนุมัติ';

  @override
  String get walletsListEmpty => 'ยังไม่มี wallet ในระบบ';

  @override
  String get withdrawalsListEmpty => 'ไม่มีคำขอถอนเงิน';

  @override
  String get withdrawalApprove => 'อนุมัติ';

  @override
  String get withdrawalReject => 'ปฏิเสธ';

  @override
  String get withdrawalComplete => 'บันทึกการโอน';

  @override
  String get withdrawalStatusPending => 'รออนุมัติ';

  @override
  String get withdrawalStatusApproved => 'อนุมัติแล้ว';

  @override
  String get withdrawalStatusRejected => 'ปฏิเสธ';

  @override
  String get withdrawalStatusCompleted => 'โอนแล้ว';

  @override
  String get errorGeneric => 'เกิดข้อผิดพลาด กรุณาลองใหม่';

  @override
  String get errorNetwork => 'เชื่อมต่อเครือข่ายไม่ได้';

  @override
  String get errorUnauthorized => 'หมดอายุการเข้าสู่ระบบ กรุณา login ใหม่';

  @override
  String get errorForbidden => 'ไม่มีสิทธิ์เข้าถึง';

  @override
  String get errorValidation => 'ข้อมูลไม่ถูกต้อง';

  @override
  String get actionCancel => 'ยกเลิก';

  @override
  String get actionConfirm => 'ยืนยัน';

  @override
  String get actionRetry => 'ลองใหม่';

  @override
  String get actionSearch => 'ค้นหา';

  @override
  String get loading => 'กำลังโหลด...';

  @override
  String get settingsTitle => 'ตั้งค่า';

  @override
  String get settingsLanguage => 'ภาษา';

  @override
  String get settingsLogout => 'ออกจากระบบ';

  @override
  String get settingsLogoutAll => 'ออกจากทุกอุปกรณ์';
}
