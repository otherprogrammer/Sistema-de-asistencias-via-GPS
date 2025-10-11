import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

/// Servicio para gestionar marcas de asistencia offline
class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Connectivity _connectivity = Connectivity();
  
  static const String _pendingAttendanceKey = 'pending_attendances';
  static const String _lastSyncAttemptKey = 'last_sync_attempt';

  /// Verificar si hay conexión a internet
  Future<bool> hasInternetConnection() async {
    try {
      final ConnectivityResult connectivityResult = await _connectivity.checkConnectivity();
      
      // Verificar si hay conexión (no es 'none')
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      print('Error checking connectivity: $e');
      return false;
    }
  }

  /// 🔧 CORREGIDO: Guardar marca de asistencia pendiente (offline) CON validación
  Future<String> savePendingAttendance({
    required String workerId,
    required String worksiteId,
    required String type, // 'checkIn' o 'checkOut'
    required Position position,
    required DateTime timestamp,
    required bool isValid, // ✅ NUEVO: Ya viene validado desde AttendanceService
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Generar ID temporal único
      String tempId = 'offline_${DateTime.now().millisecondsSinceEpoch}';
      
      // Crear objeto de asistencia pendiente
      Map<String, dynamic> pendingAttendance = {
        'tempId': tempId,
        'workerId': workerId,
        'worksiteId': worksiteId,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'isValid': isValid, // ✅ Guardar el resultado de la validación
        'status': 'pending', // pending, syncing, synced, failed
        'createdAt': DateTime.now().toIso8601String(),
        'syncAttempts': 0,
      };

      // Obtener lista de pendientes
      List<String> pendingList = prefs.getStringList(_pendingAttendanceKey) ?? [];
      
      // Agregar nueva marca
      pendingList.add(jsonEncode(pendingAttendance));
      
      // Guardar
      await prefs.setStringList(_pendingAttendanceKey, pendingList);
      
      print('💾 Marca guardada offline: $tempId ($type) - isValid: $isValid');
      return tempId;
    } catch (e) {
      print('❌ Error saving pending attendance: $e');
      rethrow;
    }
  }

  /// Obtener todas las marcas pendientes de sincronización
  Future<List<Map<String, dynamic>>> getPendingAttendances() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingList = prefs.getStringList(_pendingAttendanceKey) ?? [];
      
      return pendingList
          .map((item) => jsonDecode(item) as Map<String, dynamic>)
          .where((item) => item['status'] != 'synced') // Solo pendientes
          .toList();
    } catch (e) {
      print('❌ Error getting pending attendances: $e');
      return [];
    }
  }

  /// Contar marcas pendientes
  Future<int> getPendingCount() async {
    final pending = await getPendingAttendances();
    return pending.length;
  }

  /// Sincronizar todas las marcas pendientes
  Future<SyncResult> syncPendingAttendances() async {
    print('🔄 Iniciando sincronización de marcas pendientes...');
    
    // Verificar conexión
    bool hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      print('❌ No hay conexión a internet');
      return SyncResult(
        success: false,
        synced: 0,
        failed: 0,
        message: 'Sin conexión a internet',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> pendingList = prefs.getStringList(_pendingAttendanceKey) ?? [];
    
    if (pendingList.isEmpty) {
      print('✅ No hay marcas pendientes de sincronizar');
      return SyncResult(success: true, synced: 0, failed: 0, message: 'Sin pendientes');
    }

    int syncedCount = 0;
    int failedCount = 0;
    List<String> updatedList = [];

    for (String item in pendingList) {
      Map<String, dynamic> attendance = jsonDecode(item);
      
      // Saltar si ya fue sincronizado
      if (attendance['status'] == 'synced') {
        continue;
      }

      try {
        // Intentar sincronizar
        attendance['status'] = 'syncing';
        attendance['syncAttempts'] = (attendance['syncAttempts'] ?? 0) + 1;
        
        bool syncSuccess = await _syncSingleAttendance(attendance);
        
        if (syncSuccess) {
          attendance['status'] = 'synced';
          attendance['syncedAt'] = DateTime.now().toIso8601String();
          syncedCount++;
          print('✅ Sincronizado: ${attendance['tempId']}');
        } else {
          attendance['status'] = 'failed';
          failedCount++;
          updatedList.add(jsonEncode(attendance)); // Guardar para reintentar
          print('❌ Falló sincronización: ${attendance['tempId']}');
        }
      } catch (e) {
        attendance['status'] = 'failed';
        attendance['lastError'] = e.toString();
        failedCount++;
        updatedList.add(jsonEncode(attendance)); // Guardar para reintentar
        print('❌ Error sincronizando ${attendance['tempId']}: $e');
      }
    }

    // Actualizar lista (eliminar sincronizados, mantener fallidos)
    await prefs.setStringList(_pendingAttendanceKey, updatedList);
    await prefs.setString(_lastSyncAttemptKey, DateTime.now().toIso8601String());

    print('🔄 Sincronización completada: $syncedCount exitosos, $failedCount fallidos');
    
    return SyncResult(
      success: failedCount == 0,
      synced: syncedCount,
      failed: failedCount,
      message: failedCount == 0 
          ? 'Todas las marcas sincronizadas exitosamente'
          : 'Algunas marcas no pudieron sincronizarse',
    );
  }

  /// 🔧 CORREGIDO: Sincronizar una sola marca de asistencia CON validación preservada
  Future<bool> _syncSingleAttendance(Map<String, dynamic> attendance) async {
    try {
      String workerId = attendance['workerId'];
      String worksiteId = attendance['worksiteId'];
      String type = attendance['type'];
      DateTime timestamp = DateTime.parse(attendance['timestamp']);
      double latitude = attendance['latitude'];
      double longitude = attendance['longitude'];
      bool isValid = attendance['isValid'] ?? true; // ✅ Obtener validación guardada

      print('🔄 Sincronizando $type - isValid: $isValid');

      // Buscar documento de asistencia del día
      DateTime date = DateTime(timestamp.year, timestamp.month, timestamp.day);
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = startOfDay.add(const Duration(days: 1));

      QuerySnapshot query = await _firestore
          .collection('attendances')
          .where('workerId', isEqualTo: workerId)
          .where('worksiteId', isEqualTo: worksiteId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .limit(1)
          .get();

      GeoPoint location = GeoPoint(latitude, longitude);
      
      Map<String, dynamic> punchData = {
        'timestamp': Timestamp.fromDate(timestamp),
        'location': location,
        'isValid': isValid, // ✅ Usar el valor validado guardado localmente
        'syncedFrom': 'offline',
      };

      if (type == 'checkIn') {
        if (query.docs.isEmpty) {
          // Crear nuevo documento
          await _firestore.collection('attendances').add({
            'workerId': workerId,
            'worksiteId': worksiteId,
            'date': Timestamp.fromDate(date),
            'punchIn': punchData,
            'status': 'Presente',
            'createdOffline': true,
          });
          print('✅ Nuevo documento creado con entrada offline');
        } else {
          // Actualizar documento existente
          await query.docs.first.reference.update({
            'punchIn': punchData,
            'status': 'Presente',
          });
          print('✅ Documento existente actualizado con entrada offline');
        }
      } else if (type == 'checkOut') {
        if (query.docs.isEmpty) {
          throw Exception('No se encontró registro de entrada');
        }
        
        // Actualizar con salida
        DocumentSnapshot doc = query.docs.first;
        Map<String, dynamic> docData = doc.data() as Map<String, dynamic>;
        
        // Calcular horas trabajadas
        DateTime? punchInTime;
        if (docData['punchIn'] != null) {
          punchInTime = (docData['punchIn']['timestamp'] as Timestamp).toDate();
        }
        
        double? workedHours;
        if (punchInTime != null) {
          Duration duration = timestamp.difference(punchInTime);
          workedHours = duration.inMinutes / 60.0;
        }

        await doc.reference.update({
          'punchOut': punchData,
          'workedHours': workedHours,
          'status': 'Presente',
        });
        print('✅ Salida offline sincronizada - Horas trabajadas: ${workedHours?.toStringAsFixed(2)}h');
      }

      return true;
    } catch (e) {
      print('❌ Error en _syncSingleAttendance: $e');
      return false;
    }
  }

  /// Limpiar marcas sincronizadas (después de X días)
  Future<void> cleanOldSyncedAttendances({int daysOld = 7}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingList = prefs.getStringList(_pendingAttendanceKey) ?? [];
      
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      
      List<String> filteredList = pendingList.where((item) {
        Map<String, dynamic> attendance = jsonDecode(item);
        
        // Mantener si no está sincronizado
        if (attendance['status'] != 'synced') return true;
        
        // Mantener si es reciente
        DateTime syncedAt = DateTime.parse(attendance['syncedAt'] ?? attendance['createdAt']);
        return syncedAt.isAfter(cutoffDate);
      }).toList();

      await prefs.setStringList(_pendingAttendanceKey, filteredList);
      print('🧹 Limpieza completada. Eliminadas ${pendingList.length - filteredList.length} marcas antiguas');
    } catch (e) {
      print('Error cleaning old synced attendances: $e');
    }
  }

  /// Obtener último intento de sincronización
  Future<DateTime?> getLastSyncAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? lastSync = prefs.getString(_lastSyncAttemptKey);
      return lastSync != null ? DateTime.parse(lastSync) : null;
    } catch (e) {
      return null;
    }
  }

  /// Escuchar cambios de conectividad
  Stream<List<ConnectivityResult>> watchConnectivity() {
    return _connectivity.onConnectivityChanged.map((result) => [result]);
  }

  /// Iniciar sincronización automática al detectar conexión
  void startAutoSync() {
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        int pendingCount = await getPendingCount();
        if (pendingCount > 0) {
          print('📶 Conexión detectada. Sincronizando $pendingCount marcas pendientes...');
          await syncPendingAttendances();
        }
      }
    });
  }
}

/// Resultado de la sincronización
class SyncResult {
  final bool success;
  final int synced;
  final int failed;
  final String message;

  SyncResult({
    required this.success,
    required this.synced,
    required this.failed,
    required this.message,
  });
}