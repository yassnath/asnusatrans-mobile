class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.displayName,
    required this.isCustomer,
  });

  final String token;
  final String role;
  final String displayName;
  final bool isCustomer;

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'role': role,
      'displayName': displayName,
      'isCustomer': isCustomer,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: (json['token'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      displayName: (json['displayName'] ?? '').toString(),
      isCustomer: json['isCustomer'] == true,
    );
  }
}
