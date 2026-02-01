import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/prayer_service.dart';
import '../../services/location_service.dart';
import '../../services/settings_service.dart';
import '../../models/location_info.dart';
import 'package:adhan/adhan.dart';
import 'package:sakin_app/l10n/generated/app_localizations.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  @override
  void initState() {
    super.initState();
    // Load location when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      if (locationService.currentLocation == null) {
        locationService.getCurrentLocation();
      }

      // Load current settings
      final settingsService =
          Provider.of<SettingsService>(context, listen: false);
      settingsService.loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prayerService = Provider.of<PrayerService>(context);
    final locationService = Provider.of<LocationService>(context);
    final settingsService = Provider.of<SettingsService>(context);

    // List of prayers (excluding sunrise)
    final prayers = [
      {
        'name': 'الفجر',
        'prayer': Prayer.fajr,
        'icon': HugeIcons.strokeRoundedSun01,
        'key': 'fajr'
      },
      {
        'name': 'الظهر',
        'prayer': Prayer.dhuhr,
        'icon': HugeIcons.strokeRoundedSun01,
        'key': 'dhuhr'
      },
      {
        'name': 'العصر',
        'prayer': Prayer.asr,
        'icon': HugeIcons.strokeRoundedSun01,
        'key': 'asr'
      },
      {
        'name': 'المغرب',
        'prayer': Prayer.maghrib,
        'icon': HugeIcons.strokeRoundedSunset,
        'key': 'maghrib'
      },
      {
        'name': 'العشاء',
        'prayer': Prayer.isha,
        'icon': HugeIcons.strokeRoundedMoon01,
        'key': 'isha'
      },
    ];

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.prayerTimes),
        centerTitle: true,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Colored Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                // Location information display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      locationService.currentLocation?.address ??
                          'جاري تحديد الموقع...',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (locationService.currentLocation?.mode ==
                        LocationMode.cached)
                      const Padding(
                        padding: EdgeInsets.only(left: 5),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCloud,
                          color: Colors.orange,
                          size: 14,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Hijri date display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      prayerService.getHijriDate(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Update location button
                ElevatedButton.icon(
                  onPressed: locationService.isLoading
                      ? null
                      : () async {
                          final loc =
                              await locationService.getCurrentLocation();
                          if (loc != null) {
                            prayerService.scheduleNotifications(
                                settingsService.settings);
                          }
                        },
                  icon: locationService.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const HugeIcon(
                          icon: HugeIcons.strokeRoundedRefresh,
                        ),
                  label: Text(locationService.isLoading
                      ? 'جاري التحديث...'
                      : 'تحديث الموقع'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Prayer times list
          Expanded(
            child: prayerService.prayerTimes == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: prayers.length,
                    itemBuilder: (context, index) {
                      final prayerData = prayers[index];
                      final prayer = prayerData['prayer'] as Prayer;
                      final prayerKey = prayerData['key'] as String;
                      final time = prayerService.getAdjustedTime(prayer);
                      final isNext = prayerService.nextPrayer == prayer;

                      // Notification enabled status
                      bool isEnabled = true;
                      switch (prayerKey) {
                        case 'fajr':
                          isEnabled = settingsService.settings.fajrEnabled;
                          break;
                        case 'dhuhr':
                          isEnabled = settingsService.settings.dhuhrEnabled;
                          break;
                        case 'asr':
                          isEnabled = settingsService.settings.asrEnabled;
                          break;
                        case 'maghrib':
                          isEnabled = settingsService.settings.maghribEnabled;
                          break;
                        case 'isha':
                          isEnabled = settingsService.settings.ishaEnabled;
                          break;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isNext
                              ? AppTheme.primaryColor.withValues(alpha: 0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isNext
                                ? AppTheme.primaryColor
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isNext
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: HugeIcon(
                              icon: prayerData['icon'] as dynamic,
                              color:
                                  isNext ? Colors.white : AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            prayerData['name'] as String,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  isNext ? FontWeight.bold : FontWeight.w500,
                              color: isNext
                                  ? AppTheme.primaryColor
                                  : Colors.black87,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Prayer time display
                              Text(
                                time != null
                                    ? prayerService.getFormattedTime(time)
                                    : '--:--',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isNext
                                      ? AppTheme.primaryColor
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Notification toggle switch
                              Transform.scale(
                                scale: 0.8,
                                child: Switch(
                                  value: isEnabled,
                                  activeThumbColor: AppTheme.primaryColor,
                                  onChanged: (value) async {
                                    await settingsService.togglePrayer(
                                        prayerKey, value);
                                    // Reschedule alarms immediately after change
                                    prayerService.scheduleNotifications(
                                        settingsService.settings);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
