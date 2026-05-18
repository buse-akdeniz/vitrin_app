import 'package:flutter/material.dart';
import '../services/api_service.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = true;
  int _used = 0;
  int _limit = 20;
  List<dynamic> _sent = [];
  List<dynamic> _received = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getOfferQuota(),
        ApiService.getSentOffers(),
        ApiService.getReceivedOffers(),
      ]);

      final quota = results[0];
      final sent = results[1];
      final received = results[2];

      if (!mounted) return;
      setState(() {
        _used = (quota['used'] ?? 0) as int;
        _limit = (quota['dailyLimit'] ?? 20) as int;
        _sent = (sent['offers'] as List?) ?? [];
        _received = (received['offers'] as List?) ?? [];
      });
    } catch (_) {
      // sessiz
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(int offerId, String action) async {
    final result = await ApiService.respondOffer(offerId: offerId, action: action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text((result['message'] ?? 'İşlem tamamlandı').toString())),
    );
    _load();
  }

  Widget _offerCard(Map<String, dynamic> item, {bool received = false}) {
    final status = (item['status'] ?? 'pending').toString();
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
            Text(
              (item['product_title'] ?? '').toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text('Teklif: ₺${item['amount']} • Durum: $status'),
            Text(
              received
                  ? 'Alıcı: ${item['buyer_name'] ?? '-'}'
                  : 'Satıcı: ${item['seller_name'] ?? '-'}',
              style: const TextStyle(color: Color(0xFF777777)),
            ),
            if (received && status == 'pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _respond(item['id'] as int, 'reject'),
                      child: const Text('Reddet'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _respond(item['id'] as int, 'accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Kabul Et'),
                    ),
                  ),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (_limit - _used).clamp(0, _limit);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Teklifler',
          style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2D2D2D),
          tabs: const [
            Tab(text: 'Verdiklerim'),
            Tab(text: 'Aldıklarım'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Text('Günlük teklif hakkı: $_used/$_limit • Kalan: $remaining'),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D2D2D)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _sent.length,
                        itemBuilder: (_, i) => _offerCard(_sent[i] as Map<String, dynamic>),
                      ),
                      ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _received.length,
                        itemBuilder: (_, i) => _offerCard(_received[i] as Map<String, dynamic>, received: true),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
