import 'package:flutter/material.dart';

void main() {
  runApp(const VitrinApp());
}

class VitrinApp extends StatelessWidget {
  const VitrinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vitrin App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const MainLayoutScreen(),
    );
  }
}

// Ana Ekran Düzeni (Main Layout Screen)
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  // Chat panelinin açık/kapalı olma durumunu tutan değişken (State)
  bool _isChatOpen = false;

  @override
  Widget build(BuildContext context) {
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