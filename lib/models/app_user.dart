enum UserRole {
  tenant,
  dalali,
  landlord,
  admin;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => UserRole.tenant,
    );
  }

  String get displayName {
    switch (this) {
      case UserRole.tenant:
        return 'Tenant';
      case UserRole.dalali:
        return 'Dalali';
      case UserRole.landlord:
        return 'Landlord';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.authId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.verified,
    required this.createdAt,
    this.phone,
    this.avatarUrl,
  });

  final String id;
  final String authId;
  final String fullName;
  final String email;
  final String? phone;
  final UserRole role;
  final String? avatarUrl;
  final bool verified;
  final DateTime createdAt;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'tenant'),
      avatarUrl: json['avatar_url'] as String?,
      verified: json['verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'auth_id': authId,
      'full_name': fullName,
      'email': email,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      'role': role.name,
    };
  }
}
