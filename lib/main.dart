import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/auth_service.dart';
import 'models/user_model.dart';

void main() {
  runApp(const HistolinkApp());
}

class HistolinkApp extends StatelessWidget {
  const HistolinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Histolink',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
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
    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;
    if (loggedIn) {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('cached_username') ?? '';
      final user = UserModel(id: 0, username: username, email: '', firstName: '', lastName: '', groups: []);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardScreen(user: user)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1976D2),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_hospital, color: Colors.white, size: 64),
            SizedBox(height: 16),
            Text('Histolink', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Colors.white70),
          ],
        ),
      ),
    );
  }
}
