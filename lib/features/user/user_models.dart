// phone is [String] in GraphQL (array) — take first element safely
String? _firstPhone(dynamic value) {
  if (value == null) return null;
  if (value is List) return value.isEmpty ? null : value.first?.toString();
  final s = value.toString();
  return s.isEmpty ? null : s;
}

class AppUser {
  final String id;
  final String firstname;
  final String lastname;
  final String email;
  final String companyId;
  final String companyName;
  final String? img;
  final String? phone;
  final String? role;
  final List<String> access;
  final String? timezone;
  final bool multiCompany;

  const AppUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.companyId,
    required this.companyName,
    this.img,
    this.phone,
    this.role,
    this.access = const [],
    this.timezone,
    this.multiCompany = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String? ?? '',
        firstname: json['firstname'] as String? ?? '',
        lastname: json['lastname'] as String? ?? '',
        email: json['email'] as String? ?? '',
        companyId: json['company_id'] as String? ?? '',
        companyName: json['company_name'] as String? ?? '',
        img: json['img'] as String?,
        phone: _firstPhone(json['phone']),
        role: json['role'] as String?,
        access: (json['access'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
            [],
        timezone: json['timezone'] as String?,
        multiCompany: json['multi_company'] as bool? ?? false,
      );

  String get fullName => '$firstname $lastname'.trim();

  String get initials {
    final f = firstname.isNotEmpty ? firstname[0].toUpperCase() : '';
    final l = lastname.isNotEmpty ? lastname[0].toUpperCase() : '';
    return '$f$l';
  }

  bool get isAdmin => role == 'admin' || access.contains('admin');
}

// ── Company user (for DM / Create Room user selection) ───────────────────────

class CompanyUser {
  final String id;
  final String firstname;
  final String lastname;
  final String? email;
  final String? img;

  const CompanyUser({
    required this.id,
    required this.firstname,
    required this.lastname,
    this.email,
    this.img,
  });

  factory CompanyUser.fromJson(Map<String, dynamic> json) => CompanyUser(
        id: json['id']?.toString() ?? '',
        firstname: json['firstname']?.toString() ?? '',
        lastname: json['lastname']?.toString() ?? '',
        email: json['email']?.toString(),
        img: json['img']?.toString(),
      );

  String get fullName => '$firstname $lastname'.trim();

  String get initials {
    final f = firstname.isNotEmpty ? firstname[0].toUpperCase() : '';
    final l = lastname.isNotEmpty ? lastname[0].toUpperCase() : '';
    final combined = '$f$l';
    return combined.isNotEmpty ? combined : '?';
  }

  bool matches(String query) {
    final q = query.toLowerCase();
    return fullName.toLowerCase().contains(q) ||
        (email?.toLowerCase().contains(q) ?? false);
  }
}
