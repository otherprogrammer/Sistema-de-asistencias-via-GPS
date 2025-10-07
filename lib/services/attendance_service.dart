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

        throw Exception(
          'Estás fuera del perímetro permitido para esta obra. '
          'Distancia: ${distance.toStringAsFixed(0)}m, '
          'Permitido: ${worksite.radius.toStringAsFixed(0)}m. '
          'Intento registrado como "Intento Fallido".'
        );
      }

      // SI ESTÁ DENTRO: Crear documento de asistencia exitosa
      String attendanceId = await _getOrCreateTodayAttendance(
        workerId: workerId,
        worksiteId: worksiteId,
        punchIn: punchIn,
      );

      return attendanceId;
    } catch (e) {
      print('Error marking check-in: $e');
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

        throw Exception(
          'Estás fuera del perímetro permitido para esta obra. '
          'Distancia: ${distance.toStringAsFixed(0)}m, '
          'Permitido: ${worksite.radius.toStringAsFixed(0)}m. '
          'Intento registrado como "Intento Fallido".'
        );
      }

      // SI ESTÁ DENTRO: Actualizar documento de asistencia exitosa
      String attendanceId = await _updateTodayAttendance(
        workerId: workerId,
        worksiteId: worksiteId,
        punchOut: punchOut,
      );

      return attendanceId;
    } catch (e) {
      print('Error marking check-out: $e');
      rethrow;
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

    // Buscar documento existente para hoy
    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('worksiteId', isEqualTo: worksiteId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // Actualizar documento existente con nuevo intento fallido
      DocumentSnapshot doc = query.docs.first;
      await doc.reference.update({
        'punchIn': punchIn.toMap(),
        'status': 'Intento Fallido',
        'failureReason': 'Fuera del perímetro: ${distance.toStringAsFixed(0)}m de ${allowedRadius.toStringAsFixed(0)}m permitidos',
        'lastAttempt': Timestamp.now(),
      });
      return doc.id;
    } else {
      // Crear nuevo documento con intento fallido
      AttendanceModel attendance = AttendanceModel(
        workerId: workerId,
        worksiteId: worksiteId,
        date: today,
        punchIn: punchIn,
        status: 'Intento Fallido',
      );

      Map<String, dynamic> data = attendance.toFirestore();
      data['failureReason'] = 'Fuera del perímetro: ${distance.toStringAsFixed(0)}m de ${allowedRadius.toStringAsFixed(0)}m permitidos';
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

    // Buscar documento existente para hoy
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
    await doc.reference.update({
      'punchOut': punchOut.toMap(),
      'status': 'Intento Fallido',
      'failureReason': 'Salida fuera del perímetro: ${distance.toStringAsFixed(0)}m de ${allowedRadius.toStringAsFixed(0)}m permitidos',
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

    // Buscar documento existente para hoy
    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('worksiteId', isEqualTo: worksiteId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      // Actualizar documento existente (podría ser un intento fallido previo)
      DocumentSnapshot doc = query.docs.first;
      Map<String, dynamic> updateData = {
        'punchIn': punchIn.toMap(),
        'status': 'Presente',
      };
      
      // Limpiar campos de intento fallido si existían
      updateData['failureReason'] = FieldValue.delete();
      updateData['lastAttempt'] = FieldValue.delete();
      
      await doc.reference.update(updateData);
      return doc.id;
    } else {
      // Crear nuevo documento
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

    // Buscar documento existente para hoy
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

    // Calcular horas trabajadas
    Duration workedDuration = punchOut.timestamp.difference(attendance.punchIn!.timestamp);
    double workedHours = workedDuration.inMinutes / 60.0;

    // Actualizar documento
    Map<String, dynamic> updateData = {
      'punchOut': punchOut.toMap(),
      'workedHours': workedHours,
      'status': 'Presente',
    };
    
    // Limpiar campos de intento fallido si existían
    updateData['failureReason'] = FieldValue.delete();
    updateData['lastAttempt'] = FieldValue.delete();

    await doc.reference.update(updateData);

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

  /// Verificar si ya marcó entrada hoy (exitosamente)
  Future<bool> hasCheckedInToday(String workerId) async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    AttendanceModel attendance = AttendanceModel.fromFirestore(
      query.docs.first.data() as Map<String, dynamic>,
      query.docs.first.id,
    );

    // Solo retorna true si tiene punchIn Y el estado es "Presente"
    // Si es "Intento Fallido", permite seguir intentando
    return attendance.punchIn != null && attendance.status == 'Presente';
  }

  /// Verificar si ya marcó salida hoy (exitosamente)
  Future<bool> hasCheckedOutToday(String workerId) async {
    DateTime today = DateTime.now();
    DateTime startOfDay = DateTime(today.year, today.month, today.day);
    DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    QuerySnapshot query = await _firestore
        .collection('attendances')
        .where('workerId', isEqualTo: workerId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (query.docs.isEmpty) return false;

    AttendanceModel attendance = AttendanceModel.fromFirestore(
      query.docs.first.data() as Map<String, dynamic>,
      query.docs.first.id,
    );

    // Solo retorna true si tiene punchOut Y el estado es "Presente"
    // Si es "Intento Fallido", permite seguir intentando
    return attendance.punchOut != null && attendance.status == 'Presente';
  }
}