import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TrackingScreen extends StatefulWidget {
  final int orderId;

  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _loading = true;
  Map<String, dynamic>? _order;
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getOrderTracking(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = result['order'] as Map<String, dynamic>?;
        _events = (result['events'] as List?) ?? [];
      });
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
        title: const Text(
          'Kargo Takibi',
          style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8E8E8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sipariş #${_order?['id'] ?? '-'}'),
                      const SizedBox(height: 4),
                      Text('Durum: ${_order?['order_status'] ?? '-'}'),
                      Text('Takip No: ${(_order?['tracking_no'] ?? '').toString().isEmpty ? '-' : _order?['tracking_no']}'),
                      Text('Paket: ${_order?['package_size'] ?? 'medium'}'),
                      Text('Kargo: ${(_order?['shipping_type'] ?? '') == 'buyer' ? 'Alıcı' : 'Satıcı'}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Takip Geçmişi', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._events.map((e) {
                  final item = e as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((item['event_type'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text((item['note'] ?? '').toString()),
                        Text((item['created_at'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
