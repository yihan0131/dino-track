import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dino_tracker/config/recycling_config.dart';
import 'package:dino_tracker/models/user_model.dart';
import 'package:dino_tracker/repositories/challenge_repository.dart';

void main() {
  group('User model', () {
    test('new users start as an Egg with 0 points', () {
      final user = User(id: 'u1', username: 'yihan', email: 'a@b.c');
      expect(user.ecoPoints, 0);
      expect(user.dinoStage, 'Egg');
      expect(user.dinoName, 'Eco Dino');
      expect(user.isAdmin, isFalse);
    });

    test('toMap then fromMap keeps the data', () {
      final user = User(
        id: 'u1',
        username: 'yihan',
        email: 'a@b.c',
        ecoPoints: 500,
        dinoName: 'dino',
        dinoStage: 'Eco Dino Warrior',
        processedReports: ['r1'],
        isAdmin: true,
      );
      final copy = User.fromMap(user.toMap());
      expect(copy.toMap(), user.toMap());
    });

    test('fromMap fills defaults for missing fields', () {
      final user = User.fromMap({});
      expect(user.username, '');
      expect(user.dinoStage, 'Egg');
      expect(user.processedReports, isEmpty);
    });

    test('copyWith only changes the given fields', () {
      final user = User(id: 'u1', username: 'yihan', email: 'a@b.c');
      final updated = user.copyWith(ecoPoints: 20);
      expect(updated.ecoPoints, 20);
      expect(updated.username, 'yihan');
      expect(user.ecoPoints, 0);
    });
  });

  group('RecyclingConfig', () {
    test('every material has its own units', () {
      for (final material in RecyclingConfig.materialTypes) {
        expect(RecyclingConfig.unitsByMaterial.containsKey(material), isTrue,
            reason: '$material has no units');
      }
    });

    test('unknown material falls back to generic units', () {
      expect(RecyclingConfig.getUnitsForMaterial('Wood'), ['pieces', 'kg', 'g']);
    });

    test('colors ignore case and default to grey', () {
      expect(RecyclingConfig.getColorForMaterial('PLASTIC'), Colors.blue);
      expect(RecyclingConfig.getColorForMaterial('Wood'), Colors.grey);
    });
  });

  group('System challenge monthly cycle', () {
    test('runs from the 1st of this month to the 1st of next month', () {
      final cycle = ChallengeRepository.monthlyCycle(DateTime(2026, 11, 14, 15));
      expect(cycle.start, DateTime(2026, 11, 1));
      expect(cycle.end, DateTime(2026, 12, 1));
    });

    test('December rolls over into January', () {
      final cycle = ChallengeRepository.monthlyCycle(DateTime(2026, 12, 31));
      expect(cycle.start, DateTime(2026, 12, 1));
      expect(cycle.end, DateTime(2027, 1, 1));
    });
  });
}
