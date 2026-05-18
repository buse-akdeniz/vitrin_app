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
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await ApiService.getToken();
    if (!mounted) return;
    setState(() {
      _hasToken = token != null && token.trim().isNotEmpty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F4F0),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF2D2D2D)),
        ),
      );
    }

    return _hasToken ? const HomeScreen() : const LoginScreen();
  }
}
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vitrin', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Arka Plandaki Ana İçerik (Kıyafet Listesi vb.)
          const Center(
            child: Text(
              'Vitrin Akış Alanı',
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
          ),

          // Yapay Zeka Chat Paneli (Yarı Ekranı Kaplayan Katman)
          if (_isChatOpen)
            Positioned(
              bottom: 80,
              right: 20,
              left: 20,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Column(
                  children: [
                    // Panel Başlığı
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: const BoxDecoration(
                        color: Colors.indigo,
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Vitrin AI Stylist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    // Chat Mesaj Alanı
                    const Expanded(
                      child: Center(
                        child: Text('Kombin asistanına bir şeyler sor...', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    // Chat Input Girişi
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Nasıl bir kombin istersin?',
                          suffixIcon: IconButton(icon: const Icon(Icons.send, color: Colors.indigo), onPressed: () {}),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Sağ Alttaki Yüzen Buton (FloatingActionButton)
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Butona basıldığında panel durumunu tersine çevir (Açıksa kapat, kapalıysa aç)
          setState(() {
            _isChatOpen = !_isChatOpen;
          });
        },
        backgroundColor: Colors.indigo,
        child: Icon(
          _isChatOpen ? Icons.close : Icons.auto_awesome, // Panel açıksa çarpı, kapalıysa yapay zeka ikonu
          color: Colors.white,
        ),
      ),
    );
  }
}