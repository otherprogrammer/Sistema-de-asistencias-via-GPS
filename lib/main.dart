import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_gps/screens/worker/change_password_screen.dart';
import 'package:flutter_gps/screens/worker/select_worksite_screen.dart';
import 'package:flutter_gps/screens/worker/face_registration_screen.dart'; // 🆕
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/tflite_service.dart'; // 🆕
import 'screens/login/login_screen.dart';
import 'screens/worker/worker_home_screen.dart';
import 'constants/app_colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 🆕 Inicializar TFLite en segundo plano
  TFLiteService().initialize().catchError((e) {
    print('⚠️ Error inicializando TFLite en main: $e');
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Crellat Asistencia', // 🆕 Nombre actualizado
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: AppColors.primarySwatch,
          primaryColor: AppColors.primary,
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textOnPrimary,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
            ),
          ),
        ),
        routes: {
          '/': (context) => const AuthWrapper(),
          '/change-password': (context) => const ChangePasswordScreen(isFirstTime: true),
          '/select-worksite': (context) => const SelectWorksiteScreen(),
          '/face-registration': (context) => const FaceRegistrationScreen(), // 🆕
          '/home': (context) => const WorkerHomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Si está cargando, mostrar loading
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Si no hay usuario, mostrar login
        if (authService.currentUser == null) {
          print('🚪 No hay usuario - Mostrando LoginScreen');
          return const LoginScreen();
        }

        final user = authService.currentUser;
        
        // Validar que el usuario no sea nulo antes de usarlo
        if (user == null) {
          print('⚠️ Usuario es nulo inesperadamente, mostrando login');
          return const LoginScreen();
        }

        print('👤 Usuario actual: ${user.fullName}');

        // Verificar si es trabajador y necesita primer setup
        if (user.role == 'trabajador') {
          print('👷 Rol: trabajador');
          print('   - hasChangedPassword: ${user.hasChangedPassword}');
          print('   - hasSelectedWorksite: ${user.hasSelectedWorksite}');
          print('   - assignedWorksiteId: ${user.assignedWorksiteId}');
          print('   - faceRegistered: ${user.faceRegistered ?? false}');
          
          // 1️⃣ Si no ha cambiado contraseña, ir a cambio obligatorio
          if (!user.hasChangedPassword) {
            print('🔐 Redirigiendo a ChangePasswordScreen (obligatorio)');
            return const ChangePasswordScreen(isFirstTime: true);
          }
          
          // 2️⃣ Si no ha seleccionado obra, ir a selección
          if (!user.hasSelectedWorksite || user.assignedWorksiteId == null) {
            print('🏗️ Redirigiendo a SelectWorksiteScreen');
            return const SelectWorksiteScreen();
          }

          // 3️⃣ Si no ha registrado rostro, ir a registro facial
          if (user.faceRegistered != true) {
            print('📸 Redirigiendo a FaceRegistrationScreen');
            return const FaceRegistrationScreen();
          }
        }

        // Si ya completó setup completo o es admin, ir a home
        print('✅ Setup completo - Mostrando WorkerHomeScreen');
        return const WorkerHomeScreen();
      },
    );
  }
}