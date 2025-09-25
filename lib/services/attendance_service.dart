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

      // Crear registro de entrada
      PunchRecord punchIn = PunchRecord(
        timestamp: DateTime.now(),
        location: GeoPoint(position.latitude, position.longitude),
        isValid: isWithinWorksite,
      );

      // Buscar o crear documento de asistencia para hoy
      String attendanceId = await _getOrCreateTodayAttendance(
        workerId: workerId,
        worksiteId: worksiteId,
        punchIn: punchIn,
      );

      if (!isWithinWorksite) {
        throw Exception(
          'Estás fuera del perímetro permitido para esta obra. '
          'Distancia: ${_locationService.calculateDistance(
            lat1: position.latitude,
            lon1: position.longitude,
            lat2: worksite.latitude,
            lon2: worksite.longitude,
          ).toStringAsFixed(0)}m, '
          'Permitido: ${worksite.radius.toStringAsFixed(0)}m'
        );
      }

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

      // Crear registro de salida
      PunchRecord punchOut = PunchRecord(
        timestamp: DateTime.now(),
        location: GeoPoint(position.latitude, position.longitude),
        isValid: isWithinWorksite,
      );

      // Actualizar documento de asistencia de hoy
      String attendanceId = await _updateTodayAttendance(
        workerId: workerId,
        worksiteId: worksiteId,
        punchOut: punchOut,
      );

      if (!isWithinWorksite) {
        throw Exception(
          'Estás fuera del perímetro permitido para esta obra. '
          'Distancia: ${_locationService.calculateDistance(
            lat1: position.latitude,
            lon1: position.longitude,
            lat2: worksite.latitude,
            lon2: worksite.longitude,
          ).toStringAsFixed(0)}m, '
          'Permitido: ${worksite.radius.toStringAsFixed(0)}m'
        );
      }

      return attendanceId;
    } catch (e) {
      print('Error marking check-out: $e');
      rethrow;
    }
  }

  /// Obtener o crear documento de asistencia para hoy
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
      // Actualizar documento existente
      DocumentSnapshot doc = query.docs.first;
      await doc.reference.update({
        'punchIn': punchIn.toMap(),
        'status': 'Presente',
      });
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

  /// Actualizar documento de asistencia con salida
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
    await doc.reference.update({
      'punchOut': punchOut.toMap(),
      'workedHours': workedHours,
      'status': 'Presente',
    });

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

  /// Verificar si ya marcó entrada hoy
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

    return attendance.punchIn != null;
  }

  /// Verificar si ya marcó salida hoy
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

    return attendance.punchOut != null;
  }
}