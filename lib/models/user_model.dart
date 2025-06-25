// lib/models/user_model.dart - FIXED FOR LOCAL STORAGE
// Removed all Firebase dependencies

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? address;
  final String role; // 'user' or 'admin'
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.address,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // FIXED: Handle dates without Firebase Timestamp
    DateTime createdAt = DateTime.now();
    if (json['createdAt'] != null) {
      final createdAtValue = json['createdAt'];
      if (createdAtValue is String) {
        try {
          createdAt = DateTime.parse(createdAtValue);
        } catch (e) {
          print('Error parsing createdAt: $e');
        }
      } else if (createdAtValue is int) {
        createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtValue);
      } else {
        // Handle Timestamp if it somehow exists
        try {
          createdAt = (createdAtValue as dynamic).toDate();
        } catch (e) {
          print('Error parsing createdAt timestamp: $e');
        }
      }
    }

    DateTime updatedAt = DateTime.now();
    if (json['updatedAt'] != null) {
      final updatedAtValue = json['updatedAt'];
      if (updatedAtValue is String) {
        try {
          updatedAt = DateTime.parse(updatedAtValue);
        } catch (e) {
          print('Error parsing updatedAt: $e');
        }
      } else if (updatedAtValue is int) {
        updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtValue);
      } else {
        // Handle Timestamp if it somehow exists
        try {
          updatedAt = (updatedAtValue as dynamic).toDate();
        } catch (e) {
          print('Error parsing updatedAt timestamp: $e');
        }
      }
    }

    return UserModel(
      uid: json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      photoUrl: json['photoUrl']?.toString(),
      address: json['address']?.toString(),
      role: json['role']?.toString() ?? 'user',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // FIXED: Store dates as ISO strings
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'address': address,
      'role': role,
      'createdAt': createdAt.toIso8601String(), // Store as ISO string
      'updatedAt': updatedAt.toIso8601String(), // Store as ISO string
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? email,
    String? photoUrl,
    String? address,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}