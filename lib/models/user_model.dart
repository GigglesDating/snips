class UserModel {
  final String profileId;
  final String name;
  final String profileImage;

  UserModel({
    required this.profileId,
    required this.name,
    required this.profileImage,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      profileId: json['profile_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      profileImage: json['profile_image']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'name': name,
      'profile_image': profileImage,
    };
  }
}
