import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class DatabaseService {
  static const String _usersKey = 'users_local_db';
  
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // Datos de prueba - Solo trabajadores
  List<UserModel> _mockUsers = [
    UserModel(
      uid: 'worker_12345678',
      role: 'trabajador',
      dni: '12345678',
      fullName: 'Juan Carlos Pérez',
      assignedWorksiteId: 'obra_001',
      isActive: true,
    ),
    UserModel(
      uid: 'worker_87654321',
      role: 'trabajador', 
      dni: '87654321',
      fullName: 'María Elena Rodríguez',
      assignedWorksiteId: 'obra_002',
      isActive: true,
    ),
    UserModel(
      uid: 'worker_11111111',
      role: 'trabajador',
      dni: '11111111', 
      fullName: 'Carlos Alberto Silva',
      assignedWorksiteId: 'obra_001',
      isActive: true,
    ),
    UserModel(
      uid: 'worker_22222222',
      role: 'trabajador',
      dni: '22222222',
      fullName: 'Ana Lucía Torres',
      assignedWorksiteId: 'obra_003',
      isActive: false, // Usuario inactivo
    ),
  ];

  // Contraseñas para trabajadores (DNI como identificador)
  Map<String, String> _passwords = {
    '12345678': '123456', // Primeros 6 dígitos del DNI
    '87654321': '876543',
    '11111111': '111111',
    '22222222': '222222',
  };

  /// Inicializar base de datos local
  Future<void> initializeDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Si no hay datos guardados, usar los datos mock
    if (!prefs.containsKey(_usersKey)) {
      await _saveUsersToLocal();
      print('Base de datos local inicializada con datos de prueba');
    } else {
      await _loadUsersFromLocal();
      print('Base de datos local cargada desde almacenamiento');
    }
  }

  /// Guardar usuarios en almacenamiento local
  Future<void> _saveUsersToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> usersJson = _mockUsers.map((user) => 
      json.encode(user.toFirestore()..['uid'] = user.uid)
    ).toList();
    await prefs.setStringList(_usersKey, usersJson);
  }

  /// Cargar usuarios desde almacenamiento local
  Future<void> _loadUsersFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? usersJson = prefs.getStringList(_usersKey);
    
    if (usersJson != null) {
      _mockUsers = usersJson.map((userStr) {
        Map<String, dynamic> userData = json.decode(userStr);
        String uid = userData['uid'];
        userData.remove('uid');
        return UserModel.fromFirestore(userData, uid);
      }).toList();
    }
  }

  /// Autenticar usuario por DNI (trabajadores)
  Future<UserModel?> authenticateWorkerByDni(String dni, String password) async {
    // Simular delay de red
    await Future.delayed(Duration(milliseconds: 800));
    
    // Buscar usuario por DNI
    UserModel? user = _mockUsers.firstWhere(
      (u) => u.dni == dni && u.role == 'trabajador',
      orElse: () => throw Exception('User not found'),
    );
    
    if (user == null) return null;
    
    // Verificar contraseña
    if (_passwords[dni] != password) {
      throw Exception('Invalid password');
    }
    
    // Verificar que el usuario esté activo
    if (!user.isActive) {
      throw Exception('User account is inactive');
    }
    
    return user;
  }
  /// Verificar permisos de usuario
bool hasPermission(UserModel user, String permission) {
  switch (permission) {
    case 'mark_attendance':
      return user.role == 'trabajador' && user.isActive;
    
    case 'view_own_history':
      return user.role == 'trabajador' && user.isActive;
    
    default:
      return false;
  }
}

/// Obtener usuario por UID
Future<UserModel?> getUserById(String uid) async {
  await Future.delayed(Duration(milliseconds: 200));
  
  try {
    return _mockUsers.firstWhere((u) => u.uid == uid);
  } catch (e) {
    return null;
  }
}

  /// Obtener todos los trabajadores
  Future<List<UserModel>> getAllWorkers() async {
    await Future.delayed(Duration(milliseconds: 500));
    return _mockUsers.where((u) => u.role == 'trabajador').toList();
  }

  /// Obtener trabajadores por obra
  Future<List<UserModel>> getWorkersByWorksite(String worksiteId) async {
    await Future.delayed(Duration(milliseconds: 300));
    return _mockUsers.where((u) => 
      u.role == 'trabajador' && u.assignedWorksiteId == worksiteId
    ).toList();
  }

  /// Crear nuevo usuario (simulado)
  Future<UserModel> createUser({
    required String role,
    String? email,
    String? dni,
    required String fullName,
    String? assignedWorksiteId,
    bool isActive = true,
  }) async {
    await Future.delayed(Duration(milliseconds: 600));
    
    String uid = 'generated_${DateTime.now().millisecondsSinceEpoch}';
    
    UserModel newUser = UserModel(
      uid: uid,
      role: role,
      email: email,
      dni: dni,
      fullName: fullName,
      assignedWorksiteId: assignedWorksiteId,
      isActive: isActive,
    );
    
    _mockUsers.add(newUser);
    await _saveUsersToLocal();
    
    return newUser;
  }

  /// Actualizar usuario
  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    await Future.delayed(Duration(milliseconds: 400));
    
    int index = _mockUsers.indexWhere((u) => u.uid == uid);
    if (index != -1) {
      // Crear usuario actualizado (esto simula la actualización)
      Map<String, dynamic> currentData = _mockUsers[index].toFirestore();
      currentData.addAll(updates);
      
      _mockUsers[index] = UserModel.fromFirestore(currentData, uid);
      await _saveUsersToLocal();
    }
  }

  /// Cambiar contraseña (simulado)
  Future<void> changePassword(String identifier, String newPassword) async {
    await Future.delayed(Duration(milliseconds: 400));
    _passwords[identifier] = newPassword;
    // En un sistema real, esto se guardaría de forma segura
    print('Password changed for $identifier');
  }

  /// Métodos de utilidad para debugging
  void printAllUsers() {
    print('=== USUARIOS EN BASE DE DATOS LOCAL ===');
    for (var user in _mockUsers) {
      print('UID: ${user.uid}');
      print('Role: ${user.role}');
      print('Name: ${user.fullName}');
      print('Email: ${user.email}');
      print('DNI: ${user.dni}');
      print('Worksite: ${user.assignedWorksiteId}');
      print('Active: ${user.isActive}');
      print('---');
    }
  }
}