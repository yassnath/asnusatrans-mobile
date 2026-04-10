class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.displayName,
    required this.isCustomer,
    this.userId,
  });

  final String token;
  final String role;
  final String displayName;
  final bool isCustomer;
  final String? userId;

  String get normalizedRole => role.trim().toLowerCase();
  bool get isPengurus => normalizedRole == 'pengurus';
  bool get isOwner => normalizedRole == 'owner';
  bool get isAdmin => normalizedRole == 'admin';
  bool get isAdminOrOwner => isAdmin || isOwner;
  bool get isBackofficeUser => isAdminOrOwner || isPengurus;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'role': role,
      'displayName': displayName,
      'isCustomer': isCustomer,
      'userId': userId,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: (json['token'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      isCustomer: json['isCustomer'] == true,
      userId: (json['userId'] ?? '').toString().trim().isEmpty
          ? null
          : (json['userId'] ?? '').toString().trim(),
    );
  }
}
