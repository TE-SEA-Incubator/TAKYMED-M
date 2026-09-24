
class User {
  final int id;
  final String? email;
  final String? phone;
  final String type;
  final String name;

  /// Code pays ISO-2 (ex. "CM") : détermine le fuseau horaire des rappels.
  final String? country;

  /// Fuseau horaire IANA effectif (ex. "Africa/Douala"), fourni par le serveur.
  final String? timezone;

  User({
    required this.id,
    this.email,
    this.phone,
    required this.type,
    required this.name,
    this.country,
    this.timezone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final rawType = (json['type'] ?? 'standard').toString().toLowerCase();
    final type = switch (rawType) {
      'professionnel' || 'professional' || 'pharmacist' || 'pharmacien' => 'professional',
      'administrateur' || 'admin' => 'admin',
      'commercial' => 'commercial',
      _ => 'standard',
    };
    return User(
      id: id,
      email: json['email'],
      phone: json['phone'],
      type: type,
      name: json['name'] ?? 'Utilisateur',
      country: json['country']?.toString(),
      timezone: json['timezone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'type': type,
      'name': name,
      'country': country,
      'timezone': timezone,
    };
  }

  User copyWith({
    String? email,
    String? phone,
    String? name,
    String? country,
    String? timezone,
  }) {
    return User(
      id: id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      type: type,
      name: name ?? this.name,
      country: country ?? this.country,
      timezone: timezone ?? this.timezone,
    );
  }
}
