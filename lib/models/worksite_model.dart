class WorksiteModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // Radio en metros para geofence

  WorksiteModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory WorksiteModel.fromFirestore(Map<String, dynamic> data, String id) {
    return WorksiteModel(
      id: id,
      name: data['name'] ?? '',
      latitude: data['latitude']?.toDouble() ?? 0.0,
      longitude: data['longitude']?.toDouble() ?? 0.0,
      radius: data['radius']?.toDouble() ?? 100.0, // Default 100m
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
    };
  }
}