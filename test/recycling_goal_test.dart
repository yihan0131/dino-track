import 'package:flutter_test/flutter_test.dart';

import 'package:dino_tracker/models/recycling_goal.dart';

RecyclingGoal makeGoal({
  DateTime? start,
  DateTime? end,
  String frequency = 'daily',
  List<bool>? selectedDays,
  double targetAmount = 1,
  int progress = 0,
  List<DateTime> checkInDates = const [],
  Map<String, int> dailyProgress = const {},
}) {
  return RecyclingGoal(
    id: 'g1',
    userId: 'u1',
    title: 'Test goal',
    description: '',
    startDate: start ?? DateTime(2026, 11, 14),
    endDate: end ?? DateTime(2026, 11, 21),
    targetAmount: targetAmount,
    unit: 'kg',
    frequency: frequency,
    selectedDays: selectedDays ?? List.filled(7, false),
    progress: progress,
    checkInDates: checkInDates,
    dailyProgress: dailyProgress,
  );
}

void main() {
  group('expected completions', () {
    test('daily counts every day, both ends included', () {
      // 14–21 Nov = 8 days, matching the "Total Goal: 8.0 kg" shown in the app
      final goal = makeGoal();
      expect(goal.getTotalExpectedCompletions(), 8);
      expect(goal.getTotalExpectedAmount(), 8.0);
    });

    test('weekly rounds up to whole weeks', () {
      final goal = makeGoal(frequency: 'weekly');
      expect(goal.getTotalExpectedCompletions(), 2); // 8 days -> 2 weeks
    });

    test('custom uses the number of selected weekdays', () {
      final days = List.filled(7, false);
      days[1] = true; // Monday
      days[3] = true; // Wednesday
      final goal = makeGoal(
        start: DateTime(2026, 11, 1),
        end: DateTime(2026, 11, 14), // 14 days = 2 weeks
        frequency: 'custom',
        selectedDays: days,
      );
      expect(goal.getTotalExpectedCompletions(), 4);
    });

    test('unknown frequency expects nothing', () {
      expect(makeGoal(frequency: 'yearly').getTotalExpectedCompletions(), 0);
    });
  });

  group('completion rate', () {
    test('is progress over the expected amount', () {
      expect(makeGoal(progress: 2).getCompletionRate(), closeTo(0.25, 1e-9));
    });

    test('never goes above 100%', () {
      expect(makeGoal(progress: 50).getCompletionRate(), 1.0);
    });

    test('is 0 when nothing is expected', () {
      expect(makeGoal(targetAmount: 0, progress: 3).getCompletionRate(), 0.0);
    });
  });

  group('shouldCompleteOnDate', () {
    test('is false outside the goal period', () {
      final goal = makeGoal();
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 13)), isFalse);
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 22)), isFalse);
    });

    test('daily is true on every day in range, including the last', () {
      final goal = makeGoal();
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 14)), isTrue);
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 21, 23, 59)), isTrue);
    });

    test('weekly only on the start weekday', () {
      // 14 Nov 2026 is a Saturday
      final goal = makeGoal(frequency: 'weekly');
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 21)), isTrue);
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 17)), isFalse);
    });

    test('custom index 0 is Sunday', () {
      final days = List.filled(7, false);
      days[0] = true; // Sunday
      final goal = makeGoal(frequency: 'custom', selectedDays: days);
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 15)), isTrue); // Sunday
      expect(goal.shouldCompleteOnDate(DateTime(2026, 11, 16)), isFalse); // Monday
    });
  });

  group('check-ins', () {
    test('wasCompletedOnDate ignores the time of day', () {
      final goal = makeGoal(checkInDates: [DateTime(2026, 11, 14, 9, 30)]);
      expect(goal.wasCompletedOnDate(DateTime(2026, 11, 14, 22)), isTrue);
      expect(goal.wasCompletedOnDate(DateTime(2026, 11, 15)), isFalse);
    });

    test('getProgressForDate reads the zero-padded day key', () {
      final goal = makeGoal(dailyProgress: {'2026-11-05': 3});
      expect(goal.getProgressForDate(DateTime(2026, 11, 5)), 3);
      expect(goal.getProgressForDate(DateTime(2026, 11, 6)), 0);
    });

    test('completion status map only covers days that need a check-in', () {
      final days = List.filled(7, false);
      days[0] = true; // Sundays only
      final goal = makeGoal(
        frequency: 'custom',
        selectedDays: days,
        checkInDates: [DateTime(2026, 11, 15)],
      );
      final status = goal.getCompletionStatusForRange(
          DateTime(2026, 11, 14), DateTime(2026, 11, 21));
      expect(status, {DateTime(2026, 11, 15): true});
    });
  });

  group('points eligibility', () {
    test('needs at least 7 days', () {
      expect(makeGoal(end: DateTime(2026, 11, 19)).isEligibleForPoints(), isFalse);
      expect(makeGoal().isEligibleForPoints(), isTrue);
    });

    test('needs at least 3 expected completions', () {
      // weekly over 8 days = 2 completions -> not eligible
      expect(makeGoal(frequency: 'weekly').isEligibleForPoints(), isFalse);
    });
  });

  group('map round trip', () {
    test('toMap then fromMap keeps the data', () {
      final original = makeGoal(
        progress: 2,
        checkInDates: [DateTime(2026, 11, 14)],
        dailyProgress: {'2026-11-14': 1},
      );
      final copy = RecyclingGoal.fromMap({...original.toMap(), 'id': 'g1'});

      expect(copy.id, 'g1');
      expect(copy.title, original.title);
      expect(copy.startDate, original.startDate);
      expect(copy.endDate, original.endDate);
      expect(copy.targetAmount, 1.0);
      expect(copy.progress, 2);
      expect(copy.checkInDates, original.checkInDates);
      expect(copy.dailyProgress, original.dailyProgress);
      expect(copy.reminderTime, isNull);
    });

    test('fromMap fills defaults for missing fields', () {
      final goal = RecyclingGoal.fromMap({});
      expect(goal.title, '');
      expect(goal.targetAmount, 0.0);
      expect(goal.selectedDays, List.filled(7, false));
      expect(goal.checkInDates, isEmpty);
    });
  });
}
