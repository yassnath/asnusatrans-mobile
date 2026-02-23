class SignUpPayload {
  const SignUpPayload({
    required this.name,
    required this.username,
    required this.email,
    required this.phone,
    required this.gender,
    required this.birthDate,
    required this.address,
    required this.city,
    required this.company,
    required this.password,
    required this.confirmPassword,
  });

  final String name;
  final String username;
  final String email;
  final String phone;
  final String gender;
  final String birthDate;
  final String address;
  final String city;
  final String company;
  final String password;
  final String confirmPassword;

  Map<String, dynamic> toApiBody() {
    return {
      'name': name.trim(),
      'username': username.trim(),
      'email': email.trim().toLowerCase(),
      'phone': phone.trim(),
      'gender': gender.trim(),
      'birth_date': birthDate.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'company': company.trim(),
      'password': password,
    };
  }

  Map<String, dynamic> toSupabaseMetadata() {
    return {
      'name': name.trim(),
      'username': username.trim(),
      'phone': phone.trim(),
      'gender': gender.trim(),
      'birth_date': birthDate.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'company': company.trim(),
      'role': 'customer',
    };
  }

  Map<String, dynamic> toProfileRow(String userId) {
    return {
      'id': userId,
      'email': email.trim().toLowerCase(),
      'name': name.trim(),
      'username': username.trim(),
      'phone': phone.trim(),
      'gender': gender.trim(),
      'birth_date': birthDate.trim(),
      'address': address.trim(),
      'city': city.trim(),
      'company': company.trim(),
      'role': 'customer',
    };
  }
}
