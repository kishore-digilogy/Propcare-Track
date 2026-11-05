class Employee {
  const Employee({
    required this.id,
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.joinedAt,
    required this.avatarSeed,
  });

  final String id;
  final String code;
  final String name;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final String joinedAt;
  final String avatarSeed;

  String get firstName => name.split(' ').first;

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'email': email,
        'phone': phone,
        'department': department,
        'designation': designation,
        'joined_at': joinedAt,
        'avatar_seed': avatarSeed,
      };

  factory Employee.fromMap(Map<String, Object?> map) => Employee(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        email: map['email'] as String,
        phone: (map['phone'] as String?) ?? '',
        department: (map['department'] as String?) ?? '',
        designation: (map['designation'] as String?) ?? '',
        joinedAt: (map['joined_at'] as String?) ?? '',
        avatarSeed: (map['avatar_seed'] as String?) ?? 'mint',
      );
}
