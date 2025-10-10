import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../models/attendance_model.dart';
import '../models/worksite_model.dart';
import 'location_service.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  /// Registrar entrada del trabajador
  Future<String> markCheckIn({
    required String workerId,
    required String worksiteId,
  }) async {
    try {
      // Obtener ubicación actual
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('No se pudo obtener la ubicación GPS');
      }

      // Obtener datos de la obra para validar geofence
      WorksiteModel worksite = await _getWorksite(worksiteId);

      // 🔍 VALIDACIÓN: Verificar que las coordenadas sean válidas
      if (!_areValidCoordinates(worksite.latitude, worksite.longitude)) {
        throw Exception(
          '⚠️ ERROR DE CONFIGURACIÓN:\n'
          'Las coordenadas de la obra "${worksite.name}" no son válidas.\n'
          'Lat: ${worksite.latitude}, Lon: ${worksite.longitude}\n'
          'Contacta al administrador para corregir la ubicación de la obra.'
        );
      }

      // Validar que esté dentro del perímetro
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

      // Crear registro del intento (válido o no)
      PunchRecord punchIn = PunchRecord(
        timestamp: DateTime.now(),
        location: GeoPoint(position.latitude, position.longitude),
        isValid: isWithinWorksite,
      );

      // SI NO ESTÁ DENTRO: Guardar intento fallido
      if (!isWithinWorksite) {
        await _recordFailedCheckInAttempt(
          workerId: workerId,
          worksiteId: worksiteId,
          punchIn: punchIn,
          distance: distance,
          allowedRadius: worksite.radius,
        );

        String distanceText = _formatDistance(distance);
        throw Exception(
          'Estás fuera del perímetro permitido para "${worksite.name}".\n\n'
          '📍 Tu distancia: $distanceText\n'
          '✅ Permitido: ${worksite.radius.toStringAsFixed(0)}m\n\n'
          'Intento registrado como "Intento Fallido".'
        );
      }

      // SI ESTÁ DENTRO: Crear documento de asistencia exitosa
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
      // Obtener ubicación actual
      Position? position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('No se pudo obtener la ubicación GPS');
      }

      // Obtener datos de la obra para validar geofence
      WorksiteModel worksite = await _getWorksite(worksiteId);

      // 🔍 VALIDACIÓN: Verificar que las coordenadas sean válidas
      if (!_areValidCoordinates(worksite.latitude, worksite.longitude)) {
        throw Exception(
          '⚠️ ERROR DE CONFIGURACIÓN:\n'
          'Las coordenadas de la obra "${worksite.name}" no son válidas.\n'
          'Contacta al administrador para corregir la ubicación.'
        );
      }

      // Validar que esté dentro del perímetro
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

      // Crear registro del intento (válido o no)
      PunchRecord punchOut = PunchRecord(
        timestamp: DateTime.now(),
        location: GeoPoint(position.latitude, position.longitude),
        isValid: isWithinWorksite,
      );

      // SI NO ESTÁ DENTRO: Guardar intento fallido de salida
      if (!isWithinWorksite) {
        await _recordFailedCheckOutAttempt(
          workerId: workerId,
          worksiteId: worksiteId,
          punchOut: punchOut,
          distance: distance,
          allowedRadius: worksite.radius,
        );

        String distanceText = _formatDistance(distance);
        throw Exception(
          'Estás fuera del perímetro permitido para "${worksite.name}".\n\n'
          '📍 Tu distancia: $distanceText\n'
          '✅ Permitido: ${worksite.radius.toStringAsFixed(0)}m\n\n'
          'Intento registrado como "Intento Fallido".'
        );
      }

      // SI ESTÁ DENTRO: Actualizar documento de asistencia exitosa
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

  /// Registrar intento fallido de entrada (fuera del perímetro)
  Future<String> _recordFailedCheckInAttempt({
    required String workerId,
    required String worksiteId,
    required PunchRecord punchIn,
    required double distance,
    required double allowedRadius,
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

    String failureReason = 'Fuera del perímetro: ${_formatDistance(distance)} de ${allowedRadius.toStringAsFixed(0)}m permitidos';

    if (query.docs.isNotEmpty) {
      DocumentSnapshot doc = query.docs.first;
      await doc.reference.update({
        'punchIn': punchIn.toMap(),
        'status': 'Intento Fallido',
        'failureReason': failureReason,
        'lastAttempt': Timestamp.now(),
      });
      return doc.id;
    } else {
      AttendanceModel attendance = AttendanceModel(
        workerId: workerId,
        worksiteId: worksiteId,
        date: today,
        punchIn: punchIn,
        status: 'Intento Fallido',
      );

      Map<String, dynamic> data = attendance.toFirestore();
      data['failureReason'] = failureReason;
      data['lastAttempt'] = Timestamp.now();

      DocumentReference docRef = await _firestore
          .collection('attendances')
          .add(data);
      
      return docRef.id;
    }
  }

  /// Registrar intento fallido de salida (fuera del perímetro)
  Future<String> _recordFailedCheckOutAttempt({
    required String workerId,
    required String worksiteId,
    required PunchRecord punchOut,
    required double distance,
    required double allowedRadius,
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

    String failureReason = 'Salida fuera del perímetro: ${_formatDistance(distance)} de ${allowedRadius.toStringAsFixed(0)}m permitidos';

    DocumentSnapshot doc = query.docs.first;
    await doc.reference.update({
      'punchOut': punchOut.toMap(),
      'status': 'Intento Fallido',
      'failureReason': failureReason,
      'lastAttempt': Timestamp.now(),
    });

    return doc.id;
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

  /// Obtener datos de la obra
  Future<WorksiteModel> _getWorksite(String worksiteId) async {
    DocumentSnapshot doc = await _firestore
        .collection('worksites')
        .doc(worksiteId)
        .get();
    
    if (!doc.exists) {
      throw Exception('Obra no encontrada');
    }

    return WorksiteModel.fromFirestore(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
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

    print('❌ No se encontró entrada exitosa (solo intentos fallidos)');
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