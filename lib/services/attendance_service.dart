import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/attendance_model.dart';
import '../models/worksite_model.dart';
import 'location_service.dart';
import 'offline_sync_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final OfflineSyncService _offlineSync = OfflineSyncService();
  
  static const String _cachedWorksitePrefix = 'cached_worksite_';

  /// Registrar entrada del trabajador
  Future<String> markCheckIn({
    required String workerId,
    required String worksiteId,
  }) async {
    try {
      // 1️⃣ Obtener ubicación actual
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('No se pudo obtener la ubicación GPS');
      }

      // 2️⃣ Obtener datos de la obra para validar geofence
      WorksiteModel worksite = await _getWorksite(worksiteId);

      // 3️⃣ VALIDACIÓN: Verificar que las coordenadas sean válidas
      if (!_areValidCoordinates(worksite.latitude, worksite.longitude)) {
        throw Exception(
          '⚠️ ERROR DE CONFIGURACIÓN:\n'
          'Las coordenadas de la obra "${worksite.name}" no son válidas.\n'
          'Lat: ${worksite.latitude}, Lon: ${worksite.longitude}\n'
          'Contacta al administrador para corregir la ubicación de la obra.'
        );
      }

      // 4️⃣ Validar que esté dentro del perímetro
      bool isWithinWorksite = _locationService.isWithinWorksite(
        userPosition: position,
        worksiteLat: worksite.latitude,
        worksiteLon: worksite.longitude,
        radiusMeters: worksite.radius,
      );

      double distance = _locationService.calculateDistance(
        lat1: position.latitude,
        lon1: position.longitude,
        lat2: worksite.latitude,
        lon2: worksite.longitude,
      );

      // 🔍 DEBUG: Log detallado
      print('📍 ENTRADA - DEBUG COMPLETO:');
      print('Usuario: ${position.latitude}, ${position.longitude}');
      print('Obra "${worksite.name}": ${worksite.latitude}, ${worksite.longitude}');
      print('Distancia: ${distance.toStringAsFixed(2)}m');
      print('Radio permitido: ${worksite.radius}m');
      print('¿Dentro?: $isWithinWorksite');
      print('─────────────────────────────');

      // 5️⃣ SI NO ESTÁ DENTRO: Rechazar (NO guardar nada)
      if (!isWithinWorksite) {
        String distanceText = _formatDistance(distance);
        throw Exception(
          'Estás fuera del perímetro permitido para "${worksite.name}".\n\n'
          '📍 Tu distancia: $distanceText\n'
          '✅ Permitido: ${worksite.radius.toStringAsFixed(0)}m\n\n'
          'Acércate a la obra para marcar asistencia.'
        );
      }

      // 6️⃣ Verificar conexión a internet
      bool hasConnection = await _offlineSync.hasInternetConnection();
      
      if (!hasConnection) {
        // 📵 MODO OFFLINE: Guardar localmente (ya validado)
        print('📵 Sin conexión. Guardando entrada offline validada...');
        String tempId = await _offlineSync.savePendingAttendance(
          workerId: workerId,
          worksiteId: worksiteId,
          type: 'checkIn',
          position: position,
          timestamp: DateTime.now(),
          isValid: true, // ✅ Ya validamos que está dentro
        );
        
        throw OfflineException(
          'Entrada guardada sin conexión.\n\n'
          '✅ Ubicación validada: Dentro de la obra\n'
          '📵 Se sincronizará automáticamente cuando recuperes internet.\n\n'
          '📍 Ubicación: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
          '🕒 Hora: ${DateTime.now().toString().substring(11, 16)}',
          tempId: tempId,
        );
      }

      // 7️⃣ Con internet: Guardar en Firestore
      // Crear registro del intento válido
      PunchRecord punchIn = PunchRecord(
        timestamp: DateTime.now(),
        location: GeoPoint(position.latitude, position.longitude),
        isValid: true, // ✅ Ya validamos que está dentro
      );

      String attendanceId = await _getOrCreateTodayAttendance(
        workerId: workerId,
        worksiteId: worksiteId,
        punchIn: punchIn,
      );

      print('✅ Entrada registrada exitosamente. ID: $attendanceId');
      return attendanceId;
    } catch (e) {
      print('❌ Error marking check-in: $e');
      rethrow;
    }
  }

  /// Registrar salida del trabajador
  Future<String> markCheckOut({
    required String workerId,
    required String worksiteId,
  }) async {
    try {
      // 1️⃣ Obtener ubicación actual
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('No se pudo obtener la ubicación GPS');
      }

      // 2️⃣ Obtener datos de la obra para validar geofence
      WorksiteModel worksite = await _getWorksite(worksiteId);

      // 3️⃣ VALIDACIÓN: Verificar que las coordenadas sean válidas
      if (!_areValidCoordinates(worksite.latitude, worksite.longitude)) {
        throw Exception(
          '⚠️ ERROR DE CONFIGURACIÓN:\n'
          'Las coordenadas de la obra "${worksite.name}" no son válidas.\n'
          'Contacta al administrador para corregir la ubicación.'
        );
      }

      // 4️⃣ Validar que esté dentro del perímetro
      bool isWithinWorksite = _locationService.isWithinWorksite(
        userPosition: position,
        worksiteLat: worksite.latitude,
        worksiteLon: worksite.longitude,
        radiusMeters: worksite.radius,
      );

      double distance = _locationService.calculateDistance(
        lat1: position.latitude,
        lon1: position.longitude,
        lat2: worksite.latitude,
        lon2: worksite.longitude,
      );

      // 🔍 DEBUG: Log detallado
      print('📍 SALIDA - DEBUG COMPLETO:');
      print('Usuario: ${position.latitude}, ${position.longitude}');
      print('Obra "${worksite.name}": ${worksite.latitude}, ${worksite.longitude}');
      print('Distancia: ${distance.toStringAsFixed(2)}m');
      print('Radio permitido: ${worksite.radius}m');
      print('¿Dentro?: $isWithinWorksite');
      print('─────────────────────────────');

      // 5️⃣ SI NO ESTÁ DENTRO: Rechazar (NO guardar nada)
      if (!isWithinWorksite) {
        String distanceText = _formatDistance(distance);
        throw Exception(
          'Estás fuera del perímetro permitido para "${worksite.name}".\n\n'
          '📍 Tu distancia: $distanceText\n'
          '✅ Permitido: ${worksite.radius.toStringAsFixed(0)}m\n\n'
          'Acércate a la obra para marcar salida.'
        );
      }

      // 6️⃣ Verificar conexión a internet
      bool hasConnection = await _offlineSync.hasInternetConnection();
      
      if (!hasConnection) {
        // 📵 MODO OFFLINE: Guardar localmente (ya validado)
        print('📵 Sin conexión. Guardando salida offline validada...');
        String tempId = await _offlineSync.savePendingAttendance(
          workerId: workerId,
          worksiteId: worksiteId,
          type: 'checkOut',
          position: position,
          timestamp: DateTime.now(),
          isValid: true, // ✅ Ya validamos que está dentro
        );
        
        throw OfflineException(
          'Salida guardada sin conexión.\n\n'
          '✅ Ubicación validada: Dentro de la obra\n'
          '📵 Se sincronizará automáticamente cuando recuperes internet.\n\n'
          '📍 Ubicación: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}\n'
          '🕒 Hora: ${DateTime.now().toString().substring(11, 16)}',
          tempId: tempId,
        );
      }

      // 7️⃣ Con internet: Actualizar en Firestore
      // Crear registro del intento válido
      PunchRecord punchOut = PunchRecord(
        timestamp: DateTime.now(),
        location: GeoPoint(position.latitude, position.longitude),
        isValid: true, // ✅ Ya validamos que está dentro
      );

      String attendanceId = await _updateTodayAttendance(
        workerId: workerId,
        worksiteId: worksiteId,
        punchOut: punchOut,
      );

      print('✅ Salida registrada exitosamente. ID: $attendanceId');
      return attendanceId;
    } catch (e) {
      print('❌ Error marking check-out: $e');
      rethrow;
    }
  }

  /// 🆕 Validar que las coordenadas sean válidas geográficamente
  bool _areValidCoordinates(double latitude, double longitude) {
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    if (latitude == 0.0 && longitude == 0.0) return false;
    return true;
  }

  /// 🆕 Formatear distancia de forma legible
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      double km = meters / 1000;
      return '${km.toStringAsFixed(2)} km';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
  }

  /// Obtener o crear documento de asistencia para hoy (entrada exitosa)
  Future<String> _getOrCreateTodayAttendance({
    required String workerId,
    required String worksiteId,
    required PunchRecord punchIn,
  }) async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('worksiteId', isEqualTo: worksiteId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      DocumentSnapshot doc = query.docs.first;
      Map<String, dynamic> updateData = {
        'punchIn': punchIn.toMap(),
        'status': 'Presente',
      };
      
      updateData['failureReason'] = FieldValue.delete();
      updateData['lastAttempt'] = FieldValue.delete();
      
      await doc.reference.update(updateData);
      print('📝 Documento actualizado: ${doc.id}');
      return doc.id;
    } else {
      AttendanceModel attendance = AttendanceModel(
        workerId: workerId,
        worksiteId: worksiteId,
        date: today,
        punchIn: punchIn,
        status: 'Presente',
      );

      DocumentReference docRef = await _firestore
          .collection('attendances')
          .add(attendance.toFirestore());
      
      print('📝 Nuevo documento creado: ${docRef.id}');
      return docRef.id;
    }
  }

  /// Actualizar documento de asistencia con salida (salida exitosa)
  Future<String> _updateTodayAttendance({
    required String workerId,
    required String worksiteId,
    required PunchRecord punchOut,
  }) async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('worksiteId', isEqualTo: worksiteId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No se encontró registro de entrada para hoy. Marca tu entrada primero.');
    }

    DocumentSnapshot doc = query.docs.first;
    AttendanceModel attendance = AttendanceModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );

    if (attendance.punchIn == null) {
      throw Exception('No se encontró registro de entrada para hoy. Marca tu entrada primero.');
    }

    Duration workedDuration = punchOut.timestamp.difference(attendance.punchIn!.timestamp);
    double workedHours = workedDuration.inMinutes / 60.0;

    Map<String, dynamic> updateData = {
      'punchOut': punchOut.toMap(),
      'workedHours': workedHours,
      'status': 'Presente',
    };
    
    updateData['failureReason'] = FieldValue.delete();
    updateData['lastAttempt'] = FieldValue.delete();

    await doc.reference.update(updateData);
    print('📝 Salida actualizada en documento: ${doc.id}');

    return doc.id;
  }

  /// Obtener datos de la obra (con caché offline)
  Future<WorksiteModel> _getWorksite(String worksiteId) async {
    try {
      // 1️⃣ Intentar obtener desde Firestore
      DocumentSnapshot doc = await _firestore
          .collection('worksites')
          .doc(worksiteId)
          .get()
          .timeout(const Duration(seconds: 5));
      
      if (!doc.exists) {
        throw Exception('Obra no encontrada');
      }

      WorksiteModel worksite = WorksiteModel.fromFirestore(
        doc.data() as Map<String, dynamic>,
        doc.id,
      );

      // 2️⃣ Guardar en caché local
      await _cacheWorksite(worksiteId, worksite);
      print('✅ Obra obtenida de Firestore y guardada en caché');
      
      return worksite;
    } catch (e) {
      print('⚠️ Error obteniendo obra de Firestore: $e');
      print('📦 Intentando cargar desde caché local...');
      
      // 3️⃣ Si falla (sin internet), cargar desde caché
      WorksiteModel? cachedWorksite = await _getCachedWorksite(worksiteId);
      
      if (cachedWorksite != null) {
        print('✅ Obra cargada desde caché local');
        return cachedWorksite;
      } else {
        throw Exception('Sin conexión y sin datos de la obra en caché. Conecta a internet al menos una vez.');
      }
    }
  }

  /// Guardar obra en caché local
  Future<void> _cacheWorksite(String worksiteId, WorksiteModel worksite) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      Map<String, dynamic> worksiteData = {
        'id': worksite.id,
        'name': worksite.name,
        'latitude': worksite.latitude,
        'longitude': worksite.longitude,
        'radius': worksite.radius,
        'cachedAt': DateTime.now().toIso8601String(),
      };
      
      await prefs.setString(
        '$_cachedWorksitePrefix$worksiteId',
        jsonEncode(worksiteData),
      );
    } catch (e) {
      print('❌ Error guardando obra en caché: $e');
    }
  }

  /// Obtener obra desde caché local
  Future<WorksiteModel?> _getCachedWorksite(String worksiteId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('$_cachedWorksitePrefix$worksiteId');
      
      if (cachedData == null) {
        print('❌ No hay caché disponible para esta obra');
        return null;
      }

      Map<String, dynamic> data = jsonDecode(cachedData);
      
      // Recrear el modelo usando fromFirestore para compatibilidad
      return WorksiteModel.fromFirestore(
        {
          'name': data['name'],
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'radius': data['radius'],
          'isActive': true,
        },
        data['id'],
      );
    } catch (e) {
      print('❌ Error leyendo obra desde caché: $e');
      return null;
    }
  }

  /// Obtener historial de asistencia del trabajador
  Future<List<AttendanceModel>> getWorkerAttendanceHistory({
    required String workerId,
    int limitDays = 30,
  }) async {
    DateTime startDate = DateTime.now().subtract(Duration(days: limitDays));

    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('date', descending: true)
        .limit(100)
        .get();

    return query.docs.map((doc) => AttendanceModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    )).toList();
  }

  /// 🔧 CORREGIDO: Verificar si ya marcó entrada hoy (exitosamente)
  Future<bool> hasCheckedInToday(String workerId) async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    print('🔍 === VERIFICANDO ENTRADA PARA HOY ===');
    print('WorkerId: $workerId');
    print('Rango: $startOfDay - $endOfDay');

    // 🔧 Buscar TODOS los documentos del día (no solo 1)
    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    print('📄 Total documentos encontrados: ${query.docs.length}');

    if (query.docs.isEmpty) {
      print('❌ No hay documentos para hoy');
      print('=====================================');
      return false;
    }

    // 🔧 Buscar si ALGUNO tiene status "Presente"
    for (var doc in query.docs) {
      var docData = doc.data() as Map<String, dynamic>;
      print('📄 Revisando documento: ${doc.id}');
      print('   - Status: ${docData['status']}');
      print('   - PunchIn existe: ${docData['punchIn'] != null}');

      AttendanceModel attendance = AttendanceModel.fromFirestore(docData, doc.id);

      if (attendance.punchIn != null && attendance.status == 'Presente') {
        print('✅ ¡Encontrado! Entrada registrada con éxito');
        print('=====================================');
        return true;
      }
    }

    print('❌ No se encontró entrada exitosa');
    print('=====================================');
    return false;
  }

  /// 🔧 CORREGIDO: Verificar si ya marcó salida hoy (exitosamente)
  Future<bool> hasCheckedOutToday(String workerId) async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    print('🔍 === VERIFICANDO SALIDA PARA HOY ===');
    print('WorkerId: $workerId');

    // 🔧 Buscar TODOS los documentos del día
    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    print('📄 Total documentos encontrados: ${query.docs.length}');

    if (query.docs.isEmpty) {
      print('❌ No hay documentos para hoy');
      print('=====================================');
      return false;
    }

    // 🔧 Buscar si ALGUNO tiene status "Presente" con salida
    for (var doc in query.docs) {
      var docData = doc.data() as Map<String, dynamic>;
      print('📄 Revisando documento: ${doc.id}');
      print('   - Status: ${docData['status']}');
      print('   - PunchOut existe: ${docData['punchOut'] != null}');

      AttendanceModel attendance = AttendanceModel.fromFirestore(docData, doc.id);

      if (attendance.punchOut != null && attendance.status == 'Presente') {
        print('✅ ¡Encontrado! Salida registrada con éxito');
        print('=====================================');
        return true;
      }
    }

    print('❌ No se encontró salida exitosa');
    print('=====================================');
    return false;
  }
}

/// Excepción personalizada para modo offline
class OfflineException implements Exception {
  final String message;
  final String tempId;

  OfflineException(this.message, {required this.tempId});

  @override
  String toString() => message;
}