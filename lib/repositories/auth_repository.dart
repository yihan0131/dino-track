import 'package:firebase_auth/firebase_auth.dart' as auth;

class AuthRepository {
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  String? getCurrentUserId() => _auth.currentUser?.uid;

  bool isUserLoggedIn() => _auth.currentUser != null;
}
