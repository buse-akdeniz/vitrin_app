import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await ApiService.getNotifications();
      if (!mounted) return;
      setState(() => _notifications = (result['notifications'] as List?) ?? []);
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    await ApiService.markAllNotificationsRead();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Bildirimler', style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold)),
        actions: [
          TextButton(onPressed: _markAllRead, child: const Text('Tümünü Oku')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _notifications.length,
              itemBuilder: (_, i) {
                final n = _notifications[i] as Map<String, dynamic>;
                final isRead = (n['is_read'] ?? 0) == 1;
                Map<String, dynamic> payload = {};
                try {
                  payload = jsonDecode((n['data_json'] ?? '{}').toString()) as Map<String, dynamic>;
                } catch (_) {}
                return InkWell(
                  onTap: () async {
                    await ApiService.markNotificationRead((n['id'] ?? 0) as int);
                    _load();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isRead ? Colors.white : const Color(0xFFFFF9E6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((n['title'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text((n['message'] ?? '').toString()),
                        if (payload['orderId'] != null)
                          Text('Sipariş #${payload['orderId']}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                        Text((n['created_at'] ?? '').toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
