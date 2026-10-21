import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Singleton service for Firebase Auth and Firestore user/profile operations.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // AUTH — GOOGLE
  // ─────────────────────────────────────────────

  Future<UserCredential> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    final GoogleSignInAuthentication googleAuth =
        await googleUser!.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await auth.signInWithCredential(credential);
  }

  // ─────────────────────────────────────────────
  // AUTH — APPLE (iOS / macOS)
  // ─────────────────────────────────────────────

  /// Generates a cryptographically random nonce string.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  /// Returns the SHA-256 hash of [input] as a hex string.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Decodes a JWT payload for diagnostic logging only.
  Map<String, dynamic> _decodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return {'error': 'Not a valid JWT'};
      // Base64 decode with padding
      String payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      return Map<String, dynamic>.from(
        (jsonDecode(decoded) as Map<String, dynamic>),
      );
    } catch (e) {
      return {'decodeError': e.toString()};
    }
  }

  Future<UserCredential> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Guard: identityToken can be null if Apple's response was incomplete
      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw Exception(
          'Apple Sign-In failed: identityToken was null. '
          'Please try again.',
        );
      }

      // Pass authorizationCode as accessToken so Firebase can exchange it
      // with Apple's token endpoint when Team ID/Key ID/Private Key are set.
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await auth.signInWithCredential(oauthCredential);

      // Apple only sends the display name on the very first sign-in.
      final fullName = appleCredential.givenName != null
          ? '${appleCredential.givenName} ${appleCredential.familyName ?? ''}'
              .trim()
          : null;
      if (fullName != null && fullName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(fullName);
      }

      return userCredential;
    } catch (e, stack) {
      // ignore: avoid_print
      print('🍎 Apple Sign-In ERROR: ${e.runtimeType}: $e');
      // ignore: avoid_print
      print('Stack: $stack');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // AUTH — SIGN OUT
  // ─────────────────────────────────────────────

  Future<void> signOut() async {
    await auth.signOut();
    await GoogleSignIn().signOut();
  }

  // ─────────────────────────────────────────────
  // ACCOUNT DELETION  (App Store requirement)
  // ─────────────────────────────────────────────

  /// Deletes all user data from Firestore then deletes the Firebase Auth
  /// account. Throws [FirebaseAuthException] with code 'requires-recent-login'
  /// if the user needs to re-authenticate first.
  Future<void> deleteAccount() async {
    final user = auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    // 1. Delete Firestore user document
    await firestore.collection('users').doc(uid).delete();

    // 2. Delete any subcollections you may have (e.g. reminders, prescriptions)
    for (final sub in ['reminders', 'prescriptions', 'health_logs']) {
      final snapshot =
          await firestore.collection('users').doc(uid).collection(sub).get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    // 3. Sign out of Google if applicable
    await GoogleSignIn().signOut();

    // 4. Delete the Firebase Auth account
    await user.delete();
  }

  // ─────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────

  Future<void> saveUserProfile(
      String uid, Map<String, dynamic> data) async {
    await firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }
}

