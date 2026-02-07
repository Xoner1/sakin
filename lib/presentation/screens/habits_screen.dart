import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/theme.dart';
import '../../core/services/habit_service.dart';
/* Added for Install Date */
import 'package:sakin_app/l10n/generated/app_localizations.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  // Data
  List<String> _habits = [];
  double _todayProgress = 0.0;

  // Monthly calendar state
  DateTime _currentMonth = DateTime.now();
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _monthSuccessRate = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Reloads all data from the Service
  void _refreshData() {
    setState(() {
      _habits = HabitService.getHabits();
      _calculateProgress();
      _currentStreak = HabitService.getCurrentStreak();
      _bestStreak = HabitService.getBestStreak();
      _monthSuccessRate = HabitService.getMonthSuccessRate(_currentMonth);
    });
  }

  void _calculateProgress() {
    if (_habits.isEmpty) {
      _todayProgress = 0.0;
      return;
    }

    int completedCount = 0;
    for (var habit in _habits) {
      if (HabitService.isHabitCompletedToday(habit)) {
        completedCount++;
      }
    }
    _todayProgress = completedCount / _habits.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark),
              const SizedBox(height: 20),

              // Stats Cards
              _buildStatsCards(isDark),
              const SizedBox(height: 16),

              // Monthly Calendar
              Text(AppLocalizations.of(context)!.habitLog,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(height: 10),
              _buildMonthlyCalendar(isDark),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.todaysTasks,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black)),
                  InkWell(
                    onTap: () => _showHabitDialog(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppTheme.primaryColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add,
                              color: AppTheme.primaryColor, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.addHabit,
                            style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildHabitsList(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildHabitsList(bool isDark) {
    if (_habits.isEmpty) {
      return Center(
          child: Text(AppLocalizations.of(context)!.noTasksYet,
              style: const TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final habitName = _habits[index];
        bool isCompleted = HabitService.isHabitCompletedToday(habitName);

        return Dismissible(
          key: Key(habitName),
          background: Container(
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              children: [
                Icon(Icons.edit, color: Colors.white),
                SizedBox(width: 8),
                Text('تعديل',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
          secondaryBackground: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('حذف',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                SizedBox(width: 8),
                Icon(Icons.delete, color: Colors.white),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            // Haptic feedback for safety
            await HapticFeedback.mediumImpact();

            if (direction == DismissDirection.startToEnd) {
              // Swipe right to edit
              _showHabitDialog(initialName: habitName, index: index);
              return false; // Don't dismiss the item
            } else {
              // Swipe left to delete - show confirmation
              return await _showDeleteConfirmDialog(habitName);
            }
          },
          child: GestureDetector(
            onTap: () async {
              await HabitService.toggleHabit(habitName);
              _refreshData();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? AppTheme.primaryColor
                          : Colors.transparent,
                      border: Border.all(
                          color: isCompleted
                              ? AppTheme.primaryColor
                              : (isDark
                                  ? Colors.white38
                                  : Colors.grey.shade400),
                          width: 2),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      habitName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isCompleted
                            ? (isDark ? Colors.white38 : Colors.grey)
                            : (isDark ? Colors.white : Colors.black87),
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  HugeIcon(
                      icon: HugeIcons.strokeRoundedCheckList,
                      color: isDark ? Colors.white38 : Colors.grey,
                      size: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Dialogs ---

  void _showHabitDialog({String? initialName, int? index}) {
    final controller = TextEditingController(text: initialName);
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(initialName == null ? l10n.addHabit : l10n.editHabit),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: l10n.habitName),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                if (index != null && initialName != null) {
                  // Rename logic:
                  // 1. Check if completed today using old name
                  bool wasCompleted =
                      HabitService.isHabitCompletedToday(initialName);
                  // 2. Delete old
                  await HabitService.deleteHabit(initialName);
                  // 3. Add new
                  await HabitService.addHabit(controller.text);
                  // 4. Restore completion status if needed
                  if (wasCompleted) {
                    // We need to mark new one as done.
                    // But wait, toggle toggles. We need to be careful.
                    // If we just added it, it's not done. Toggle it to make it done.
                    await HabitService.toggleHabit(controller.text);
                  }
                } else {
                  await HabitService.addHabit(controller.text);
                }
                _refreshData();
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(String habitName) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Must choose an option
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.orange, size: 48),
        title: Text(l10n.deleteHabitTitle, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.deleteHabitConfirmation,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.shade900.withValues(alpha: 0.3)
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade300),
              ),
              child: Text(
                '"$habitName"',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel,
                style:
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Capture messenger before async gap
              final messenger = ScaffoldMessenger.of(context);

              await HabitService.deleteHabit(habitName);
              _refreshData();
              if (ctx.mounted) {
                Navigator.pop(ctx, true);
                // Show success message
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('تم حذف "$habitName" بنجاح'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // --- Helpers ---

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.05),
              blurRadius: 10)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppLocalizations.of(context)!.achievementBoard,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black)),
            Text(AppLocalizations.of(context)!.smallSteps,
                style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey)),
          ]),
          Stack(alignment: Alignment.center, children: [
            SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                    value: _todayProgress,
                    color: AppTheme.primaryColor,
                    backgroundColor:
                        isDark ? Colors.white10 : Colors.grey.shade100)),
            Text("${(_todayProgress * 100).toInt()}%",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black)),
          ]),
        ],
      ),
    );
  }

  // ==========================================================================
  // Stats Cards Widget
  // ==========================================================================

  Widget _buildStatsCards(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          _buildStatCard(
            emoji: '🔥',
            label: 'Current Streak',
            value: '$_currentStreak يوم',
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            emoji: '⭐',
            label: 'Best Streak',
            value: '$_bestStreak يوم',
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            emoji: '📊',
            label: 'Success Rate',
            value: '$_monthSuccessRate%',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String emoji,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // Monthly Calendar Widget
  // ==========================================================================

  Widget _buildMonthlyCalendar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMonthHeader(isDark),
          const SizedBox(height: 16),
          _buildWeekdayLabels(isDark),
          const SizedBox(height: 8),
          _buildCalendarGrid(isDark),
          const SizedBox(height: 12),
          _buildMonthStats(isDark),
        ],
      ),
    );
  }

  Widget _buildMonthHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        Text(
          _formatMonthYear(_currentMonth),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ],
    );
  }

  Widget _buildWeekdayLabels(bool isDark) {
    final weekdays = ['ن', 'ث', 'خ', 'ج', 'س', 'ح', 'أ'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays
          .map((day) => SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCalendarGrid(bool isDark) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startingWeekday = firstDay.weekday % 7;

    List<Widget> dayWidgets = [];

    // Add empty cells before first day
    for (int i = 0; i < startingWeekday; i++) {
      dayWidgets.add(const SizedBox(width: 40, height: 40));
    }

    // Add days of month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isFuture = date.isAfter(DateTime.now());
      final percentage =
          isFuture ? 0.0 : HabitService.getCompletionPercentageForDate(date);

      dayWidgets.add(_buildDayCell(day, percentage, isDark, isFuture));
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(int day, double percentage, bool isDark, bool isFuture) {
    Color color;

    if (isFuture) {
      color = isDark ? Colors.white10 : Colors.grey.shade100;
    } else {
      color = _getGradientColor(percentage, isDark);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: percentage > 0.5
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthStats(bool isDark) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final today = DateTime.now();

    int totalDays = 0;
    int completedDays = 0;

    for (var date = firstDay;
        !date.isAfter(lastDay) && !date.isAfter(today);
        date = date.add(const Duration(days: 1))) {
      totalDays++;
      if (HabitService.getCompletionPercentageForDate(date) > 0) {
        completedDays++;
      }
    }

    return Text(
      'إنجاز الشهر: $completedDays/$totalDays يوم',
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white60 : Colors.black54,
      ),
    );
  }

  // ==========================================================================
  // Helper Methods
  // ==========================================================================

  Color _getGradientColor(double percentage, bool isDark) {
    if (isDark) {
      if (percentage == 0) return Colors.white10;
      if (percentage < 0.25) return const Color(0xFF3D5843);
      if (percentage < 0.50) return const Color(0xFF4F6E55);
      if (percentage < 0.75) return const Color(0xFF61845F);
      return AppTheme.primaryColor;
    } else {
      if (percentage == 0) return Colors.grey.shade100;
      if (percentage < 0.25) return const Color(0xFFB8C9BC);
      if (percentage < 0.50) return const Color(0xFF8FAF97);
      if (percentage < 0.75) return const Color(0xFF6F9577);
      return AppTheme.primaryColor;
    }
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _monthSuccessRate = HabitService.getMonthSuccessRate(_currentMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _monthSuccessRate = HabitService.getMonthSuccessRate(_currentMonth);
    });
  }
}
