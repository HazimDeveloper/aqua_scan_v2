// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
  try {
    // For development: automatically grant admin role for specific credentials
    if (email == 'admin@gmail.com' && password == 'Admin123') {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      // Check if the user exists in Firestore and update role if needed
      final docRef = _firestore.collection('users').doc(userCredential.user!.uid);
      final docSnapshot = await docRef.get();
      
      if (docSnapshot.exists) {
        // Update role to admin if not already
        if (docSnapshot.data()?['role'] != 'admin') {
          await docRef.update({'role': 'admin'});
        }
      } else {
        // Create user doc with admin role if it doesn't exist
        final now = DateTime.now();
        await docRef.set({
          'uid': userCredential.user!.uid,
          'name': 'Admin User',
          'email': email,
          'photoUrl': null,
          'address': null,
          'role': 'admin',
          'createdAt': now,
          'updatedAt': now,
        });
      }
      
      return userCredential;
    }
    
    // Regular login for other credentials
    return await _auth.signInWithEmailAndPassword(
      email: email, 
      password: password,
    );
  } catch (e) {
    throw Exception('Failed to sign in: $e');
  }
}

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
    String name, 
    String email, 
    String password,
    {String role = 'user'} 
  ) async {
    try {
      // Create user in Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      // Create user document in Firestore
      if (userCredential.user != null) {
        await _createUserDocument(
          userCredential.user!.uid, 
          name, 
          email, 
          role,
        );
      }
      
      return userCredential;
    } catch (e) {
      throw Exception('Failed to register: $e');
    }
  }

  // Create user document in Firestore
  Future<void> _createUserDocument(
    String uid, 
    String name, 
    String email, 
    String role,
  ) async {
    final now = DateTime.now();
    
    final userData = {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': null,
      'address': null,
      'role': role,
      'createdAt': now,
      'updatedAt': now,
    };
    
    await _firestore.collection('users').doc(uid).set(userData);
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
  
  // Get user data from Firestore
  Future<UserModel> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data()!);
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }
  
  // Update user profile
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      data['updatedAt'] = DateTime.now();
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }
  
  // Check if user is admin
  Future<bool> isUserAdmin(String uid) async {
    try {
      final userData = await getUserData(uid);
      return userData.role == 'admin';
    } catch (e) {
      return false;
    }
  }
}



