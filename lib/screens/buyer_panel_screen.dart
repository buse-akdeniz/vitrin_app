import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'tracking_screen.dart';

class BuyerPanelScreen extends StatefulWidget {
  const BuyerPanelScreen({super.key});

  @override
  State<BuyerPanelScreen> createState() => _BuyerPanelScreenState();
}

class _BuyerPanelScreenState extends State<BuyerPanelScreen> {
  bool _loading = true;
  List<dynamic> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getBuyerOrders();
      if (!mounted) return;
      setState(() => _orders = (result['orders'] as List?) ?? []);
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Alıcı Paneli', style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _orders.length,
              itemBuilder: (_, i) {
                final order = _orders[i] as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((order['product_title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Durum: ${order['order_status']}'),
                        Text('Satıcı: ${order['seller_name'] ?? '-'} • Puan: ${order['seller_rating'] ?? 0}'),
                        Text('Kargo: ${(order['shipping_type'] ?? '') == 'buyer' ? 'Alıcı' : 'Satıcı'} • Paket: ${order['package_size'] ?? 'medium'}'),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TrackingScreen(orderId: (order['id'] ?? 0) as int),
                                ),
                              ),
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: const Text('Takip'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final r = await ApiService.requestCancel((order['id'] ?? 0) as int);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((r['message'] ?? 'İşlem tamamlandı').toString())));
                                _load();
                              },
                              child: const Text('İptal Talebi'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final r = await ApiService.requestReturn((order['id'] ?? 0) as int);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((r['message'] ?? 'İşlem tamamlandı').toString())));
                                _load();
                              },
                              child: const Text('İade Talebi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
