import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sakin_app/l10n/generated/app_localizations.dart';

import 'package:timezone/data/latest.dart' as tz;

import 'presentation/screens/settings_screen.dart';
import 'presentation/screens/adhan_alarm_page.dart';
import 'services/permission_service.dart';

import 'core/theme.dart';
import 'services/prayer_service.dart';
import 'services/notification_service.dart';
import 'services/location_service.dart';
import 'services/settings_service.dart';
import 'services/battery_optimization_service.dart';
import 'services/alarm_service.dart'; // New Service

import 'data/hive_database.dart';
import 'presentation/widgets/nav_bar.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/habits_screen.dart';
import 'presentation/screens/prayer_times_screen.dart';
import 'presentation/screens/adhkar_screen.dart';

import 'package:sakin_app/models/location_info.dart';
import 'package:sakin_app/providers/dependencies/adhan_dependency_provider.dart';
import 'package:sakin_app/providers/adhan_playback_provider.dart';
import 'package:sakin_app/providers/adhan_provider.dart';
import 'package:sakin_app/providers/adhan_notification_provider.dart';

// Global navigator key for navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Initialize date formatting locale
  await initializeDateFormatting('ar', null);
  tz.initializeTimeZones();

  // 1. Initialize Database (Ensure Hive is initialized first)
  final hiveDb = HiveDatabase();
  await hiveDb.init();

  // 2. Request necessary permissions (Only once)
  // Use Hive (Settings Box) to check if permissions were already requested
  var settingsBox = await Hive.openBox('settings');
  bool permissionsRequested =
      settingsBox.get('permissions_requested', defaultValue: false);

  if (!permissionsRequested) {
    debugPrint('Requesting permissions for the first time...');

    // Use the robust PermissionService
    final permissionService = PermissionService();
    await permissionService.requestNotificationPermissions();

    // Also request location specifically for the first time
    await Permission.location.request();

    // Mark as requested preventing future prompts
    await settingsBox.put('permissions_requested', true);
  } else {
    debugPrint('Permissions already requested previously. Skipping.');
  }

  // 3. Initialize Services
  await NotificationService.init();
  if (Platform.isAndroid) {
    await AndroidAlarmManager
        .initialize(); // Initialize Alarm Manager (Android only)
  }

  // 5. Initialize Location Service
  final locationService = LocationService();
  await locationService.init();

  // 7. Setup callback to open Adhkar screen on notification tap
  NotificationService.onAdhkarTap = (payload) {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const AdhkarScreen()),
    );
  };

  runApp(SakinApp(hiveDb: hiveDb, locationService: locationService));
}

class SakinApp extends StatelessWidget {
  final HiveDatabase hiveDb;
  final LocationService locationService;
  const SakinApp(
      {super.key, required this.hiveDb, required this.locationService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: hiveDb),
        ChangeNotifierProvider.value(value: locationService),
        ChangeNotifierProvider(
            create: (_) => SettingsService()..loadSettings()),
        ChangeNotifierProvider(create: (_) => AdhanDependencyProvider()),
        ChangeNotifierProvider(create: (_) => AdhanPlayBackProvider()),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, child) {
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            title: 'Sakin',
            theme: AppTheme.lightTheme,
            locale: settings.locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ar'),
              Locale('en'),
              Locale('fr'),
            ],
            builder: (context, child) {
              return MultiProvider(
                providers: [
                  ChangeNotifierProxyProvider2<AdhanDependencyProvider,
                      LocationService, AdhanProvider>(
                    create: (context) => AdhanProvider(
                      Provider.of<AdhanDependencyProvider>(context,
                          listen: false),
                      Provider.of<LocationService>(context, listen: false)
                              .currentLocation ??
                          LocationInfo(
                              latitude: 0,
                              longitude: 0,
                              address: '',
                              mode: LocationMode.manual), // Default
                      null,
                    ),
                    update: (context, dep, loc, prev) {
                      return AdhanProvider(
                        dep,
                        loc.currentLocation ??
                            LocationInfo(
                                latitude: 0,
                                longitude: 0,
                                address: '',
                                mode: LocationMode.manual),
                        AppLocalizations.of(context),
                      );
                    },
                  ),
                  ChangeNotifierProxyProvider2<AdhanDependencyProvider,
                      LocationService, AdhanNotificationProvider>(
                    create: (context) => AdhanNotificationProvider(
                      Provider.of<AdhanDependencyProvider>(context,
                          listen: false),
                      Provider.of<LocationService>(context, listen: false)
                              .currentLocation ??
                          LocationInfo(
                              latitude: 0,
                              longitude: 0,
                              address: '',
                              mode: LocationMode.manual),
                      null,
                    ),
                    update: (context, dep, loc, prev) {
                      return AdhanNotificationProvider(
                        dep,
                        loc.currentLocation ??
                            LocationInfo(
                                latitude: 0,
                                longitude: 0,
                                address: '',
                                mode: LocationMode.manual),
                        AppLocalizations.of(context),
                      );
                    },
                  ),
// Keep PrayerService for now if needed, or rely on refactor
                  ChangeNotifierProxyProvider<LocationService, PrayerService>(
                    create: (_) => PrayerService(),
                    update: (_, location, prayerService) {
                      if (prayerService != null &&
                          location.currentLocation != null) {
                        prayerService.updateLocation(
                          location.currentLocation!.latitude,
                          location.currentLocation!.longitude,
                        );
                      }
                      return prayerService ?? PrayerService();
                    },
                  ),
                ],
                child: child!,
              );
            },
            home: const MainLayout(),
            routes: {
              '/adhkar': (context) => const AdhkarScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      BatteryOptimizationService.checkAndPrompt(context);
      _checkNotificationLaunch();

      // NEW: Alarm-Style Scheduling
      await PrayerAlarmScheduler.scheduleSevenDays();
      await PrayerAlarmScheduler.checkAndNotifyTTL();
    });
  }

  /* Removed legacy background service calls */

  Future<void> _checkNotificationLaunch() async {
    final bool launchedFromAdhan =
        await NotificationService.didLaunchFromAdhan();
    if (launchedFromAdhan && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AdhanAlarmPage()),
      );
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const HabitsScreen(),
    const PrayerTimesScreen(),
    const SettingsScreen(), // Settings Page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: CustomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
