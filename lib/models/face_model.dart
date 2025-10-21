import 'dart:math';
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

  /// Calcular similitud entre dos embeddings usando similitud del coseno
  /// Rango: 0.0 a 1.0 (1.0 = idéntico, 0.0 = completamente diferente)
  static double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw Exception('Los embeddings deben tener la misma longitud');
    }

    // Calcular producto punto (dot product)
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }

    // Evitar división por cero
    if (norm1 == 0 || norm2 == 0) return 0.0;

    // Similitud del coseno: producto punto / (norma1 * norma2)
    double cosineSimilarity = dotProduct / (sqrt(norm1) * sqrt(norm2));

    // Convertir a porcentaje (0-100%)
    // Rango: 0.0 a 1.0 se convierte a 0% a 100%
    double similarity = (cosineSimilarity * 100.0).clamp(0.0, 100.0);

    return similarity;
  }

  /// Verificar si dos rostros son la misma persona
  /// Threshold recomendado:
  /// - MobileFaceNet 128D: 60-65%
  /// - FaceNet 512D: 70-75%
  static bool areMatching(List<double> embedding1, List<double> embedding2, {double threshold = 60.0}) {
    double similarity = calculateSimilarity(embedding1, embedding2);
    print('📊 Similitud calculada: ${similarity.toStringAsFixed(2)}%');
    return similarity >= threshold;
  }
}