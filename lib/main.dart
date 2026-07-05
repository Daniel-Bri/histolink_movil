import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:histolink/app_navigator.dart';
import 'package:histolink/shared/theme/app_colors.dart';
import 'package:histolink/shared/screens/dashboard_screen.dart';
import 'package:histolink/shared/models/user_model.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/screens/login_screen.dart';
import 'package:histolink/GestionDeUsuarios/LoginYAutenticacion/services/auth_service.dart';
import 'package:histolink/shared/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FcmService.instance.init();
  runApp(const HistolinkApp());
}

class HistolinkApp extends StatelessWidget {
  const HistolinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      title: 'Histolink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.azulElectrico,
          primary: AppColors.azulElectrico,
          secondary: AppColors.mentaVibrante,
          surface: AppColors.fondo,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          labelStyle: const TextStyle(color: AppColors.azulElectrico),
          prefixIconColor: AppColors.azulElectrico,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.azulPuro, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.azulCielo.withOpacity(0.8), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE53E3E), width: 2),
          ),
        ),
      ),
      home: const _SplashRouter(),
    );
  }
}

/// Verifica si hay sesión activa y redirige a Login o Dashboard.
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    try {
      final auth = AuthService();

      // Timeout de 6s: si el storage tarda más, vamos directo al login
      final loggedIn = await auth.isLoggedIn().timeout(
        const Duration(seconds: 6),
        onTimeout: () => false,
      );

      if (!mounted) return;

      if (loggedIn) {
        final username = await auth.getCachedUsername();
        final user = UserModel(
          id: 0, username: username, email: '',
          firstName: '', lastName: '', groups: [],
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => DashboardScreen(user: user)),
        );
      } else {
        _goLogin();
      }
    } catch (_) {
      // Cualquier error → pantalla de login
      if (mounted) _goLogin();
    }
  }

  void _goLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.azulElectrico,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white30, width: 1.5),
              ),
              child: const Icon(Icons.local_hospital, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text(
              'Histolink',
              style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Text(
              'Sistema de Gestión Documental Clínico',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: AppColors.mentaVibrante, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
