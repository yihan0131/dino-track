import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dino_tracker/repositories/challenge_repository.dart';
import 'package:dino_tracker/service/cloudinary_service.dart';

/// Records what the admin panel asked Cloudinary to do, without any network.
class FakeCloudinaryService implements CloudinaryService {
  final List<String> calls = [];

  @override
  Future<void> approveReportedImage(String imageUrl) async =>
      calls.add('approve $imageUrl');

  @override
  Future<void> rejectReportedImage(String imageUrl) async =>
      calls.add('reject $imageUrl');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const photoUrl = 'https://example.com/photo.jpg';
const userId = 'user-a';
const userChallengeId = 'uc-1';

late FakeFirebaseFirestore db;
late FakeCloudinaryService cloudinary;
late ChallengeRepository repo;

/// A user with [points], a check-in photo in a challenge, and one pending
/// report against that photo (what reportCheckInPhoto leaves behind).
Future<String> seed({bool systemChallenge = true, int points = 100}) async {
  await db.collection('users').doc(userId).set({
    'id': userId,
    'ecoPoints': points,
    'dinoStage': 'Baby Dino',
    'processedReports': <String>[],
  });
  await db.collection('eco_challenges').doc('ch-1').set({
    'title': 'Recycle at Home',
    'createdBy': systemChallenge ? 'system' : 'someone',
  });
  await db.collection('user_challenges').doc(userChallengeId).set({
    'userId': userId,
    'challengeId': 'ch-1',
    'checkInPhotos': [
      {'photoUrl': photoUrl, 'reported': true, 'approved': false},
      {'photoUrl': 'https://example.com/other.jpg', 'reported': false},
    ],
  });
  final report = await db.collection('photo_reports').add({
    'userChallengeId': userChallengeId,
    'photoUrl': photoUrl,
    'status': 'pending',
    'processed': false,
    'userId': userId,
    'challengeId': 'ch-1',
    'reportedBy': 'user-b',
  });
  return report.id;
}

Future<int> points() async =>
    (await db.collection('users').doc(userId).get()).data()!['ecoPoints'] as int;

Future<Map<String, dynamic>> photo() async {
  final doc = await db.collection('user_challenges').doc(userChallengeId).get();
  final photos = List<Map<String, dynamic>>.from(doc.data()!['checkInPhotos']);
  return photos.firstWhere((p) => p['photoUrl'] == photoUrl);
}

void main() {
  setUp(() {
    db = FakeFirebaseFirestore();
    cloudinary = FakeCloudinaryService();
    repo = ChallengeRepository(firestore: db, cloudinaryService: cloudinary);
  });

  test('pending reports show up for the admin panel', () async {
    final reportId = await seed();
    final pending = await repo.getPendingReports();
    expect(pending, hasLength(1));
    expect(pending.single['reportId'], reportId);
    expect(pending.single['reportedBy'], 'user-b');
  });

  group('approve', () {
    test('clears the report and keeps the photo visible', () async {
      final reportId = await seed();
      await repo.approveReportedPhoto(photoUrl, userChallengeId);

      final p = await photo();
      expect(p['reported'], isFalse);
      expect(p['approved'], isTrue);
      expect(p['visible'], isTrue);

      final report = await db.collection('photo_reports').doc(reportId).get();
      expect(report['status'], 'approved');
      expect(report['processed'], isTrue);

      expect(await repo.getPendingReports(), isEmpty);
      expect(cloudinary.calls, ['approve $photoUrl']);
    });

    test('does not change points', () async {
      await seed(points: 100);
      await repo.approveReportedPhoto(photoUrl, userChallengeId);
      expect(await points(), 100);
    });

    test('leaves other photos alone', () async {
      await seed();
      await repo.approveReportedPhoto(photoUrl, userChallengeId);
      final doc = await db.collection('user_challenges').doc(userChallengeId).get();
      final other = (doc.data()!['checkInPhotos'] as List)[1] as Map;
      expect(other.containsKey('approved'), isFalse);
    });
  });

  group('reject', () {
    test('hides the photo and settles the report', () async {
      final reportId = await seed();
      await repo.rejectReportedPhoto(photoUrl, userChallengeId);

      final p = await photo();
      expect(p['rejected'], isTrue);
      expect(p['visible'], isFalse);

      final report = await db.collection('photo_reports').doc(reportId).get();
      expect(report['status'], 'rejected');
      expect(report['processed'], isTrue);
      expect(await repo.getPendingReports(), isEmpty);
      expect(cloudinary.calls, ['reject $photoUrl']);
    });

    test('takes 2 points on a system challenge and records the report',
        () async {
      final reportId = await seed(points: 100);
      await repo.rejectReportedPhoto(photoUrl, userChallengeId);

      expect(await points(), 98);
      final user = await db.collection('users').doc(userId).get();
      expect(user['processedReports'], [reportId]);
    });

    test('rejecting twice only takes 2 points once', () async {
      await seed(points: 100);
      await repo.rejectReportedPhoto(photoUrl, userChallengeId);
      await repo.rejectReportedPhoto(photoUrl, userChallengeId);
      expect(await points(), 98);
    });

    test('a report already approved costs nothing if rejected later',
        () async {
      await seed(points: 100);
      await repo.approveReportedPhoto(photoUrl, userChallengeId);
      await repo.rejectReportedPhoto(photoUrl, userChallengeId);
      expect(await points(), 100);
    });

    test('a user-made challenge never costs points', () async {
      await seed(systemChallenge: false, points: 100);
      await repo.rejectReportedPhoto(photoUrl, userChallengeId);
      expect(await points(), 100);
      expect((await photo())['rejected'], isTrue);
    });
  });
}
