import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:permission_handler/permission_handler.dart'; // ضروري للبطارية
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme.dart';
import '../../main.dart'; // للوصول لـ Notifiers

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  // حالة البطارية الحقيقية
  bool _isBatteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // لمراقبة العودة من الإعدادات
    _checkBatteryStatus(); // فحص الحالة عند البدء
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // تحديث الحالة عند العودة للتطبيق (في حال غير المستخدم الإعداد من الخارج)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBatteryStatus();
    }
  }

  Future<void> _checkBatteryStatus() async {
    // التحقق هل التطبيق في القائمة البيضاء (مسموح له بالعمل)
    final isIgnored = await Permission.ignoreBatteryOptimizations.isGranted;
    if (mounted) {
      setState(() {
        _isBatteryOptimizationIgnored = isIgnored;
      });
    }
  }

  Future<void> _requestBatteryPermission(bool value) async {
    if (value) {
      // طلب الإذن
      await Permission.ignoreBatteryOptimizations.request();
    } else {
      // لا يمكن إلغاء الإذن برمجياً، نوجه المستخدم للإعدادات
      await openAppSettings();
    }
    // إعادة الفحص بعد الإجراء
    await _checkBatteryStatus();
  }

  // --- Logic Functions ---

  void _changeLanguage(String code) {
    SettingsService.setLanguage(code);
    localeNotifier.value = Locale(code);
    Navigator.pop(context);
  }

  void _toggleDarkMode(bool val) {
    SettingsService.setDarkMode(val);
    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
  }

  // --- UI Build ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "الإعدادات",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. قسم عام (اللغة والثيم) - تم الإبقاء عليه
            _sectionHeader("عام"),
            _sectionBox([
              _tile(HugeIcons.strokeRoundedGlobal, "اللغة",
                  trailing: _langName(SettingsService.language),
                  onTap: _showLangSheet),
              _divider(),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (_, mode, __) {
                  return _tile(HugeIcons.strokeRoundedMoon02, "الوضع الداكن",
                      trailingWidget: Switch.adaptive(
                        value: mode == ThemeMode.dark,
                        activeTrackColor: AppTheme.primaryColor,
                        onChanged: _toggleDarkMode,
                      ));
                },
              ),
            ]),

            const SizedBox(height: 24),

            // ⚠️ تم حذف قسم "إعدادات الصلاة" (الموقع وتعديل الوقت) بالكامل كما طلبت ✅

            // 2. قسم النظام (الإشعارات والبطارية)
            _sectionHeader("النظام"),
            _sectionBox([
              _tile(HugeIcons.strokeRoundedNotification01, "إشعارات الصلاة",
                  trailingWidget:
                      Switch.adaptive(value: true, onChanged: (v) {})),
              _divider(),
              // زر البطارية الذكي الجديد 🔋
              _tile(HugeIcons.strokeRoundedBatteryCharging01,
                  "تجاهل تحسين البطارية",
                  subtitle: "لضمان دقة الأذان في الخلفية",
                  trailingWidget: Switch.adaptive(
                    value: _isBatteryOptimizationIgnored, // يعكس الواقع
                    activeTrackColor: AppTheme.primaryColor,
                    onChanged: (val) => _requestBatteryPermission(val),
                  )),
            ]),

            const SizedBox(height: 40),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  void _showLangSheet() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        builder: (ctx) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                const Text("اختر اللغة",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                _langTile("العربية", 'ar'),
                _langTile("English", 'en'),
                _langTile("Français", 'fr'),
                const SizedBox(height: 20),
              ],
            ));
  }

  Widget _langTile(String title, String code) {
    bool isSelected = SettingsService.language == code;
    return ListTile(
      title: Text(title),
      trailing: isSelected
          ? const Icon(Icons.check, color: AppTheme.primaryColor)
          : null,
      onTap: () => _changeLanguage(code),
    );
  }

  Widget _sectionHeader(String title) => Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 10, left: 10),
      child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(title,
              style: const TextStyle(
                  color: Colors.grey, fontWeight: FontWeight.bold))));

  Widget _sectionBox(List<Widget> children) => Container(
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
          ]),
      child: Column(children: children));

  Widget _divider() =>
      const Divider(height: 1, indent: 60, color: Colors.black12);

  Widget _tile(dynamic icon, String title,
      {String? subtitle,
      String? trailing,
      Widget? trailingWidget,
      VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: isDark
                  ? Colors.white10
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: HugeIcon(
              icon: icon,
              color: isDark ? Colors.white : AppTheme.primaryColor,
              size: 24)),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 11))
          : null,
      trailing: trailingWidget ??
          (trailing != null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(trailing,
                      style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(width: 5),
                  const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey)
                ])
              : null),
      onTap: onTap,
    );
  }

  Widget _buildFooter() => Column(children: [
        Text("Sakin v1.0.0", style: TextStyle(color: Colors.grey.shade400)),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _socialBtn(HugeIcons.strokeRoundedGithub,
              "https://github.com/Xoner1/-sakin-app"),
          const SizedBox(width: 20),
          _socialBtn(
              HugeIcons.strokeRoundedMail01, "mailto:fakhridfarhat@gmail.com"),
        ])
      ]);

  Widget _socialBtn(dynamic icon, String url) {
    return InkWell(
      onTap: () async => await launchUrl(Uri.parse(url)),
      child: HugeIcon(icon: icon, color: Colors.grey, size: 24),
    );
  }

  String _langName(String c) =>
      c == 'ar' ? 'العربية' : (c == 'fr' ? 'Français' : 'English');
}
