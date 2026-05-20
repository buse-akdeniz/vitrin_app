import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const VitrinApp());
}

class VitrinApp extends StatelessWidget {
  const VitrinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitrin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2D2D2D),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashRouter(),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter> {
  bool _loading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final token = await ApiService.getToken();
    if (token == null || token.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _loading = false;
      });
      return;
    }

    try {
      final verify = await ApiService.verifyToken();
      final ok = verify['success'] == true;
      if (!mounted) return;
      setState(() {
        _isAuthenticated = ok;
        _loading = false;
      });

      if (!ok) {
        await ApiService.deleteToken();
      }
    } catch (_) {
      await ApiService.deleteToken();
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F4F0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.checkroom, size: 56, color: Color(0xFF2D2D2D)),
              SizedBox(height: 12),
              CircularProgressIndicator(color: Color(0xFF2D2D2D)),
            ],
          ),
        ),
      );
    }

    return _isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}