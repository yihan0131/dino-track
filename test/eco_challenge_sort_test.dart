import 'package:flutter_test/flutter_test.dart';

import 'package:dino_tracker/models/eco_challenge.dart';

EcoChallenge challenge(String title, DateTime start, DateTime end) {
  return EcoChallenge(
    id: title,
    title: title,
    description: '',
    durationDays: end.difference(start).inDays,
    imageUrl: '',
    startDate: start,
    endDate: end,
  );
}

void main() {
  final now = DateTime(2026, 11, 14, 12);

  final endedLongAgo = challenge('ended May', DateTime(2026, 5, 16), DateTime(2026, 5, 30));
  final endedRecently = challenge('ended Jul', DateTime(2026, 6, 20), DateTime(2026, 7, 20));
  final activeLong = challenge('active to Dec 31', DateTime(2026, 11, 1), DateTime(2026, 12, 31));
  final activeShort = challenge('active to Dec 1', DateTime(2026, 11, 1), DateTime(2026, 12, 1));
  final upcomingLater = challenge('starts Jan', DateTime(2027, 1, 1), DateTime(2027, 2, 1));
  final upcomingSoon = challenge('starts Dec', DateTime(2026, 12, 1), DateTime(2027, 1, 1));

  test('displayRank follows the badge rules', () {
    expect(activeShort.displayRank(now), 0);
    expect(upcomingSoon.displayRank(now), 1);
    expect(endedRecently.displayRank(now), 2);
  });

  test('active, then upcoming, then ended', () {
    final sorted = EcoChallenge.sortedForDisplay(
      [endedLongAgo, upcomingLater, activeLong, endedRecently, upcomingSoon, activeShort],
      now,
    );
    expect(sorted.map((c) => c.title), [
      'active to Dec 1', // ends soonest
      'active to Dec 31',
      'starts Dec', // starts soonest
      'starts Jan',
      'ended Jul', // most recently ended
      'ended May',
    ]);
  });

  test('does not change the original list', () {
    final original = [endedLongAgo, activeShort];
    EcoChallenge.sortedForDisplay(original, now);
    expect(original.first, endedLongAgo);
  });
}
