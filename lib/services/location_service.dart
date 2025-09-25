import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Verificar y solicitar permisos de ubicación
  Future<bool> requestLocationPermission() async {
    try {
      // Verificar si el servicio de ubicación está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      // Verificar permisos actuales
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente. Ve a Configuración para habilitarlos.');
      }

      return true;
    } catch (e) {
      print('Error requesting location permission: $e');
      return false;
    }
  }

  /// Obtener ubicación actual del dispositivo
  Future<Position?> getCurrentLocation() async {
    try {
      // Verificar permisos primero
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        throw Exception('Sin permisos de ubicación');
      }

      // Obtener posición con timeout y configuración de precisión
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Timeout al obtener ubicación. Verifica tu GPS.');
        },
      );

      return position;
    } catch (e) {
      print('Error getting current location: $e');
      rethrow;
    }
  }

  /// Calcular distancia entre dos puntos en metros
  double calculateDistance({
    required double lat1,
    required double lon1, 
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Verificar si el usuario está dentro del perímetro de una obra
  bool isWithinWorksite({
    required Position userPosition,
    required double worksiteLat,
    required double worksiteLon,
    required double radiusMeters,
  }) {
    double distance = calculateDistance(
      lat1: userPosition.latitude,
      lon1: userPosition.longitude,
      lat2: worksiteLat,
      lon2: worksiteLon,
    );

    print('=== VALIDACIÓN GEOFENCE ===');
    print('Usuario: ${userPosition.latitude}, ${userPosition.longitude}');
    print('Obra: $worksiteLat, $worksiteLon');
    print('Distancia: ${distance.toStringAsFixed(2)} metros');
    print('Radio permitido: $radiusMeters metros');
    print('¿Dentro del perímetro?: ${distance <= radiusMeters}');
    print('==========================');

    return distance <= radiusMeters;
  }

  /// Obtener descripción legible del error de ubicación
  String getLocationErrorMessage(dynamic error) {
    String errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('timeout')) {
      return 'Tiempo agotado al obtener ubicación. Verifica que el GPS esté activado.';
    } else if (errorStr.contains('permission') || errorStr.contains('denied')) {
      return 'Sin permisos de ubicación. Ve a Configuración para habilitarlos.';
    } else if (errorStr.contains('service') || errorStr.contains('disabled')) {
      return 'Los servicios de ubicación están deshabilitados. Activa el GPS.';
    } else if (errorStr.contains('network')) {
      return 'Error de red al obtener ubicación.';
    } else {
      return 'Error al obtener ubicación GPS. Verifica que esté activado.';
    }
  }

  /// Verificar estado actual de los permisos
  Future<LocationPermission> getLocationPermissionStatus() async {
    return await Geolocator.checkPermission();
  }
}