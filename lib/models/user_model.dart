class UserModel {
  final String uid;
  final String role; // 'trabajador' or 'admin'
  final String? email; // Null for workers
  final String? dni; // Null for admins
  final String fullName;
  final String? assignedWorksiteId;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.role,
    this.email,
    this.dni,
    required this.fullName,
    this.assignedWorksiteId,
    this.isActive = true,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      role: data['role'] ?? '',
      email: data['email'],
      dni: data['dni'],
      fullName: data['fullName'] ?? '',
      assignedWorksiteId: data['assignedWorksiteId'],
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      'email': email,
      'dni': dni,
      'fullName': fullName,
      'assignedWorksiteId': assignedWorksiteId,
      'isActive': isActive,
    };
  }

  bool get isWorker => role == 'trabajador';
  bool get isAdmin => role == 'admin';
}
