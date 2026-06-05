import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Emailarekin ERREGISTRATU
  Future<User?> erabiltzaileaErregistratu(String email, String password) async {
    try {
      UserCredential kredentziala = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return kredentziala.user;
    } catch (e) {
      print('Errorea erregistratzean: $e');
      return null;
    }
  }

  // Emailarekin SAIOA HASI
  Future<User?> saioaHasi(String email, String password) async {
    try {
      UserCredential kredentziala = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return kredentziala.user;
    } catch (e) {
      print('Errorea saioa hastean: $e');
      return null;
    }
  }
}