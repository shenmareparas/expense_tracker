class ProfileModel {
  final String id;
  final String email;
  final String? name;

  ProfileModel({
    required this.id,
    required this.email,
    this.name,
  });

  String get displayName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    return email.split('@').first;
  }

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
    };
  }

  @override
  bool operator ==(Object other) => other is ProfileModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
