import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceModel {
  final String? id;
  final String workerId;
  final String worksiteId;
  final DateTime date;
  final PunchRecord? punchIn;
  final PunchRecord? punchOut;
  final String status; // "Presente", "Ausente", "Incompleto"
  final double? workedHours;

  AttendanceModel({
    this.id,
    required this.workerId,
    required this.worksiteId,
    required this.date,
    this.punchIn,
    this.punchOut,
    this.status = "Incompleto",
    this.workedHours,
  });

  factory AttendanceModel.fromFirestore(Map<String, dynamic> data, String id) {
    return AttendanceModel(
      id: id,
      workerId: data['workerId'] ?? '',
      worksiteId: data['worksiteId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      punchIn: data['punchIn'] != null 
          ? PunchRecord.fromMap(data['punchIn'] as Map<String, dynamic>)
          : null,
      punchOut: data['punchOut'] != null 
          ? PunchRecord.fromMap(data['punchOut'] as Map<String, dynamic>)
          : null,
      status: data['status'] ?? 'Incompleto',
      workedHours: data['workedHours']?.toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'workerId': workerId,
      'worksiteId': worksiteId,
      'date': Timestamp.fromDate(date),
      'punchIn': punchIn?.toMap(),
      'punchOut': punchOut?.toMap(),
      'status': status,
      'workedHours': workedHours,
    };
  }

  AttendanceModel copyWith({
    String? id,
    String? workerId,
    String? worksiteId,
    DateTime? date,
    PunchRecord? punchIn,
    PunchRecord? punchOut,
    String? status,
    double? workedHours,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      workerId: workerId ?? this.workerId,
      worksiteId: worksiteId ?? this.worksiteId,
      date: date ?? this.date,
      punchIn: punchIn ?? this.punchIn,
      punchOut: punchOut ?? this.punchOut,
      status: status ?? this.status,
      workedHours: workedHours ?? this.workedHours,
    );
  }
}

class PunchRecord {
  final DateTime timestamp;
  final GeoPoint location;
  final bool isValid;

  PunchRecord({
    required this.timestamp,
    required this.location,
    this.isValid = false,
  });

  factory PunchRecord.fromMap(Map<String, dynamic> data) {
    return PunchRecord(
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      location: data['location'] as GeoPoint,
      isValid: data['isValid'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'location': location,
      'isValid': isValid,
    };
  }
}