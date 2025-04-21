class UserDetails {
  final String id;
  final String? displayName;
  final String? email;
  final String? photoUrl;

  UserDetails({
    required this.id,
    this.displayName,
    this.email,
    this.photoUrl,
  });

  factory UserDetails.fromMap(Map<String, dynamic> map) {
    return UserDetails(
      id: map['id'] ?? '',
      displayName: map['display_name'] ?? map['displayName'],
      email: map['email'],
      photoUrl: map['photo_url'] ?? map['photoUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'email': email,
      'photo_url': photoUrl,
    };
  }

  // This handles the special case where Firebase might return a List<Object?> 
  static UserDetails? fromFirebaseResult(dynamic data) {
    if (data == null) return null;
    
    try {
      if (data is Map<String, dynamic>) {
        return UserDetails.fromMap(data);
      }
      
      // Handle the case where data is a List<Object?>
      if (data is List && data.isNotEmpty) {
        final item = data.first;
        if (item is Map<String, dynamic>) {
          return UserDetails.fromMap(item);
        }
      }
      
      // Handle case where Firebase returns User object
      if (data is Map && data.containsKey('uid')) {
        return UserDetails(
          id: data['uid'] as String,
          displayName: data['displayName'] as String?,
          email: data['email'] as String?,
          photoUrl: data['photoUrl'] as String?,
        );
      }
      
      // Last resort fallback - create a default user
      print("Converting unknown data format to UserDetails: $data");
      return UserDetails(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        displayName: "Anonymous User",
        email: null,
        photoUrl: null,
      );
    } catch (e) {
      print("Error converting data to UserDetails: $e");
      return UserDetails(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        displayName: "Error User",
        email: null,
        photoUrl: null,
      );
    }
  }
} 