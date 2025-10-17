import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para almacenar datos de reconocimiento facial
class FaceData {
  final String userId;
  final List<double> embedding; // Vector de características faciales (128 o 512 dimensiones)
  final DateTime registeredAt;
  final String? imageUrl; // Opcional: URL de la foto en Storage

  FaceData({
    required this.userId,
    required this.embedding,
    required this.registeredAt,
    this.imageUrl,
  });

  /// Crear desde Firestore
  factory FaceData.fromFirestore(Map<String, dynamic> data, String id) {
    return FaceData(
      userId: id,
      embedding: List<double>.from(data['faceEmbedding'] ?? []),
      registeredAt: (data['faceRegisteredAt'] as Timestamp).toDate(),
      imageUrl: data['faceImageUrl'],
    );
  }

  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'faceEmbedding': embedding,
      'faceRegisteredAt': Timestamp.fromDate(registeredAt),
      'faceImageUrl': imageUrl,
      'faceRegistered': true,
    };
  }

  /// Calcular similitud entre dos embeddings usando distancia euclidiana
  static double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Los embeddings deben tener la misma longitud');
    }

    double sum = 0.0;
    for (int i = 0; i < embedding1.length; i++) {
      double diff = embedding1[i] - embedding2[i];
      sum += diff * diff;
    }

    // Distancia euclidiana
    double distance = sum; // Sin sqrt para mayor velocidad
    
    // Convertir a porcentaje de similitud (0-100%)
    // Threshold típico para MobileFaceNet: ~1.0
    // Valores menores = mayor similitud
    double similarity = 100.0 / (1.0 + distance);
    
    return similarity;
  }

  /// Verificar si dos rostros son la misma persona
  static bool areMatching(List<double> embedding1, List<double> embedding2, {double threshold = 70.0}) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    print('📊 Similitud calculada: ${similarity.toStringAsFixed(2)}%');
    return similarity >= threshold;
  }
}