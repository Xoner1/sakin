import 'package:hive_flutter/hive_flutter.dart';

class HabitService {
  // 📦 Define Box Names
  static const String _habitsBox =
      'habit_definitions'; // Stores List<String> of habits
  static const String _completionsBox =
      'habit_completions'; // Stores Key: HabitName, Value: DateTime
  static const String _historyBox =
      'habit_history'; // Stores Key: Date(String), Value: Count(int)

  ///  Initialize Hive Boxes (Call this in main.dart)
  static Future<void> init() async {
    // Ensure Hive is initialized only once in main, but we open boxes here
    if (!Hive.isBoxOpen(_habitsBox)) await Hive.openBox(_habitsBox);
    if (!Hive.isBoxOpen(_completionsBox)) await Hive.openBox(_completionsBox);
    if (!Hive.isBoxOpen(_historyBox)) await Hive.openBox(_historyBox);
  }

  // -----------------------------------------------------------------------------
  // 🔄 Daily Reset Logic (The Core Fix)
  // -----------------------------------------------------------------------------

  /// Checks if a habit is completed TODAY based on DateTime comparison.
  /// This automatically "resets" the checkbox the next day without any manual reset code.
  static bool isHabitCompletedToday(String habitName) {
    final box = Hive.box(_completionsBox);
    final lastCompletionDate = box.get(habitName);

    if (lastCompletionDate == null || lastCompletionDate is! DateTime) {
      return false;
    }

    return _isSameDay(lastCompletionDate, DateTime.now());
  }

  /// Toggles the habit status and updates the Heatmap history accordingly.
  static Future<void> toggleHabit(String habitName) async {
    final completionsBox = Hive.box(_completionsBox);
    final bool isDone = isHabitCompletedToday(habitName);

    if (isDone) {
      // 🔽 UNCHECK: Remove completion & Decrease Heatmap count
      await completionsBox.delete(habitName);
      await _updateHeatmapHistory(increment: false);
    } else {
      // 🔼 CHECK: Save NOW as completion time & Increase Heatmap count
      await completionsBox.put(habitName, DateTime.now());
      await _updateHeatmapHistory(increment: true);
    }
  }

  // -----------------------------------------------------------------------------
  // 📊 Heatmap History Logic (Data Loss Prevention)
  // -----------------------------------------------------------------------------

  /// Updates the count for TODAY in the history box.
  /// It reads the old value first to ensure we don't overwrite history.
  static Future<void> _updateHeatmapHistory({required bool increment}) async {
    final historyBox = Hive.box(_historyBox);
    final String todayKey = _formatDateKey(DateTime.now());

    // Get current count (default to 0)
    int currentCount = historyBox.get(todayKey, defaultValue: 0);

    // Calculate new count
    int newCount = increment ? currentCount + 1 : currentCount - 1;
    if (newCount < 0) newCount = 0; // Safety check

    // Save back to Hive
    await historyBox.put(todayKey, newCount);
  }

  /// Returns the dataset formatted for the Heatmap Widget
  static Map<DateTime, int> getHeatmapDataset() {
    final historyBox = Hive.box(_historyBox);
    Map<DateTime, int> dataset = {};

    for (var key in historyBox.keys) {
      // Convert String Key (YYYY-MM-DD) back to DateTime
      final date = _parseDateKey(key.toString());
      final count = historyBox.get(key);
      if (date != null && count is int) {
        dataset[date] = count;
      }
    }
    return dataset;
  }

  // -----------------------------------------------------------------------------
  // 📝 CRUD for Habits List
  // -----------------------------------------------------------------------------

  static List<String> getHabits() {
    final box = Hive.box(_habitsBox);
    return box
        .get('CURRENT_HABIT_LIST', defaultValue: <String>[]).cast<String>();
  }

  static Future<void> addHabit(String habitName) async {
    final box = Hive.box(_habitsBox);
    List<String> currentHabits = getHabits();
    currentHabits.add(habitName);
    await box.put('CURRENT_HABIT_LIST', currentHabits);
  }

  static Future<void> deleteHabit(String habitName) async {
    final box = Hive.box(_habitsBox);
    List<String> currentHabits = getHabits();
    currentHabits.remove(habitName);
    await box.put('CURRENT_HABIT_LIST', currentHabits);

    // Clean up completion data for deleted habit
    Hive.box(_completionsBox).delete(habitName);
  }

  // -----------------------------------------------------------------------------
  // 🛠 Helpers
  // -----------------------------------------------------------------------------

  static bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  // Format: YYYY-MM-DD (Ensures unique key per day)
  static String _formatDateKey(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  static DateTime? _parseDateKey(String key) {
    try {
      return DateTime.parse(key);
    } catch (e) {
      return null;
    }
  }

  // -----------------------------------------------------------------------------
  // 📊 Stats & Analytics Functions
  // -----------------------------------------------------------------------------

  /// Get completion percentage for a specific date (0.0 to 1.0)
  static double getCompletionPercentageForDate(DateTime date) {
    final habits = getHabits();
    if (habits.isEmpty) return 0.0;

    final dateKey = _formatDateKey(date);
    final historyBox = Hive.box(_historyBox);
    final completedCount = historyBox.get(dateKey, defaultValue: 0);

    return completedCount / habits.length;
  }

  /// Get current streak (consecutive days with >0 completion)
  static int getCurrentStreak() {
    final today = DateTime.now();
    int streak = 0;

    for (int i = 0; i < 365; i++) {
      final date = today.subtract(Duration(days: i));
      if (getCompletionPercentageForDate(date) > 0) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Get best streak in history
  static int getBestStreak() {
    final historyBox = Hive.box(_historyBox);
    final habits = getHabits();
    if (habits.isEmpty) return 0;

    int currentStreak = 0;
    int bestStreak = 0;
    DateTime? lastDate;

    // Get all dates sorted
    final dates = historyBox.keys
        .map((key) => DateTime.tryParse(key.toString()))
        .where((date) => date != null)
        .cast<DateTime>()
        .toList()
      ..sort();

    for (var date in dates) {
      final count = historyBox.get(_formatDateKey(date), defaultValue: 0);

      if (count > 0) {
        if (lastDate == null || date.difference(lastDate).inDays == 1) {
          currentStreak++;
          bestStreak = currentStreak > bestStreak ? currentStreak : bestStreak;
        } else {
          currentStreak = 1;
        }
        lastDate = date;
      } else {
        currentStreak = 0;
      }
    }

    return bestStreak;
  }

  /// Get success rate for a month (0-100)
  static int getMonthSuccessRate(DateTime month) {
    final habits = getHabits();
    if (habits.isEmpty) return 0;

    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final today = DateTime.now();

    int totalDays = 0;
    int completedDays = 0;

    for (var date = firstDay;
        !date.isAfter(lastDay) && !date.isAfter(today);
        date = date.add(const Duration(days: 1))) {
      totalDays++;
      if (getCompletionPercentageForDate(date) > 0) {
        completedDays++;
      }
    }

    return totalDays > 0 ? ((completedDays / totalDays) * 100).round() : 0;
  }
}
