import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthService() {
    _initializeService();
  }

  /// Inicializar el servicio
  Future<void> _initializeService() async {
    _isLoading = true;
    notifyListeners();
    
    await _db.initializeDatabase();
    
    _isLoading = false;
    notifyListeners();
  }

  /// Login para trabajadores (DNI + Password) con validación de roles
  Future<bool> loginWorker(String dni, String password) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Validaciones básicas
      if (dni.length != 8) {
        _errorMessage = 'El DNI debe tener exactamente 8 dígitos';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (password.length < 6) {
        _errorMessage = 'La contraseña debe tener al menos 6 caracteres';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Autenticar con la base de datos
      UserModel? user = await _db.authenticateWorkerByDni(dni, password);
      
      if (user != null) {
        // Verificar permisos específicos para trabajadores
        if (!_db.hasPermission(user, 'mark_attendance')) {
          _errorMessage = 'No tienes permisos para registrar asistencia';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        
        _currentUser = user;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'DNI o contraseña incorrectos';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = _handleError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verificar si el usuario actual tiene un permiso específico
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;
    return _db.hasPermission(_currentUser!, permission);
  }

  /// Cambiar contraseña del usuario actual
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) return false;
    
    try {
      _isLoading = true;
      notifyListeners();

      // Para trabajadores, el identificador es el DNI
      String identifier = _currentUser!.dni!;
      
      // Verificar contraseña actual (aquí simularíamos la verificación)
      await Future.delayed(Duration(milliseconds: 500));
      
      // Cambiar contraseña
      await _db.changePassword(identifier, newPassword);
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al cambiar contraseña';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Limpiar mensajes de error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Obtener información completa del usuario actual
  Future<void> refreshCurrentUser() async {
    if (_currentUser == null) return;
    
    try {
      UserModel? updatedUser = await _db.getUserById(_currentUser!.uid);
      if (updatedUser != null) {
        _currentUser = updatedUser;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing user data: $e');
    }
  }

  /// Getters útiles para trabajadores
  bool get isLoggedIn => _currentUser != null;
  bool get isActive => _currentUser?.isActive ?? false;
  String? get workerDni => _currentUser?.dni;
  String? get workerName => _currentUser?.fullName;
  String? get assignedWorksiteId => _currentUser?.assignedWorksiteId;

  /// Verificar permisos específicos de trabajador
  bool get canMarkAttendance => hasPermission('mark_attendance');
  bool get canViewHistory => hasPermission('view_own_history');

  /// Manejo de errores con mensajes amigables
  String _handleError(dynamic error) {
    String errorMsg = error.toString();
    
    if (errorMsg.contains('User not found')) {
      return 'DNI no registrado en el sistema';
    } else if (errorMsg.contains('Invalid password')) {
      return 'Contraseña incorrecta';
    } else if (errorMsg.contains('User account is inactive')) {
      return 'Tu cuenta está inactiva. Contacta al administrador';
    } else if (errorMsg.contains('No internet')) {
      return 'Sin conexión a internet';
    } else {
      return 'Error de conexión. Inténtalo de nuevo';
    }
  }

  /// Método para debugging (solo en desarrollo)
  void debugPrintUserInfo() {
    if (_currentUser != null) {
      print('=== TRABAJADOR ACTUAL ===');
      print('UID: ${_currentUser!.uid}');
      print('Nombre: ${_currentUser!.fullName}');
      print('DNI: ${_currentUser!.dni}');
      print('Obra asignada: ${_currentUser!.assignedWorksiteId}');
      print('Activo: ${_currentUser!.isActive}');
      print('Puede marcar asistencia: $canMarkAttendance');
      print('Puede ver historial: $canViewHistory');
      print('========================');
    }
  }
}