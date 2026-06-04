import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      return await _auth.signInWithPopup(googleProvider);
    } else {
      final clientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? clientId : null,
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
    }
    await _auth.signOut();
  }
}
